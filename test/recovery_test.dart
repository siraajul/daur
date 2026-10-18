import 'dart:convert';

import 'package:daur/store.dart';
import 'package:daur/plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Store> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.finishOnboarding(start: DateTime.now(), kg: 75);
    s.setProfile(const Profile(male: false, age: 32, heightCm: 165));
    await s.saved;
    return s;
  }

  test('corrupt current data recovers previous copy without erasing damaged bytes', () async {
    final s = await fresh();
    s.setWater(4);
    await s.saved;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daur', '{broken');
    final recovered = await Store.load();
    expect(recovered.onboarded, isTrue);
    expect(recovered.startKg, 75);
    expect(recovered.recoveryNotice, contains('Recovered'));
    expect(prefs.getString('daur.corrupt'), '{broken');
  });

  test('unrecoverable storage opens usable fresh state and retains corrupt copy', () async {
    SharedPreferences.setMockInitialValues({'daur': '[]'});
    final s = await Store.load();
    expect(s.onboarded, isFalse);
    expect(s.recoveryNotice, isNotNull);
    expect((await SharedPreferences.getInstance()).getString('daur.corrupt'), '[]');
  });

  test('invalid and future backups cannot replace existing data', () async {
    final s = await fresh();
    s.setWater(6);
    await s.saved;
    final raw = jsonDecode(s.snapshot()) as Map<String, dynamic>;
    raw['backupVersion'] = 99;
    await expectLater(s.importBackup(jsonEncode(raw)), throwsFormatException);
    expect(s.water, 6);
    raw['backupVersion'] = 1;
    raw['weights'] = 'bad';
    await expectLater(s.importBackup(jsonEncode(raw)), throwsFormatException);
    expect(s.water, 6);
    expect(s.startKg, 75);
  });

  test('import retains account and consent, removes imported links, supports undo', () async {
    final s = await fresh();
    s.claim('current');
    s.setWater(3);
    await s.saved;
    final raw = jsonDecode(s.snapshot()) as Map<String, dynamic>;
    raw['water'] = 9;
    raw['ownerUid'] = 'foreign';
    raw['familyId'] = 'ABCDEFGH';
    raw['inviteCodes'] = {'partner': 'ABCDEFGH'};
    raw['crashReports'] = true;
    await s.importBackup(jsonEncode(raw));
    expect(s.water, 9);
    expect(s.ownerUid, 'current');
    expect(s.familyId, isNull);
    expect(s.inviteCodes, isEmpty);
    expect(s.crashReports, isFalse);
    expect(s.canUndoImport, isTrue);
    await s.undoImport();
    expect(s.water, 3);
    expect(s.ownerUid, 'current');
  });

  test('erase drains pending saves and removes all drafts and recovery copies', () async {
    final s = await fresh();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daur.onboarding.draft.v1', '{}');
    await prefs.setString('daur.syncRecovery.person', s.snapshot());
    await prefs.setString('daur.syncBase.person', s.snapshot());
    await prefs.setString('other.app', 'keep');
    s.setWater(4);
    s.setWater(5);
    s.eraseAll();
    await s.saved;
    expect(prefs.getKeys().where((key) => key.startsWith('daur.')), isEmpty);
    expect(prefs.getString('other.app'), 'keep');
    expect((await Store.load()).onboarded, isFalse);
  });

  test('preferences persist, filter meals without rewriting eaten records, training keeps history', () async {
    final s = await fresh();
    s.logMeal(meals[1]);
    final eaten = s.chosen(meals[1]).name;
    s.logSet(s.exercises.first, 8, 10);
    final history = jsonEncode(s.snapshot());
    s.setPreferences(diet: 'vegetarian', allergies: 'Peanuts', language: 'bn');
    expect(s.acceptsFood('Chicken curry'), isFalse);
    expect(s.acceptsFood('Fish curry'), isFalse);
    expect(s.acceptsFood('Dal'), isTrue);
    expect(s.chosen(meals[1]).name, eaten);
    s.applyTrainingSetup('home');
    expect(s.exercises, contains('Bodyweight squat'));
    expect(s.setLog, isNotEmpty);
    expect(history, isNotEmpty);
    s.setModule('social', false);
    await s.saved;
    final restored = await Store.load();
    expect(restored.trainingSetup, 'home');
    expect(restored.allergyNotes, 'Peanuts');
    expect(restored.appLanguage, 'bn');
    expect(restored.enabledModules, isNot(contains('social')));
  });

  test('cloud account release clears access links but keeps tracking data', () async {
    final s = await fresh();
    s.claim('deleted');
    s.setFamily('ABCDEFGH');
    s.setFriends('BCDEFGHJ');
    s.setInvite('partner', 'CDEFGHJK');
    s.addHelping('other', 'Person', 'trainer');
    s.setWater(5);
    s.releaseOwner();
    await s.saved;
    expect(s.ownerUid, isNull);
    expect(s.familyId, isNull);
    expect(s.friendsId, isNull);
    expect(s.inviteCodes, isEmpty);
    expect(s.helping, isEmpty);
    expect(s.water, 5);
    expect(s.onboarded, isTrue);
  });

  test('restarting archives programme and retains tracking history', () async {
    final s = await fresh();
    s.logWeight(74);
    s.setWater(5);
    s.pauseProgramme(true);
    expect(s.programmePausedOn, isNotNull);
    s.pauseProgramme(false);
    expect(s.programmePausedOn, isNull);
    s.chooseFinish('again');
    await s.saved;
    expect(s.programmes, hasLength(1));
    expect(s.startKg, 74);
    expect(s.weights, isNotEmpty);
    expect(s.waterHistory, isNotEmpty);
    expect((await Store.load()).programmes, hasLength(1));
  });
}
