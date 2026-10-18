import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plan.dart';
import 'meal_ai.dart';
import 'store.dart';

/// Google Sign-In + Firestore backup/sync for Daur.
///
/// Data model (see firestore.rules, database `daur`):
///   users/{uid}            profile: uid, displayName, email, photoUrl, createdAt, updatedAt
///   users/{uid}/state/app  the whole app state as JSON (the Store), schema, device, updatedAt
///
/// The app keeps working offline from the phone's own storage. When signed in, every change is
/// pushed a few seconds later. Divergent copies require an explicit choice; transactions
/// prevent an unseen change from another device being overwritten.
class Cloud extends ChangeNotifier {
  Cloud._()
    : _auth = FirebaseAuth.instance,
      _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: _databaseId);

  @visibleForTesting
  factory Cloud.forTesting({required FirebaseAuth auth, required FirebaseFirestore db, required Store store}) =>
      Cloud._testing(auth, db, store);

  Cloud._testing(this._auth, this._db, Store store) { _store = store; }

  @visibleForTesting
  Future<void> flushForTesting() => _push();
  static final instance = Cloud._();

  static const _databaseId = 'daur'; // Enterprise edition requires a named database
  static const _schema = 1;
  static const _maxBytes = 900000; // matches the size limit in firestore.rules

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Store? _store;
  Timer? _debounce;
  bool _pulling = false;
  bool syncing = false;
  int _authGeneration = 0;
  Future<void>? _pushTask;
  bool _pushAgain = false;

  bool _sameSession(int generation, String uid) => generation == _authGeneration && user?.uid == uid && !_deleting;
  String? conflictData;
  String? _baseData;
  String? _baseUid;

  String get backupStatus => !signedIn
      ? 'Not backed up · sign in from the menu'
      : conflictData != null
      ? 'Two saved copies need your choice'
      : error != null
      ? error!
      : syncing
      ? 'Backing up…'
      : lastSync == null
      ? 'Backup pending'
      : 'Last backed up at ${lastSync!.toLocal().toString().substring(0, 16)}';

  void dismissError() {
    error = null;
    notifyListeners();
  }

  Future<void> retrySync() async {
    final u = user;
    if (u != null) await _syncOnSignIn(u);
  }

  Future<void> resolveConflict({required bool useCloud}) async {
    final remote = conflictData, s = _store, u = user;
    if (remote == null || s == null || u == null) return;
    final generation = _authGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (!_sameSession(generation, u.uid)) return;
    await prefs.setString('daur.syncRecovery.${u.uid}', useCloud ? s.snapshot() : remote);
    if (!_sameSession(generation, u.uid)) return;
    await prefs.setString('daur.syncBase.${u.uid}', remote);
    if (!_sameSession(generation, u.uid)) return;
    _baseData = remote;
    conflictData = null;
    if (useCloud) {
      _pulling = true;
      try {
        s.adoptCloud(remote);
        s.claim(u.uid);
        await s.saved;
      } finally {
        _pulling = false;
      }
    }
    if (_sameSession(generation, u.uid)) await _push();
  }

  Future<String?> recoveredSyncCopy() async {
    final uid = user?.uid;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    if (user?.uid != uid) return null;
    return prefs.getString('daur.syncRecovery.$uid');
  }

  bool _deleting = false; // deleting the account: no sync may write anything back
  bool busy = false;
  String? error;
  DateTime? lastSync;

  User? get user => _auth.currentUser;
  bool get signedIn => user != null;

  DocumentReference<Map<String, dynamic>> _profile(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _state(String uid) => _profile(uid).collection('state').doc('app');

  /// Call once after Firebase.initializeApp. Syncs whenever the user is signed in.
  Future<void> attach(Store s) async {
    _store = s;
    s.signedIn = _auth.currentUser != null; // before the first frame asks for a coach card
    if (!kIsWeb) {
      // google_sign_in 7.x must be initialised once before use; Android reads the web client
      // from google-services.json, iOS reads GIDClientID from Info.plist.
      try {
        await GoogleSignIn.instance.initialize();
      } catch (e) {
        debugPrint('GoogleSignIn.initialize: $e');
      }
    }
    s.addListener(_onLocalChange);
    _auth.authStateChanges().listen((u) {
      _authGeneration++;
      _debounce?.cancel();
      _baseUid = null;
      _baseData = null;
      conflictData = null;
      lastSync = null;
      error = null;
      s.signedIn = u != null;
      notifyListeners();
      if (u != null) _syncOnSignIn(u);
      _watchPlan();
    });
  }

  // ---- sign in / out ----

  /// Returns null on success (or cancel), or a short message to show the user.
  Future<String?> signInWithGoogle() async {
    error = null;
    _set(busy: true);
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          return await _fail('Google did not return a sign-in token. Try again.');
        }
        await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return await _fail('Google sign-in failed (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      return await _fail(
        e.code == 'network-request-failed'
            ? 'No internet. Daur keeps working offline; sign in later.'
            : 'Sign-in failed (${e.code}).',
      );
    } catch (e) {
      return await _fail('Sign-in failed: $e');
    } finally {
      _set(busy: false);
    }
  }

  /// Delete this account's cloud data and the sign-in itself. The phone keeps its data.
  /// Google may ask to sign in again first (a recent sign-in is required to delete an account).
  Future<String?> deleteAccount() async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Not signed in.';
    if (kIsWeb && MealAi.webSiteKey.isEmpty) {
      return 'Secure web deletion is not configured for this build. Use Daur on your phone or contact support from Privacy & support.';
    }
    _debounce?.cancel();
    _deleting = true;
    _set(busy: true);
    try {
      // Finish any transaction already sent before starting server cleanup.
      await _pushTask;
      // Authenticate before deleting any data. Cancellation must leave the account intact.
      if (kIsWeb) {
        await u.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) return 'Google did not return a sign-in token.';
        await u.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: token));
      }
      await u.getIdToken(true);
      // Admin cleanup finds legacy relationships and notes on other accounts too.
      // Never fall back to partial client cleanup when the service is unavailable.
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteAccountData', options: HttpsCallableOptions(timeout: const Duration(minutes: 9)))
          .call<Map<String, dynamic>>();
      if (result.data['deleted'] != true) {
        return await _fail('Cloud deletion was not confirmed. Stay signed in and retry.');
      }
      s.releaseOwner();
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
      lastSync = null;
      notifyListeners();
      return null;
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? 'Deletion cancelled. Your account was not deleted.'
          : 'Could not verify your identity (${e.code.name}).';
    } catch (e) {
      return await _fail('Could not finish deletion. Stay signed in and retry: $e');
    } finally {
      _deleting = false;
      _set(busy: false);
    }
  }

  Future<void> signOut({bool requireBackup = true}) async {
    _debounce?.cancel();
    if (signedIn && requireBackup) {
      await _push(); // also waits for any in-flight push and later local changes
      if (conflictData != null || error != null || (_store?.ownerUid == user?.uid && _store?.snapshot() != _baseData)) {
        throw StateError('Backup is not complete. Resolve the issue in Your data before signing out.');
      }
    }
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    lastSync = null;
    notifyListeners(); // the phone keeps its local copy
  }

  // ---- sync ----

  void _onLocalChange() {
    if (!signedIn || _pulling || _deleting) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _push);
  }

  Future<void> _syncOnSignIn(User u) async {
    final s = _store;
    final generation = _authGeneration;
    if (s == null || !_sameSession(generation, u.uid)) return;
    try {
      await _writeProfile(u);
      if (!_sameSession(generation, u.uid)) return;
      final prefs = await SharedPreferences.getInstance();
      if (!_sameSession(generation, u.uid)) return;
      if (_baseUid != u.uid) {
        _baseUid = u.uid;
        _baseData = prefs.getString('daur.syncBase.${u.uid}');
        conflictData = null;
      }
      final remote = await _state(u.uid).get(const GetOptions(source: Source.server));
      if (!_sameSession(generation, u.uid)) return;
      final data = remote.data()?['data'];
      final otherPerson = s.ownerUid != null && s.ownerUid != u.uid;
      if (data is String) {
        Store.decodeBackup(data);
        if (otherPerson || !s.onboarded) {
          _pulling = true;
          s.adoptCloud(data);
          s.claim(u.uid);
          _pulling = false;
          _baseData = data;
          await prefs.setString('daur.syncBase.${u.uid}', data);
          if (!_sameSession(generation, u.uid)) return;
        } else if (data != _baseData && data != s.snapshot()) {
          conflictData = data;
          await _fail('Another saved copy exists. Choose which copy to keep in Your data.');
          return;
        }
      } else if (otherPerson) {
        _pulling = true;
        s.startFresh(u.uid);
        _pulling = false;
      }
      _pulling = true;
      s.claim(u.uid);
      _pulling = false;
      await _push();
      if (_sameSession(generation, u.uid)) _watchPlan();
    } catch (e) {
      if (!_sameSession(generation, u.uid)) return;
      _pulling = false;
      _fail('Sync failed: $e');
    }
  }

  Future<void> _writeProfile(User u) async {
    final ref = _profile(u.uid);
    final fields = <String, Object>{
      if ((u.displayName ?? '').isNotEmpty)
        'displayName': u.displayName!.substring(0, u.displayName!.length.clamp(0, 100)),
      if ((u.email ?? '').isNotEmpty) 'email': u.email!,
      if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update(fields);
    } else {
      await ref.set({...fields, 'uid': u.uid, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  /// One drain owns the writer; edits made during network work join the same flush.
  Future<void> _push() {
    _pushAgain = true;
    final active = _pushTask;
    if (active != null) return active;
    final completer = Completer<void>();
    _pushTask = completer.future;
    _drainPushes().then((_) => completer.complete(), onError: completer.completeError);
    return completer.future;
  }

  Future<void> _drainPushes() async {
    syncing = true;
    notifyListeners();
    try {
      while (_pushAgain) {
        _pushAgain = false;
        final u = user, s = _store;
        if (u == null || s == null || _deleting || s.ownerUid != u.uid || conflictData != null) {
          break;
        }
        final generation = _authGeneration;
        final data = s.snapshot();
        if (utf8.encode(data).length > _maxBytes) {
          await _fail('Too much data to back up (${data.length ~/ 1000} KB).');
          break;
        }
        try {
          await _db.runTransaction((tx) async {
            final ref = _state(u.uid);
            final remote = (await tx.get(ref)).data()?['data'];
            if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) {
              throw StateError('Account changed during backup.');
            }
            if (remote is String && remote != _baseData && remote != data) {
              conflictData = remote;
              throw StateError('Another device changed your backup. Choose a copy in Your data.');
            }
            tx.set(ref, {
              'data': data,
              'schema': _schema,
              'device': kIsWeb ? 'web' : defaultTargetPlatform.name,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
          if (!_sameSession(generation, u.uid)) continue;
          final prefs = await SharedPreferences.getInstance();
          if (!_sameSession(generation, u.uid)) continue;
          await prefs.setString('daur.syncBase.${u.uid}', data);
          if (!_sameSession(generation, u.uid)) continue;
          _baseData = data;
          _set(synced: true);
          await pushBoard();
          if (!_sameSession(generation, u.uid)) continue;
          await pushCoaching();
          if (_sameSession(generation, u.uid) && s.snapshot() != data) {
            _pushAgain = true;
          }
        } catch (e) {
          if (!_sameSession(generation, u.uid)) continue;
          await _fail('Backup not completed: $e');
          break; // retain dirty data for an explicit retry, without a network retry loop
        }
      }
    } finally {
      syncing = false;
      _pushTask = null;
      notifyListeners();
    }
  }

  // ---- boards: family, and friends with a leaderboard ----
  //
  // families/{code}           members (uids); the same for a friends' board
  // families/{code}/board/{uid}  each member's row: streak, today's meals, this race week's points,
  //                              steps, kg lifted, full days, water and kcal over target

  DocumentReference<Map<String, dynamic>> _family(String code) => _db.collection('families').doc(code);

  /// This person's row on each board they're on: streak, today's meals, a perfect day, this week's
  /// race points. No email.
  Future<void> pushBoard() async {
    final u = user, s = _store;
    if (u == null || s == null || s.ownerUid != u.uid || _deleting) return;
    final generation = _authGeneration;
    for (final kind in const ['family', 'friends']) {
      if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) return;
      final code = s.boardId(kind);
      if (code == null) continue;
      try {
        await _family(code).collection('board').doc(u.uid).set({
          'name': (u.displayName ?? '').isEmpty
              ? (kind == 'friends' ? 'Friend' : 'Family member')
              : u.displayName!.substring(0, u.displayName!.length.clamp(0, 60)),
          if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
          'streak': s.streak,
          'legs': s.legsDone,
          'day': s.today,
          'perfect': s.perfect(s.today),
          'points': s.weekPoints,
          'steps': s.weekSteps,
          'lifted': s.weekLifted,
          'full': s.weekFullDays,
          'water': s.weekWater,
          'extra': s.weekExtra,
          if (s.weekStepsTyped) 'typed': true,
          'week': raceWeekStart(s.today),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (_sameSession(generation, u.uid)) {
          await _fail('Could not update the $kind board: $e');
        }
      }
    }
  }

  /// A new board with a random 8-character code to share (no 0/O or 1/I to misread).
  Future<String?> createBoard(String kind) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final code = List.generate(8, (_) => abc[r.nextInt(abc.length)]).join();
    try {
      await _family(code).set({
        'ownerUid': u.uid,
        'members': [u.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      s.setBoard(kind, code);
      await pushBoard();
      return null;
    } catch (e) {
      return 'Couldn\'t create it: $e';
    }
  }

  Future<String?> joinBoard(String kind, String input) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    final code = input.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      return 'A code is 8 letters and numbers.';
    }
    if (code == s.boardId(kind == 'friends' ? 'family' : 'friends')) {
      return 'That\'s your ${kind == 'friends' ? 'family' : 'friends\''} board.';
    }
    try {
      await _family(code).update({
        'members': FieldValue.arrayUnion([u.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      s.setBoard(kind, code);
      await pushBoard();
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'not-found' ? 'No board with that code.' : 'Couldn\'t join (${e.code}). Is the board full (20)?';
    }
  }

  Future<void> leaveBoard(String kind) async {
    final u = user, s = _store, code = s?.boardId(kind);
    if (u == null || s == null || code == null) return;
    try {
      await _family(code).collection('board').doc(u.uid).delete();
      final members = List<String>.from((await _family(code).get()).data()?['members'] ?? const []);
      if (members.length <= 1) {
        await _family(code).delete(); // the last one out closes the board
      } else {
        await _family(code).update({
          'members': FieldValue.arrayRemove([u.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      await _fail('Could not leave the board. Sharing is still active: $e');
      return;
    }
    s.setBoard(kind, null);
  }

  Future<String?> createFamily() => createBoard('family');
  Future<String?> joinFamily(String input) => joinBoard('family', input);
  Future<void> leaveFamily() => leaveBoard('family');

  // ---- coaching: a mother for the diet, a trainer; they follow this person's plan ----
  //
  // invites/{code}              who made the code and for which role (diet | trainer | partner)
  // coaching/{owner}            the owner's progress summary, readable by their helpers
  // coaching/{owner}/helpers/{uid}  one per helper, written by the helper with a valid code; a
  //                                  partner adds `back`, their own partner code, so it goes both ways
  // coaching/{owner}/notes/{id}     notes both ways ("less rice tonight")
  // coaching/{owner}/share/partner  what a partner sees instead: the summary minus what's kept back

  DocumentReference<Map<String, dynamic>> _coach(String owner) => _db.collection('coaching').doc(owner);

  String _name(User u, String fallback) =>
      (u.displayName ?? '').isEmpty ? fallback : u.displayName!.substring(0, u.displayName!.length.clamp(0, 60));

  /// Publishes today's summary for helpers, once this person has invited someone.
  Future<void> pushCoaching() async {
    final u = user, s = _store;
    if (u == null || s == null || s.ownerUid != u.uid || _deleting || s.inviteCodes.isEmpty || s.helperOnly) {
      return;
    }
    final generation = _authGeneration;
    Map<String, Object> doc(Map<String, Object?> data) => {
      'ownerUid': u.uid,
      'name': _name(u, 'Daur'),
      if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
      'data': jsonEncode(data),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _coach(u.uid).set(doc(s.coachSummary()));
      if (_sameSession(generation, u.uid) && s.ownerUid == u.uid && s.inviteCodes.containsKey('partner')) {
        await _coach(u.uid).collection('share').doc('partner').set(doc(s.partnerSummary()));
      }
    } catch (e) {
      if (_sameSession(generation, u.uid)) {
        await _fail('Could not update your shared progress: $e');
      }
    }
  }

  /// A code for a helper with [role] ('diet', 'trainer' or 'partner'), reusable until revoked.
  Future<String?> createInvite(String role) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final code = List.generate(8, (_) => abc[r.nextInt(abc.length)]).join();
    try {
      await _db.collection('invites').doc(code).set({
        'ownerUid': u.uid,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      s.setInvite(role, code);
      _watchPlan();
      await pushCoaching();
      return null;
    } catch (e) {
      return 'Couldn\'t make a code: $e';
    }
  }

  Future<void> revokeInvite(String role) async {
    final s = _store, code = s?.inviteCodes[role];
    if (s == null || code == null) return;
    try {
      await _db.collection('invites').doc(code).delete();
    } catch (e) {
      await _fail('Could not revoke the invite. Sharing is still active: $e');
      return;
    }
    s.setInvite(role, null);
  }

  /// Join someone as their helper with the code they shared. Returns an error message or null.
  Future<String?> joinAsHelper(String input) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    final code = input.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      return 'A code is 8 letters and numbers.';
    }
    try {
      final inv = (await _db.collection('invites').doc(code).get()).data();
      if (inv == null) return 'No invite with that code.';
      final owner = inv['ownerUid'] as String, role = inv['role'] as String;
      if (owner == u.uid) {
        return 'That\'s your own code: share it with your helper.';
      }
      // a partner sees this person back: hand over our own partner code with the join
      if (role == 'partner' && s.inviteCodes['partner'] == null) {
        final e = await createInvite('partner');
        if (e != null) return e;
      }
      await _coach(owner).collection('helpers').doc(u.uid).set({
        'name': _name(u, 'Helper'),
        if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
        'role': role,
        'code': code,
        if (role == 'partner') 'back': s.inviteCodes['partner']!,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      final summary = role == 'partner' ? _coach(owner).collection('share').doc('partner') : _coach(owner);
      final name = (await summary.get()).data()?['name'] as String? ?? 'Your person';
      s.addHelping(owner, name, role);
      return null;
    } on FirebaseException catch (e) {
      return 'Couldn\'t join (${e.code}).';
    }
  }

  /// Stop helping [owner] (the helper), or remove helper [helperUid] (the owner).
  Future<void> leaveHelping(String owner) async {
    final u = user;
    if (u == null) return;
    try {
      await _coach(owner).collection('helpers').doc(u.uid).delete();
    } catch (e) {
      await _fail('Could not stop helping. Try again: $e');
      return;
    }
    _store?.removeHelping(owner);
  }

  Future<void> removeHelper(String helperUid) async {
    final u = user;
    if (u == null) return;
    try {
      final ref = _coach(u.uid).collection('helpers').doc(helperUid);
      final helper = (await ref.get()).data();
      final code = helper?['code'] as String?;
      // Revoke the original code as well: deleting only the helper lets them rejoin.
      // This revokes everyone using that code; issue a fresh code to reconnect trusted helpers.
      final batch = _db.batch();
      if (code != null) batch.delete(_db.collection('invites').doc(code));
      batch.delete(ref);
      await batch.commit();
      if (code != null && _store?.inviteCodes[helper?['role']] == code) {
        _store?.setInvite(helper!['role'] as String, null);
      }
    } catch (e) {
      await _fail('Could not remove the helper. Sharing is still active: $e');
    }
  }

  /// Unlink a partner: neither sees the other any more, and the old code stops working.
  Future<void> unlinkPartner(String uid) async {
    await removeHelper(uid);
    await leaveHelping(uid);
    await revokeInvite('partner');
  }

  /// This person's helpers, live: name, photo, role.
  Stream<List<Map<String, dynamic>>> helpers() {
    final u = user;
    if (u == null) return const Stream.empty();
    return _coach(u.uid)
        .collection('helpers')
        .snapshots()
        .map(
          (q) => [
            for (final d in q.docs) {...d.data(), 'uid': d.id},
          ],
        );
  }

  /// [owner]'s summary as a helper sees it, live (null until they have published one). A partner
  /// reads their own copy, without what [owner] keeps back.
  Stream<({String name, String? photo, Map<String, dynamic> data, DateTime? at})?> progress(
    String owner, {
    bool partner = false,
  }) => (partner ? _coach(owner).collection('share').doc('partner') : _coach(owner)).snapshots().map((d) {
    final x = d.data();
    if (x == null) return null;
    return (
      name: x['name'] as String? ?? '',
      photo: x['photoUrl'] as String?,
      data: jsonDecode(x['data'] as String? ?? '{}') as Map<String, dynamic>,
      at: (x['updatedAt'] as Timestamp?)?.toDate(),
    );
  });

  /// Notes on [owner]'s plan, newest first.
  Stream<List<Map<String, dynamic>>> notes(String owner) => _coach(owner)
      .collection('notes')
      .orderBy('at', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs) {...d.data(), 'id': d.id},
        ],
      );

  /// [role] is 'owner' when the person writes on their own plan, else their helper role.
  Future<String?> addNote(String owner, String text, String role) async {
    final u = user;
    final t = text.trim();
    if (u == null) return 'Sign in first.';
    if (t.isEmpty) return null;
    try {
      await _coach(owner).collection('notes').add({
        'fromUid': u.uid,
        'name': _name(u, role == 'owner' ? 'Me' : 'Helper'),
        'role': role,
        'text': t.substring(0, t.length.clamp(0, 500)),
        'at': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Couldn\'t send: $e';
    }
  }

  Future<void> deleteNote(String owner, String id) async {
    try {
      await _coach(owner).collection('notes').doc(id).delete();
    } catch (e) {
      await _fail('Could not delete the note: $e');
    }
  }

  // ---- the diet chart (the trainer writes it) and today's cooking (a helper picks options) ----
  //
  // coaching/{owner}/plan/diet  data: the chart as JSON, changes: what changed in words
  // coaching/{owner}/plan/cook  picks: {meal id: option} for one day
  // coaching/{owner}/plan/gym   data: the workout as JSON (Store.workout), changes: in words
  // The owner's phone applies both as they arrive (with Undo); everyone reads the chart back from
  // the owner's summary, so it always shows what the owner actually has.

  DocumentReference<Map<String, dynamic>> _plan(String owner, String doc) => _coach(owner).collection('plan').doc(doc);

  /// Plan changes applied on this phone: a message to show and the state to restore on Undo.
  final planEvents = ValueNotifier<({String text, String undo, String kind, String at})?>(null);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _dietSub, _cookSub, _gymSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _partnerSub;
  Set<String> _partners = {};

  static String? _at(Map<String, dynamic> d) => (d['at'] as Timestamp?)?.toDate().toIso8601String();

  /// Listen for a new chart or cooking picks while this person has helpers.
  void _watchPlan() {
    _dietSub?.cancel();
    _cookSub?.cancel();
    _gymSub?.cancel();
    _partnerSub?.cancel();
    _partners = {};
    final u = user, s = _store;
    if (u == null || s == null || s.ownerUid != u.uid || s.inviteCodes.isEmpty || s.helperOnly) {
      return;
    }
    final generation = _authGeneration;
    // a partner joined with our code: join them back with theirs; one who left: let go of them too.
    // ponytail: an unlink while this phone was closed isn't seen; their page just stops updating
    _partnerSub = _coach(u.uid).collection('helpers').where('role', isEqualTo: 'partner').snapshots().listen((q) async {
      if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) return;
      final now = {for (final d in q.docs) d.id: d.data()['back'] as String?};
      final gone = _partners.difference(now.keys.toSet());
      _partners = now.keys.toSet();
      for (final uid in gone) {
        if (!_sameSession(generation, u.uid)) return;
        await leaveHelping(uid);
      }
      for (final MapEntry(key: uid, value: back) in now.entries) {
        if (!_sameSession(generation, u.uid)) return;
        if (back != null && !s.helping.any((h) => h['owner'] == uid)) {
          await joinAsHelper(back);
        }
      }
    });
    _dietSub = _plan(u.uid, 'diet').snapshots().listen((snap) {
      if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) return;
      final d = snap.data(), at = d == null ? null : _at(d);
      if (d == null || at == null || at.compareTo(s.chartAt) <= 0 || d['byUid'] == u.uid) {
        return;
      }
      try {
        final chart = [for (final m in jsonDecode(d['data'] as String) as List) Meal.from(m as Map)];
        final undo = s.snapshot();
        final by = d['byName'] as String? ?? 'Your trainer';
        s.setChart(chart, by: by, changes: [for (final c in d['changes'] as List? ?? const []) c as String], at: at);
        planEvents.value = (text: 'New diet chart from $by', undo: undo, kind: 'diet', at: at);
      } catch (e) {
        debugPrint('Cloud.diet: $e');
      }
    });
    _gymSub = _plan(u.uid, 'gym').snapshots().listen((snap) {
      if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) return;
      final d = snap.data(), at = d == null ? null : _at(d);
      if (d == null || at == null || at.compareTo(s.gymAt) <= 0 || d['byUid'] == u.uid) {
        return;
      }
      try {
        final undo = s.snapshot();
        final by = d['byName'] as String? ?? 'Your trainer';
        s.setWorkout(
          jsonDecode(d['data'] as String) as Map,
          by: by,
          changes: [for (final c in d['changes'] as List? ?? const []) c as String],
          at: at,
        );
        planEvents.value = (text: 'New workout from $by', undo: undo, kind: 'gym', at: at);
      } catch (e) {
        debugPrint('Cloud.gym: $e');
      }
    });
    _cookSub = _plan(u.uid, 'cook').snapshots().listen((snap) {
      if (!_sameSession(generation, u.uid) || s.ownerUid != u.uid) return;
      final d = snap.data(), at = d == null ? null : _at(d);
      if (d == null || at == null || at.compareTo(s.cookAt) <= 0 || d['byUid'] == u.uid) {
        return;
      }
      if (d['day'] != s.today) return; // yesterday's cooking is over
      final undo = s.snapshot();
      final said = s.applyCook(Map<String, int>.from(d['picks'] as Map), at: at);
      if (said.isNotEmpty) {
        planEvents.value = (
          text: '${d['byName'] ?? 'Your helper'} is cooking · ${said.join(', ')}',
          undo: undo,
          kind: 'cook',
          at: at,
        );
      }
    });
  }

  /// The trainer (or the owner) saves [owner]'s diet chart; [changes] says what changed, briefly.
  Future<String?> saveChart(String owner, List<Meal> chart, List<String> changes) async {
    final u = user;
    if (u == null) return 'Sign in first.';
    try {
      await _plan(owner, 'diet').set({
        'data': jsonEncode([for (final m in chart) m.toJson()]),
        'changes': [for (final c in changes.take(10)) c.substring(0, c.length.clamp(0, 120))],
        'byUid': u.uid,
        'byName': _name(u, 'Your trainer'),
        'at': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return 'Couldn\'t save (${e.code}).';
    }
  }

  /// The trainer saves [owner]'s workout ([Store.workout] shape); [changes] says what changed.
  Future<String?> saveWorkout(String owner, Map<String, List<List<Object>>> workout, List<String> changes) async {
    final u = user;
    if (u == null) return 'Sign in first.';
    try {
      await _plan(owner, 'gym').set({
        'data': jsonEncode(workout),
        'changes': [for (final c in changes.take(10)) c.substring(0, c.length.clamp(0, 120))],
        'byUid': u.uid,
        'byName': _name(u, 'Your trainer'),
        'at': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return 'Couldn\'t save (${e.code}).';
    }
  }

  /// A helper picks what to cook for [mealId] today; picks for other meals today stay.
  Future<String?> pickToCook(String owner, String mealId, int option) async {
    final u = user;
    if (u == null) return 'Sign in first.';
    final today = dayKey(DateTime.now());
    try {
      final cur = (await _plan(owner, 'cook').get()).data();
      final picks = cur != null && cur['day'] == today ? Map<String, int>.from(cur['picks'] as Map) : <String, int>{};
      picks[mealId] = option;
      await _plan(owner, 'cook').set({
        'picks': picks,
        'day': today,
        'byUid': u.uid,
        'byName': _name(u, 'Your helper'),
        'at': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return 'Couldn\'t save (${e.code}).';
    }
  }

  // ---- AI quota: one shared count per Pacific day, because Google's free limit is per project ----

  /// Estimates made today by everyone (signed in), or null when signed out / offline.
  Future<Map<String, int>?> aiUsage(String day) async {
    if (user == null) return null;
    try {
      final d = (await _db.collection('aiUsage').doc(day).get()).data() ?? const {};
      return {
        for (final k in const ['flash', 'lite']) k: (d[k] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('Cloud.aiUsage: $e');
      return null;
    }
  }

  Future<void> countAi(String day, String key) async {
    if (user == null) return;
    try {
      await _db.collection('aiUsage').doc(day).set({
        key: FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Cloud.countAi: $e');
    }
  }

  /// Everyone's row, live.
  Stream<List<Map<String, dynamic>>> board(String code) => _family(code)
      .collection('board')
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs) {...d.data(), 'uid': d.id},
        ],
      );

  Future<String?> _fail(String msg) async {
    debugPrint('Cloud: $msg');
    _set(error: msg);
    return msg;
  }

  void _set({bool? busy, String? error, bool synced = false}) {
    if (busy != null) this.busy = busy;
    if (error != null || synced) this.error = error;
    if (synced) lastSync = DateTime.now();
    notifyListeners();
  }
}
