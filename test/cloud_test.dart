import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daur/cloud.dart';
import 'package:daur/store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PausableFirestore extends FakeFirebaseFirestore {
  Completer<void>? entered, release;
  void pauseNextTransaction() {
    entered = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final gate = release;
    if (gate != null) {
      release = null;
      entered!.complete();
      await gate.future;
    }
    return super.runTransaction(handler, timeout: timeout, maxAttempts: maxAttempts);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Store store;
  late MockFirebaseAuth auth;
  late PausableFirestore db;
  late Cloud cloud;
  const uid = 'person-a';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.load();
    store.finishOnboarding(start: DateTime.now(), kg: 75);
    store.claim(uid);
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'a@example.com'),
    );
    db = PausableFirestore();
    cloud = Cloud.forTesting(auth: auth, db: db, store: store);
    await cloud.retrySync();
    expect(cloud.error, isNull);
  });

  test('unseen remote edits cannot be overwritten; resolving retains losing copy', () async {
    final ref = db.doc('users/$uid/state/app');
    final original = (await ref.get()).data()!['data'] as String;
    final changed = jsonDecode(original) as Map<String, dynamic>;
    changed['startKg'] = 81.0;
    final remote = jsonEncode(changed);
    await ref.update({'data': remote});
    store.setWater(3);
    await cloud.flushForTesting();
    expect(cloud.conflictData, remote);
    expect((await ref.get()).data()!['data'], remote);
    final local = store.snapshot();
    await cloud.resolveConflict(useCloud: false);
    expect(cloud.conflictData, isNull);
    expect((await ref.get()).data()!['data'], local);
    expect(await cloud.recoveredSyncCopy(), remote);
    expect(store.startKg, 75);
    expect(cloud.error, isNull);
  });

  test('cloud choice preserves local recovery and unresolved conflict blocks sign-out', () async {
    final ref = db.doc('users/$uid/state/app');
    final changed = jsonDecode((await ref.get()).data()!['data'] as String) as Map<String, dynamic>;
    changed['startKg'] = 83.0;
    await ref.update({'data': jsonEncode(changed)});
    store.setWater(2);
    await cloud.flushForTesting();
    final local = store.snapshot();
    await expectLater(cloud.signOut(), throwsStateError);
    expect(auth.currentUser!.uid, uid);
    await cloud.resolveConflict(useCloud: true);
    expect(store.startKg, 83);
    expect(store.ownerUid, uid);
    expect(await cloud.recoveredSyncCopy(), local);
    expect((jsonDecode((await ref.get()).data()!['data'] as String) as Map)['startKg'], 83);
  });

  test('edits arriving during a transaction flush before its shared future completes', () async {
    store.setWater(1);
    db.pauseNextTransaction();
    final entered = db.entered!, release = db.release!;
    final first = cloud.flushForTesting();
    await entered.future;
    store.setWater(5);
    final second = cloud.flushForTesting();
    release.complete();
    await Future.wait([first, second]);
    final backedUp = jsonDecode((await db.doc('users/$uid/state/app').get()).data()!['data'] as String) as Map;
    expect(backedUp, jsonDecode(store.snapshot()));
    expect(cloud.syncing, isFalse);
    expect(cloud.error, isNull);
  });

  test('signing out during a pending transaction cannot publish its captured state', () async {
    final ref = db.doc('users/$uid/state/app');
    final before = (await ref.get()).data()!['data'];
    store.setWater(6);
    db.pauseNextTransaction();
    final entered = db.entered!, release = db.release!;
    final flush = cloud.flushForTesting();
    await entered.future;
    await auth.signOut();
    release.complete();
    await flush;
    expect((await ref.get()).data()!['data'], before);
    expect(cloud.error, isNull);
  });
}
