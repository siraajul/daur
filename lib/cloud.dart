import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'plan.dart';
import 'store.dart';

/// Google Sign-In + Firestore backup/sync for Daur.
///
/// Data model (see firestore.rules, database `daur`):
///   users/{uid}            profile: uid, displayName, email, photoUrl, createdAt, updatedAt
///   users/{uid}/state/app  the whole app state as JSON (the Store), schema, device, updatedAt
///
/// The app keeps working offline from the phone's own storage. When signed in, every change is
/// pushed a few seconds later, and on sign-in the newer copy (phone or cloud) wins.
class Cloud extends ChangeNotifier {
  Cloud._();
  static final instance = Cloud._();

  static const _databaseId = 'daur'; // Enterprise edition requires a named database
  static const _schema = 1;
  static const _maxBytes = 900000; // matches the size limit in firestore.rules

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: _databaseId);

  Store? _store;
  Timer? _debounce;
  bool _pulling = false;
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
        if (idToken == null) return await _fail('Google did not return a sign-in token. Try again.');
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
    _debounce?.cancel();
    if (s.familyId != null) await leaveFamily();
    _deleting = true;
    try {
      await _state(u.uid).delete();
      await _profile(u.uid).delete();
      try {
        await u.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        final err = await signInWithGoogle();
        if (err != null) return err;
        await _auth.currentUser?.delete();
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
    } catch (e) {
      return 'Couldn\'t delete: $e';
    } finally {
      _deleting = false;
    }
  }

  Future<void> signOut() async {
    _debounce?.cancel();
    if (signedIn) await _push(); // last changes up before leaving
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
    if (s == null || _deleting) return;
    try {
      await _writeProfile(u);
      final remote = await _state(u.uid).get();
      final data = remote.data()?['data'];
      // someone else's laps are on this phone (a shared phone, a family member signing in)
      final otherPerson = s.ownerUid != null && s.ownerUid != u.uid;
      if (data is String) {
        final remoteSavedAt = (jsonDecode(data) as Map<String, dynamic>)['savedAt'] as int? ?? 0;
        // A fresh install or another person's data always restores; otherwise the newer copy wins.
        if (otherPerson || !s.onboarded || remoteSavedAt > s.savedAt) {
          _pulling = true;
          s.adoptCloud(data);
          s.claim(u.uid);
          _pulling = false;
          _set(synced: true);
          return;
        }
      } else if (otherPerson) {
        _pulling = true;
        s.startFresh(u.uid); // nothing of theirs in the cloud yet: onboarding, not the last person's laps
        _pulling = false;
        return;
      }
      _pulling = true;
      s.claim(u.uid);
      _pulling = false;
      await _push();
    } catch (e) {
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

  Future<void> _push() async {
    final u = user, s = _store;
    if (u == null || s == null || _deleting) return;
    final data = s.snapshot();
    if (data.length > _maxBytes) {
      await _fail('Too much data to back up (${data.length ~/ 1000} KB).');
      return;
    }
    try {
      await _state(u.uid).set({
        'data': data,
        'schema': _schema,
        'device': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _set(synced: true);
    } catch (e) {
      _fail('Backup failed: $e');
    }
    await pushBoard();
    await pushCoaching();
  }

  // ---- family board ----

  DocumentReference<Map<String, dynamic>> _family(String code) => _db.collection('families').doc(code);

  /// This person's row on their family board: streak, today's meals, a perfect day. No email.
  Future<void> pushBoard() async {
    final u = user, s = _store, code = s?.familyId;
    if (u == null || s == null || code == null) return;
    try {
      await _family(code).collection('board').doc(u.uid).set({
        'name': (u.displayName ?? '').isEmpty
            ? 'Family member'
            : u.displayName!.substring(0, u.displayName!.length.clamp(0, 60)),
        if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
        'streak': s.streak,
        'legs': s.legsDone,
        'day': s.today,
        'perfect': s.perfect(s.today),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Cloud.pushBoard: $e');
    }
  }

  /// A new board with a random 8-character code to share (no 0/O or 1/I to misread).
  Future<String?> createFamily() async {
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
      s.setFamily(code);
      await pushBoard();
      return null;
    } catch (e) {
      return 'Couldn\'t create it: $e';
    }
  }

  Future<String?> joinFamily(String input) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    final code = input.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) return 'A code is 8 letters and numbers.';
    try {
      await _family(code).update({
        'members': FieldValue.arrayUnion([u.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      s.setFamily(code);
      await pushBoard();
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'not-found' ? 'No family with that code.' : 'Couldn\'t join (${e.code}). Is the board full (8)?';
    }
  }

  Future<void> leaveFamily() async {
    final u = user, s = _store, code = s?.familyId;
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
      debugPrint('Cloud.leaveFamily: $e');
    }
    s.setFamily(null);
  }

  // ---- coaching: a mother for the diet, a trainer; they follow this person's plan ----
  //
  // invites/{code}              who made the code and for which role (diet | trainer)
  // coaching/{owner}            the owner's progress summary, readable by their helpers
  // coaching/{owner}/helpers/{uid}  one per helper, written by the helper with a valid code
  // coaching/{owner}/notes/{id}     notes both ways ("less rice tonight")

  DocumentReference<Map<String, dynamic>> _coach(String owner) => _db.collection('coaching').doc(owner);

  String _name(User u, String fallback) =>
      (u.displayName ?? '').isEmpty ? fallback : u.displayName!.substring(0, u.displayName!.length.clamp(0, 60));

  /// Publishes today's summary for helpers, once this person has invited someone.
  Future<void> pushCoaching() async {
    final u = user, s = _store;
    if (u == null || s == null || s.inviteCodes.isEmpty || s.helperOnly) return;
    try {
      await _coach(u.uid).set({
        'ownerUid': u.uid,
        'name': _name(u, 'Daur'),
        if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
        'data': jsonEncode(s.coachSummary()),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Cloud.pushCoaching: $e');
    }
  }

  /// A code for a helper with [role] ('diet' or 'trainer'), reusable until revoked.
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
      debugPrint('Cloud.revokeInvite: $e');
    }
    s.setInvite(role, null);
  }

  /// Join someone as their helper with the code they shared. Returns an error message or null.
  Future<String?> joinAsHelper(String input) async {
    final u = user, s = _store;
    if (u == null || s == null) return 'Sign in first.';
    final code = input.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) return 'A code is 8 letters and numbers.';
    try {
      final inv = (await _db.collection('invites').doc(code).get()).data();
      if (inv == null) return 'No invite with that code.';
      final owner = inv['ownerUid'] as String, role = inv['role'] as String;
      if (owner == u.uid) return 'That\'s your own code: share it with your helper.';
      await _coach(owner).collection('helpers').doc(u.uid).set({
        'name': _name(u, 'Helper'),
        if ((u.photoURL ?? '').startsWith('https://')) 'photoUrl': u.photoURL!,
        'role': role,
        'code': code,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      final name = (await _coach(owner).get()).data()?['name'] as String? ?? 'Your person';
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
      debugPrint('Cloud.leaveHelping: $e');
    }
    _store?.removeHelping(owner);
  }

  Future<void> removeHelper(String helperUid) async {
    final u = user;
    if (u == null) return;
    try {
      await _coach(u.uid).collection('helpers').doc(helperUid).delete();
    } catch (e) {
      debugPrint('Cloud.removeHelper: $e');
    }
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

  /// [owner]'s summary as a helper sees it, live (null until they have published one).
  Stream<({String name, String? photo, Map<String, dynamic> data, DateTime? at})?> progress(String owner) =>
      _coach(owner).snapshots().map((d) {
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
      debugPrint('Cloud.deleteNote: $e');
    }
  }

  // ---- the diet chart (the trainer writes it) and today's cooking (a helper picks options) ----
  //
  // coaching/{owner}/plan/diet  data: the chart as JSON, changes: what changed in words
  // coaching/{owner}/plan/cook  picks: {meal id: option} for one day
  // The owner's phone applies both as they arrive (with Undo); everyone reads the chart back from
  // the owner's summary, so it always shows what the owner actually has.

  DocumentReference<Map<String, dynamic>> _plan(String owner, String doc) => _coach(owner).collection('plan').doc(doc);

  /// Plan changes applied on this phone: a message to show and the state to restore on Undo.
  final planEvents = ValueNotifier<({String text, String undo, String kind, String at})?>(null);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _dietSub, _cookSub;

  static String? _at(Map<String, dynamic> d) => (d['at'] as Timestamp?)?.toDate().toIso8601String();

  /// Listen for a new chart or cooking picks while this person has helpers.
  void _watchPlan() {
    _dietSub?.cancel();
    _cookSub?.cancel();
    final u = user, s = _store;
    if (u == null || s == null || s.inviteCodes.isEmpty || s.helperOnly) return;
    _dietSub = _plan(u.uid, 'diet').snapshots().listen((snap) {
      final d = snap.data(), at = d == null ? null : _at(d);
      if (d == null || at == null || at.compareTo(s.chartAt) <= 0 || d['byUid'] == u.uid) return;
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
    _cookSub = _plan(u.uid, 'cook').snapshots().listen((snap) {
      final d = snap.data(), at = d == null ? null : _at(d);
      if (d == null || at == null || at.compareTo(s.cookAt) <= 0 || d['byUid'] == u.uid) return;
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
