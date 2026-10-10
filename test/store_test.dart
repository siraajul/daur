import 'dart:convert';

import 'package:daur/badges.dart';
import 'package:daur/couple.dart' show SideBySide;
import 'package:daur/diet_chart.dart' show chartChanges;
import 'package:daur/fasting.dart' show stageAt;
import 'package:daur/meal_ai.dart';
import 'package:daur/plan.dart';
import 'package:daur/ramadan.dart';
import 'package:daur/reminders.dart';
import 'package:daur/foods.dart';
import 'package:daur/store.dart';
import 'package:daur/students.dart' show studentFlags;
import 'package:daur/targets.dart';
import 'package:daur/today.dart' show thousands;
import 'package:daur/water_walk.dart' show litres;
import 'package:daur/workout_editor.dart' show workoutChanges, workoutFrom, workoutJson;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('day key is the local calendar date, zero-padded', () {
    expect(dayKey(DateTime(2026, 10, 9, 5, 30)), '2026-10-09'); // 05:30 local is still the 9th
  });

  test('step target builds 7k → 8k → 10k', () {
    expect([stepTargetForDay(1), stepTargetForDay(15), stepTargetForDay(29)], [7000, 8000, 10000]);
  });

  test('logging meals adds up kcal, protein and lap distance; reload keeps it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.lap, 1);
    s.choose(meals[2], 3); // snack: gym day
    s.toggleMeal(meals[0]);
    s.toggleMeal(meals[2]);
    expect(s.mealsDone, 2);
    expect(s.kcal, 402 + 212); // default breakfast is Eggs + oats (the protein-complete day)
    expect(s.protein, 24 + 25);
    expect(s.nextMeal, meals[1]);
    s.logWeight(108.4);
    s.logWeight(108.2); // same day replaces
    expect(s.weights.single.kg, 108.2);

    final again = await Store.load();
    expect(again.mealsDone, 2);
    expect(again.chosen(meals[2]).name, 'Gym day: banana + whey');
  });

  test('gym sets: log, done after planned sets, a missed rep keeps the plan, last session', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    const ex = 'Romanian deadlift';
    expect(s.plan(ex).kg, 40);
    s.logSet(ex, 10, 42.5);
    expect(s.exerciseDone(ex), isFalse);
    s.logSet(ex, 10, 42.5);
    s.logSet(ex, 9, 42.5);
    expect(s.exerciseDone(ex), isTrue);
    expect(s.plan(ex).kg, 40); // 9 of 10 reps on the last set: same plan, never lowered
    expect(s.setsDoneToday, 3);
    expect(s.lastSession(ex), isNull); // only today so far

    s.setLog[ex]!['2000-01-01'] = [const SetLog(10, 37.5)];
    expect(s.lastSession(ex)!.$1, '2000-01-01');

    s.addCardio(const Cardio(1104, 1.74, 165, 5.8, 6));
    final again = await Store.load();
    expect(again.setsToday(ex).length, 3);
    expect(again.cardio.single.km, 1.74);
  });

  test('changed food: portion, something else, skip, extras, exact undo', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final lunch = meals[1], snack = meals[2], dinner = meals[3];

    s.logMeal(lunch, portionX: 1.5); // 1½ × chicken (640 kcal)
    expect(s.mealKcal(lunch), 960);

    final before = s.snapshot();
    s.logMeal(
      snack,
      instead: [const Eaten('Singara', 150, 3, rare: true, qty: 2), const Eaten('Tea, milk + sugar', 70, 1)],
    );
    expect(s.mealKcal(snack), 370);
    expect(s.mealRare(snack), isTrue);
    expect(s.mealLabel(snack), '2 × Singara, Tea, milk + sugar');
    expect(s.recentFoods.first, 'Tea, milk + sugar');

    s.restore(before); // undo puts back exactly the earlier state
    expect(s.done.containsKey(snack.id), isFalse);
    expect(s.mealKcal(lunch), 960);

    s.logMeal(meals[0]); // breakfast as planned, Eggs + oats 402
    s.skipMeal(snack);
    expect(s.nextMeal, dinner); // skipped meals don't block the next one
    expect(s.mealsDone, 2); // eaten
    expect(s.legsDone, 3); // but a skip is an honest leg: the runner moves

    s.addExtras([const Eaten('Roshogolla', 130, 2, rare: true)]);
    expect(s.kcal, 402 + 960 + 130);
    expect(s.rareToday, 1);
  });

  test('water and steps history for the week screens', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setWater(7);
    s.setManualSteps(5410);
    final days = s.lastDays(7);
    expect(days.length, 7);
    expect(days.last, s.today);
    expect(s.waterHistory[s.today], 7);
    expect(s.stepsHistory[s.today], 5410);
    expect(s.stepTargetOn(s.today), 7000); // day 1 of the cut
    s.setManualSteps(null);
    expect(s.stepsHistory.containsKey(s.today), isFalse);
  });

  test('weekly junk count: month 1 allows none, then 1 a week, counted per cut week', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.junkAllowance, 0); // day 1 is month 1

    final t = DateTime.now();
    s.startDay = dayKey(DateTime(t.year, t.month, t.day - 37)); // today is day 38: week 6, 3rd day
    expect(s.lap, 38);
    expect(s.cutWeek, 6);
    expect(s.junkAllowance, 1);
    expect(s.weekDaysSoFar.length, 3);

    s.junkHistory[s.lastDays(2).first] = 1; // yesterday, same week
    s.junkHistory[s.lastDays(4).first] = 1; // 3 days ago: day 35, last week, not counted
    expect(s.junkThisWeek, 1);

    s.logMeal(meals[2], instead: [const Eaten('Singara', 150, 3, rare: true)]);
    expect(s.junkThisWeek, 2);
    expect(s.junkHistory[s.today], 1);
    expect(s.weekResets, DateTime(t.year, t.month, t.day + 5)); // day 43 starts week 7
  });

  test('onboarding sets day 1 and starting weight, once', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.onboarded, isFalse);
    final t = DateTime.now();
    s.finishOnboarding(start: DateTime(t.year, t.month, t.day - 9), kg: 108.6);
    expect(s.lap, 10);
    expect(s.bodyKg, 108.6); // no weigh-ins yet: calorie estimates use the start weight
    final again = await Store.load();
    expect(again.onboarded, isTrue);
    expect(again.startKg, 108.6);
  });

  test('reminders: only what is still useful, nothing once done, pause skips today', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    final noon = DateTime(t.year, t.month, t.day, 12);
    expect(Reminders.plan(s, noon), isEmpty); // off until turned on

    s.setReminders(true);
    s.logMeal(meals[0]); // breakfast eaten
    s.setWater(9); // already past the 14:30 goal
    final p = Reminders.plan(s, noon, steps: 3000);
    String at(Planned x) => '${x.when.day == t.day ? 'today' : 'tomorrow'} ${x.channel} ${x.title}';
    final today = p.where((x) => x.when.day == t.day).map(at).toList();
    expect(today.any((x) => x.contains('Breakfast')), isFalse); // logged → quiet
    expect(today.any((x) => x.contains('Lunch · 13:00')), isTrue);
    expect(today.where((x) => x.contains('water')).length, 1); // only the 18:00 check is still ahead of 9 glasses
    expect(today.any((x) => x.contains('Walk · 3,000 of 7,000')), isTrue);
    expect(p.every((x) => x.when.isAfter(noon)), isTrue);
    expect(p.every((x) => x.when.hour >= 7 && x.when.hour < 22), isTrue); // quiet hours
    expect(p.map((x) => x.id).toSet().length, p.length); // unique ids
    expect(p.any((x) => at(x).startsWith('tomorrow') && x.title.startsWith('Breakfast')), isTrue);

    s.setPausedToday(true);
    expect(Reminders.plan(s, noon).where((x) => x.when.day == t.day && x.channel != 'checkins'), isEmpty);
  });

  test('hints: first-win tip, one card a day, drawer dot; welcome back; end of the cut', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    s.finishOnboarding(start: DateTime(t.year, t.month, t.day - 1), kg: 109); // lap 2
    expect(s.showFirstWin, isTrue);
    s.logMeal(meals[0]);
    expect(s.showFirstWin, isFalse);
    expect(s.coachCard(), 'reminders'); // lap 2, a meal logged, reminders off
    expect(s.coachCard(), 'reminders'); // same card all day
    s.dismissHint('reminders');
    expect(s.coachCard(), isNull); // one card a day
    expect(s.drawerDot, isFalse); // from lap 3

    s.lastOpenDay = dayKey(DateTime(t.year, t.month, t.day - 3));
    expect(s.markOpened(), 3);
    expect(s.markOpened(), 0);

    s.startDay = dayKey(DateTime(t.year, t.month, t.day - 83)); // lap 84
    expect(s.needsFinishChoice, isTrue);
    s.chooseFinish('maintenance');
    expect(s.kcalGoal, kcalTarget + 500);
    expect(s.needsFinishChoice, isFalse);
    s.finishChoice = null;
    s.chooseFinish('again');
    expect(s.lap, 1);
    expect(s.cutRound, 2);
  });

  test('your own foods: add, edit with rename, delete; serving and category survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.saveCustomFood(const Eaten('Beef khichuri', 520, 22, portion: '1 plate', cat: 'office-lunch'));
    s.saveCustomFood(const Eaten('Bhapa pitha', 180, 3, rare: true, cat: 'sweet'));
    expect(s.customFoods.map((e) => e.name), ['Bhapa pitha', 'Beef khichuri']);

    s.saveCustomFood(
      const Eaten('Beef khichuri (hotel)', 600, 22, portion: '1 plate', cat: 'office-lunch'),
      replacing: 'Beef khichuri',
    );
    expect(s.customFoods.length, 2);
    expect(s.customFoods.last.name, 'Beef khichuri (hotel)'); // edited in place, not duplicated

    final again = await Store.load();
    final k = again.customFoods.firstWhere((e) => e.kcal == 600);
    expect([k.portion, k.cat], ['1 plate', 'office-lunch']);

    again.removeCustomFood('Bhapa pitha');
    expect(again.customFoods.single.name, 'Beef khichuri (hotel)');
  });

  test('streak counts full laps in a row; medals unlock once from the data', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    String ago(int d) => dayKey(DateTime(t.year, t.month, t.day - d));
    s.lapHistory[ago(1)] = 4;
    s.lapHistory[ago(2)] = 4;
    s.lapHistory[ago(3)] = 3; // broken here
    s.lapHistory[ago(4)] = 4;
    expect(s.streak, 2); // today not finished yet: counts from yesterday
    for (final m in meals) {
      s.logMeal(m);
    }
    expect(s.streak, 3); // today's full lap joins it

    s.startKg = 109;
    s.logWeight(105.0);
    bool has(String id) => medals.firstWhere((b) => b.id == id).earned(s);
    expect(has('weigh-1'), isTrue);
    expect(has('kg-1'), isFalse); // one light morning is not a trend
    s.weights.insertAll(0, [Weigh(ago(2), 106.5), Weigh(ago(1), 106.2)]);
    s.logWeight(106.3); // 7-day average 106.33
    final earned = medals.where((b) => b.earned(s)).map((b) => b.id).toSet();
    expect(earned.containsAll({'weigh-1', 'kg-1', 'kg-2.5'}), isTrue);
    expect(earned.contains('kg-5'), isFalse);
    expect(earned.contains('target-Month 1'), isFalse); // 106.33 > 106
    s.logWeight(105.0); // average 105.9
    expect(has('target-Month 1'), isTrue);
  });

  test('skipping a meal still closes the lap and keeps the streak', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    s.lapHistory[dayKey(DateTime(t.year, t.month, t.day - 1))] = 4;
    for (final m in meals.take(3)) {
      s.logMeal(m);
    }
    s.skipMeal(meals[3]);
    expect(s.legsDone, 4);
    expect(s.lapHistory[s.today], 4);
    expect(s.streak, 2);
  });

  test('progressive overload: all reps → step up, undo reverts, holds and light weights', () {
    expect(Store.progress(const ExPlan(3, 10, 40), const [SetLog(10, 40), SetLog(10, 40), SetLog(11, 40)])!.kg, 42.5);
    expect(Store.progress(const ExPlan(3, 12, 10), const [SetLog(12, 10), SetLog(12, 10), SetLog(12, 10)])!.kg, 11);
    expect(
      Store.progress(const ExPlan(3, 45, 0, timed: true), const [SetLog(45, 0), SetLog(50, 0), SetLog(45, 0)])!.reps,
      50,
    );
    expect(Store.progress(const ExPlan(3, 10, 40), const [SetLog(10, 35), SetLog(10, 35), SetLog(10, 35)]), isNull);
    expect(Store.progress(const ExPlan(3, 10, 40), const [SetLog(10, 40), SetLog(8, 40), SetLog(10, 40)]), isNull);
  });

  test('a step up is announced and undoing the last set takes it back', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    const ex = 'Lat pulldown'; // 3 × 12 at 55
    s.logSet(ex, 12, 55);
    s.logSet(ex, 12, 55);
    expect(s.logSet(ex, 12, 55), 'All sets hit. Next time: 57.5 kg');
    expect(s.plan(ex).kg, 57.5);
    s.undoSet(ex);
    expect(s.plan(ex).kg, 55);
  });

  test('personal plan: computed targets, scaled portions, no instant medals at 70 kg', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect([s.baseKcal, s.proteinText, s.waterGoal, s.planScale], [1800, '130–150', 14, 1.0]); // original plan

    const man = Profile(male: true, age: 30, heightCm: 178);
    expect(man.kcal(109), 1950); // Mifflin 2,057 × 1.2 − 500
    expect(man.protein(109), (125, 160)); // 1.6–2.0 g × 79 kg (BMI 25 at 178 cm)
    expect(man.glasses(109), 15);
    const woman = Profile(male: false, age: 35, heightCm: 160, activity: 1);
    expect(woman.kcal(60) % 50, 0);
    expect(woman.kcal(60), greaterThanOrEqualTo(1200));

    s.startKg = 70;
    s.setProfile(woman);
    expect(s.kcalGoal, s.baseKcal); // the day's target follows the personal plan
    expect(s.planScale, lessThan(1));
    expect(s.mealKcal(meals[1]), (640 * s.planScale).round());
    final t = DateTime.now();
    for (var d = 0; d < 3; d++) {
      s.weights.add(Weigh(dayKey(DateTime(t.year, t.month, t.day - 2 + d)), 70));
    }
    expect(medals.where((b) => b.id.startsWith('target-') && b.earned(s)), isEmpty);
    expect(double.parse(s.targets.first.$2.split('–').last), lessThan(70));
  });

  test('weekly averages, gym sessions, stall detection', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    String ago(int d) => dayKey(DateTime(t.year, t.month, t.day - d));
    s.kcalHistory.addAll({ago(1): 1700, ago(2): 1900});
    s.proteinHistory.addAll({ago(1): 120, ago(2): 140});
    s.logMeal(meals[0]); // today is still running: not in the average
    expect(s.weekFood, (kcal: 1800, protein: 130, days: 2));

    expect(s.gymToday, isFalse);
    s.logSet('Seated row', 12, 50);
    expect(s.gymToday, isTrue);
    expect(s.gymThisWeek, 1);

    s.startDay = ago(30);
    for (final d in [0, 1, 2]) {
      s.weights.add(Weigh(ago(16 + d), 104.0));
      s.weights.add(Weigh(ago(d), 103.6));
    }
    expect(s.stalled, isTrue); // 0.4 kg in two weeks
    s.weights.add(Weigh(ago(3), 102.0));
    expect(s.stalled, isFalse);
  });

  test('another person signing in starts fresh instead of inheriting this phone', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.finishOnboarding(start: DateTime.now(), kg: 109);
    s.logMeal(meals[0]);
    s.claim('siraj');
    s.startFresh('family');
    expect([s.onboarded, s.mealsDone, s.ownerUid], [false, 0, 'family']);
  });

  test('reminders cover a week, so a few days away does not silence them', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    s.setReminders(true);
    final p = Reminders.plan(s, DateTime(t.year, t.month, t.day, 12));
    final last = DateTime(t.year, t.month, t.day + Reminders.days - 1);
    expect(p.any((x) => x.when.day == last.day && x.title.startsWith('Breakfast')), isTrue);
    expect(p.map((x) => x.id).toSet().length, p.length);
    expect(p.every((x) => x.id >= 1000 && x.id < 1400), isTrue);
  });

  test('height in feet and inches: 5′ 7″ is 170 cm, and inch steps round-trip', () {
    expect(feetInches(170), '5′ 7″');
    expect(feetInches(inchesToCm(5 * 12 + 11)), '5′ 11″');
    for (var i = 48; i < 86; i++) {
      expect(cmToInches(inchesToCm(i)), i);
    }
  });

  test('stopping early: done today, plan holds; two short sessions in a row ease the weight', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    const ex = 'Leg press / squat'; // 3 × 12 at 120
    s.logSet(ex, 12, 120);
    s.logSet(ex, 12, 120);
    expect(s.endExercise(ex), isNull); // first short session: same plan
    expect(s.exerciseDone(ex), isTrue);
    expect(s.plan(ex).kg, 120);

    s.setLog[ex]!['2000-01-01'] = s.setLog[ex]!.remove(s.today)!; // that was last time
    s.gymTicks.clear();
    s.logSet(ex, 12, 120);
    expect(s.endExercise(ex), 'Two short sessions · next time 107.5 kg'); // 120 × 0.9 → 107.5
    s.toggleGym(ex); // un-stop takes the deload back
    expect(s.plan(ex).kg, 120);

    expect(Store.isShort(const ExPlan(3, 10, 40), const [SetLog(10, 35)]), isFalse); // lighter by choice
    expect(Store.deload(const ExPlan(3, 45, 0, timed: true))!.reps, 40);
    expect(Store.deload(const ExPlan(3, 10, 0)), isNull); // bodyweight
  });

  test('best streak is the longest run of full days', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    String ago(int d) => dayKey(DateTime(t.year, t.month, t.day - d));
    for (final d in [10, 9, 8, 7, 3, 2]) {
      s.lapHistory[ago(d)] = 4;
    }
    s.lapHistory[ago(5)] = 3;
    expect(s.bestStreak, 4);
    expect(s.streak, 0); // yesterday wasn't full
  });

  test('fasting 16:8: breakfast falls outside 13–21, the other meals carry the day', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final dayBefore = meals.fold(0, (a, m) => a + s.mealKcal(m));
    s.setFast('16:8');
    expect([s.eatStart, s.eatEnd], [13, 21]);
    expect(meals.where(s.fasted).map((m) => m.name), ['Breakfast']);
    expect(s.nextMeal!.name, 'Lunch'); // breakfast isn't waited for
    expect(s.legsDone, 1); // and counts as a leg
    final dayAfter = meals.where((m) => !s.fasted(m)).fold(0, (a, m) => a + s.mealKcal(m));
    expect((dayAfter - dayBefore).abs(), lessThan(5)); // same day, fewer meals

    s.setFast('18:6');
    expect(meals.where((m) => !s.fasted(m)).map((m) => m.name), ['Snack', 'Dinner']);
    s.setFast('16:8', start: 30); // clamped so the window ends by midnight
    expect(s.eatEnd, lessThanOrEqualTo(24));

    s.setReminders(true);
    final t = DateTime.now();
    final p = Reminders.plan(s, DateTime(t.year, t.month, t.day, 6));
    expect(p.any((x) => x.title.startsWith('Breakfast') || x.title.startsWith('Lunch')), isFalse); // 16 → 24 window
  });

  test('spending: month totals, by category, budget', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.addExpense(const Expense('2026-10-01', 3000, 'gym', 'October fee'));
    s.addExpense(const Expense('2026-10-05', 1200, 'food'));
    s.addExpense(const Expense('2026-10-06', 450, 'food'));
    s.addExpense(const Expense('2026-09-28', 5200, 'supp', 'whey'));
    expect(s.spentIn('2026-10'), 4650);
    expect(s.byCategory('2026-10'), {'gym': 3000, 'food': 1650});
    expect(s.expensesIn('2026-10').first.day, '2026-10-06'); // newest first
    s.setBudget(0);
    expect(s.monthBudget, isNull);
    s.setBudget(15000);
    final again = await Store.load();
    expect([again.spentIn('2026-09'), again.monthBudget], [5200, 15000]);
  });

  test('streak freeze: earned on the 7th full day, covers one missed day, the streak carries on', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    String ago(int d) => dayKey(DateTime(t.year, t.month, t.day - d));
    s.startDay = ago(20);
    for (var d = 1; d <= 6; d++) {
      s.lapHistory[ago(d)] = 4;
    }
    for (final m in meals) {
      s.logMeal(m); // 7th full day in a row
    }
    expect([s.streak, s.freezes], [7, 1]);

    // a new morning after one missed day: the freeze covers it and the streak survives
    s.lapHistory.clear();
    for (var d = 2; d <= 8; d++) {
      s.lapHistory[ago(d)] = 4; // 7 full days, then yesterday (ago 1) missed
    }
    s.freezes = 1;
    s.today = ago(1); // the app was last open yesterday
    s.rollover(); // now it's today
    expect(s.frozenDays, {ago(1)});
    expect([s.freezes, s.streak], [0, 7]);

    // two missed days with one freeze: not enough, the streak ends honestly
    s.frozenDays.clear();
    s.lapHistory.remove(ago(2));
    s.freezes = 1;
    s.today = ago(1);
    s.rollover();
    expect([s.frozenDays.isEmpty, s.freezes, s.streak], [true, 1, 0]);
  });

  test('perfect day: meals, water and steps all hit', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    for (final m in meals) {
      s.logMeal(m);
    }
    s.setWater(s.waterGoal);
    expect(s.perfect(s.today), isFalse); // steps missing
    s.noteSteps(7200);
    expect(s.perfect(s.today), isTrue);
    expect(s.week.perfect, 1);
    expect(s.week.full, 1);
  });

  test('streak-at-risk reminder only while today is open', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final t = DateTime.now();
    s.lapHistory[dayKey(DateTime(t.year, t.month, t.day - 1))] = 4;
    s.setReminders(true);
    bool risk() => Reminders.plan(
      s,
      DateTime(t.year, t.month, t.day, 12),
    ).any((x) => x.when.day == t.day && x.channel == 'streak');
    expect(risk(), isTrue);
    expect(
      Reminders.plan(s, DateTime(t.year, t.month, t.day, 12)).firstWhere((x) => x.channel == 'streak').title,
      'Your 1-day streak ends at midnight',
    );
    for (final m in meals) {
      s.logMeal(m);
    }
    expect(risk(), isFalse);
  });

  test('AI grounding: plurals and Bangla find the food list, erase and release work', () async {
    final names = MealAi.references('2 parathas and dim bhaji with cha').map((f) => f.name.toLowerCase()).join(' | ');
    expect(names.contains('paratha'), isTrue);

    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.finishOnboarding(start: DateTime.now(), kg: 109);
    s.claim('siraj');
    s.releaseOwner();
    expect(s.ownerUid, isNull);
    s.eraseAll();
    expect([s.onboarded, s.weights.isEmpty], [false, true]);
  });

  test('AI quota: counted per Pacific day, a refusal marks the model used up, a new day starts fresh', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(MealAi.quotaDay()), isTrue);
    expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(MealAi.resetsAt()), isTrue);
    s.noteAi('2026-10-09', 'flash');
    s.noteAi('2026-10-09', 'flash');
    s.noteAi('2026-10-09', 'lite', to: 500); // Google said the lite quota is gone
    expect(s.aiUsedOn('2026-10-09'), {'flash': 2, 'lite': 500});
    expect(s.aiUsedOn('2026-10-10'), isEmpty);
    s.noteAi('2026-10-10', 'lite');
    expect(s.aiUsedOn('2026-10-10'), {'lite': 1});
  });

  test('saved estimates: same meal in other words reuses it, foods are kept with their category', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    const items = [
      Eaten('Paratha', 260, 5, rare: true, qty: 2, cat: 'breakfast'),
      Eaten('Dudh cha', 70, 2, cat: 'drink'),
    ];
    s.saveEstimate('2 Parathas, and dudh cha!', items);
    expect(Store.aiKey('2 parathas with dudh cha'), Store.aiKey('2 Parathas, and dudh cha!'));
    expect(s.hasEstimate('2 parathas with dudh cha'), isTrue);
    expect(s.savedEstimate('2 parathas dudh cha')!.first.qty, 2);
    expect(s.aiFoods.map((e) => '${e.name}/${e.cat}'), containsAll(['Paratha/breakfast', 'Dudh cha/drink']));
    s.saveEstimate('paratha', const [Eaten('Paratha', 270, 5, cat: 'breakfast')]);
    expect(s.aiFoods.where((e) => e.name == 'Paratha').single.kcal, 270); // one per name, newest wins
    final again = await Store.load();
    expect(again.hasEstimate('2 parathas, dudh cha'), isTrue); // survives a restart (and syncs)
    again.removeCustomFood('Dudh cha');
    expect(again.aiFoods.any((e) => e.name == 'Dudh cha'), isFalse);
  });

  test('search understands English, Banglish spellings and typos', () {
    List<String> find(String q) => foods.where((f) => f.matches(q)).map((f) => f.name).toList();
    expect(find('milk tea'), contains('Dudh cha (home)')); // translation
    expect(find('milk tea').any((n) => n.startsWith('Coffee')), isFalse); // but not coffee
    for (final q in ['bhat', 'vat', 'bhaat', 'rice']) {
      expect(find(q), contains('Rice (bhaat), 1 cup cooked'), reason: q); // bhat = vat = bhaat = rice
    }
    expect(find('porota'), contains('Paratha (plain, hotel)'));
    expect(find('partha'), contains('Paratha (plain, hotel)')); // typo
    expect(find('paratah'), contains('Paratha (plain, hotel)')); // swapped letters
    expect(find('chiken curry'), contains('Chicken curry (home)'));
    expect(find('biriyani'), contains('Chicken biryani'));
    expect(find('vorta'), contains('Alu bhorta'));
    expect(find('egg'), containsAll(['Dim bhuna', 'Boiled egg (farm)']));
    expect(find('eggplant'), contains('Begun bhorta'));
    expect(find('dal'), isNot(contains('Dates (khejur, dried)'))); // short words stay exact
    expect(Store.aiKey('2 milk tea'), Store.aiKey('2 dudh cha'));
    expect(Store.aiKey('vat and dal'), Store.aiKey('bhat with daal'));
  });

  test('researched vocabulary: murgi, Bangla script, ambiguous words, no false friends', () {
    List<String> find(String q) => foods.where((f) => f.matches(q)).map((f) => f.name).toList();
    expect(find('murgi'), containsAll(['Chicken curry (home)', 'Deshi murgi curry']));
    expect(find('murgir jhol'), contains('Chicken jhol (light, home)'));
    expect(find('ভাত'), contains('Rice (bhaat), 1 cup cooked')); // Bangla script → English name
    expect(find('ডিম'), contains('Dim bhuna'));
    expect(find('golda chingri'), contains('Chingri malai curry'));
    expect(find('aloo'), contains('Alu bhorta'));
    expect(find('shobji'), contains('Mixed sabji / bhaji'));
    expect(find('kola'), contains('Sagor kola (banana)')); // ambiguous: bananas…
    expect(find('morgi'), contains('Deshi murgi curry')); // typo
    expect(find('tea'), isNot(contains('Coffee (instant, milk & sugar)')));
    expect(find('egg'), isNot(contains('Begun bhorta')));
    expect(find('fish'), contains('Rui curry / jhol'));
  });

  test('strength progress: kg, reps, holds since the first session, kept past the history trim', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setLog['Shoulder press'] = {
      '2026-09-01': [const SetLog(10, 14), const SetLog(10, 14)],
      '2026-09-20': [const SetLog(10, 16), const SetLog(8, 16)],
      '2026-10-05': [const SetLog(10, 18)],
    };
    s.setLog['Push-ups'] = {
      '2026-09-01': [const SetLog(10, 0), const SetLog(12, 0)],
      '2026-10-05': [const SetLog(25, 0)],
    };
    s.setLog['Core / plank'] = {
      '2026-09-01': [const SetLog(45, 0)],
      '2026-10-05': [const SetLog(90, 0)],
    };
    final byEx = {for (final r in s.strength) r.ex: r};
    expect([byEx['Shoulder press']!.start, byEx['Shoulder press']!.now, byEx['Shoulder press']!.unit], [14, 18, 'kg']);
    expect([byEx['Push-ups']!.start, byEx['Push-ups']!.now, byEx['Push-ups']!.unit], [12, 25, 'reps']);
    expect([byEx['Core / plank']!.start, byEx['Core / plank']!.now, byEx['Core / plank']!.unit], [45, 90, 's']);
    expect(s.strength.first.ex, 'Push-ups'); // biggest gain first (+108%)

    // the first session survives the history trim
    s.logSet('Seated row', 12, 40);
    expect(s.strengthFirst['Seated row']!.$2.kg, 40);
    expect(planForNew('Wall sit').timed, isTrue);
    expect(planForNew('Push-ups').timed, isFalse);
  });

  test('overall strength: body areas from exercise names, averaged gains', () async {
    expect(
      [
        for (final e in [
          'Leg press / squat',
          'Shoulder press',
          'Lat pulldown',
          'Core / plank',
          'Push-ups',
          'Biceps curl',
          'Triceps pushdown',
          'Romanian deadlift',
        ])
          Store.areaOf(e),
      ],
      ['Legs', 'Push', 'Pull', 'Core', 'Push', 'Pull', 'Push', 'Legs'],
    );
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setLog['Shoulder press'] = {
      '2026-09-01': [const SetLog(10, 14)],
      '2026-10-01': [const SetLog(10, 21)],
    }; // +50%
    s.setLog['Push-ups'] = {
      '2026-09-01': [const SetLog(10, 0)],
      '2026-10-01': [const SetLog(20, 0)],
    }; // +100%
    s.setLog['Lat pulldown'] = {
      '2026-09-01': [const SetLog(12, 50)],
      '2026-10-01': [const SetLog(12, 45)],
    }; // −10%
    final sum = s.strengthSummary;
    expect(sum.areas['Push'], closeTo(.75, 1e-9));
    expect(sum.areas['Pull'], closeTo(-.10, 1e-9));
    expect(sum.areas.containsKey('Legs'), isFalse);
    expect(sum.overall, closeTo((0.5 + 1.0 - 0.1) / 3, 1e-9));
  });

  test('push / pull / legs: split from the old list, rotation, pick, add, move', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.exercisesOn('Push'), ['Chest press / bench press', 'Shoulder press', 'Triceps pushdown']);
    expect(s.exercisesOn('Pull'), ['Lat pulldown', 'Seated row', 'Biceps curl']);
    expect(s.exercisesOn('Legs'), ['Leg press / squat', 'Romanian deadlift', 'Core / plank']);

    final t0 = DateTime.now();
    String ago(int d) => dayKey(DateTime(t0.year, t0.month, t0.day - d));
    expect(s.gymDay, 'Push'); // nothing trained yet
    s.routineLog[ago(2)] = 'Push';
    expect(s.gymDay, 'Pull'); // the one after the last trained day
    s.routineLog[ago(1)] = 'Legs';
    expect(s.gymDay, 'Push'); // wraps round
    s.pickGymDay('Legs');
    expect(s.gymDay, 'Legs'); // picked by hand wins today
    s.logSet('Lat pulldown', 12, 55);
    expect(s.routineLog[s.today], 'Pull'); // what was actually trained is remembered

    s.addExercise('Push-ups', day: 'Push');
    expect(s.exercisesOn('Push').last, 'Push-ups');
    s.moveExercise('Core / plank', 'Push');
    expect(s.exercisesOn('Legs'), isNot(contains('Core / plank')));
    expect(s.exercisesOn('Push'), contains('Core / plank'));
    final again = await Store.load();
    expect(again.exercisesOn('Push'), contains('Push-ups')); // saved
  });

  test('fasting: start/end logs real fasts, short ones dropped, streak, window reminders', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setFast('16:8'); // eats 13:00–21:00
    final now = DateTime.now();
    s.startFast(now.subtract(const Duration(minutes: 10)));
    expect(s.endFast(now)!.inMinutes, 10);
    expect(s.fasts, isEmpty); // under 30 min: not kept
    for (var d = 2; d >= 0; d--) {
      final end = DateTime(now.year, now.month, now.day - d, 12, 30);
      s.startFast(end.subtract(Duration(hours: d == 1 ? 12 : 17)));
      s.endFast(end);
    }
    expect(s.fastMinOn(dayKey(now)), 17 * 60);
    expect(s.fastStreak, 1); // yesterday's 12 h missed the 16 h goal
    expect(stageAt(const Duration(hours: 13)), 3); // burning fat

    final again = await Store.load();
    expect(again.fasts.length, 3); // saved
    again.setReminders(true);
    final morning = DateTime(now.year, now.month, now.day + 1, 6);
    final p = Reminders.plan(again, morning).where((x) => x.channel == 'fasting' && x.when.day == morning.day);
    expect(p.map((x) => '${x.when.hour}:${x.when.minute}'), ['13:0', '20:30']);
  });

  test('21:30 check lists what is still open today, one line each', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setReminders(true);
    s.logMeal(meals[0]);
    s.logMeal(meals[1]);
    s.setWater(10);
    final t = DateTime.now();
    final p = Reminders.plan(s, DateTime(t.year, t.month, t.day, 12), steps: 4000);
    final check = p.firstWhere((x) => x.channel == 'streak' && x.when.day == t.day);
    expect(check.lines, [
      'Snack · not logged yet',
      'Dinner · not logged yet',
      'Water · ${litres(s.waterGoal - 10)} L to go',
      'Steps · 3,000 short',
    ]);
    expect(check.progress, (2, 4));
  });

  test('burn: what is left to burn after eating over the target, and how long it takes', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    expect(s.burnLeft, 0); // nothing eaten
    for (final m in meals) {
      s.logMeal(m);
    }
    s.addExtras([const Eaten('Biryani', 700, 20)]); // on top of the plan's day
    final over = s.kcal - s.kcalGoal;
    expect(over, greaterThan(600));
    expect(s.burnLeft, over); // no exercise yet
    s.noteSteps(8400); // 5,400 over the 3,000 the day job already counts
    expect(s.moved.walk, (5400 / 1350 * .5 * s.bodyKg).round());
    expect(s.burnLeft, over - s.moved.walk);
    s.setReminders(true);
    final t = DateTime.now();
    final evening = Reminders.plan(
      s,
      DateTime(t.year, t.month, t.day, 12),
      steps: 8400,
    ).firstWhere((x) => x.channel == 'walk' && x.when.day == t.day);
    expect(evening.title, 'Walk off ${thousands(s.burnLeft)} kcal');
    expect(evening.payload, 'burn');
    // 109 kg, brisk walk 4.3 MET: about 6 kcal a minute above resting
    expect(s.minutesFor(360, 4.3), inInclusiveRange(59, 61));
  });

  test('coaching: helpers get today, weight and gym, never spending; helping is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.logMeal(meals[0]);
    s.logWeight(108.6);
    s.addExpense(const Expense('2026-10-10', 450, 'food', 'groceries'));
    final sum = s.coachSummary();
    final json = jsonEncode(sum); // must travel as JSON
    expect(json.contains('groceries'), isFalse);
    expect(sum.keys, isNot(contains('expenses')));
    final m = (sum['meals'] as List).first as Map;
    expect(m['status'], 'done');
    expect(sum['kcal'], s.kcal);
    expect((sum['weights'] as List).last, [s.today, 108.6]);

    s.addHelping('owner1', 'Siraj', 'diet');
    s.addHelping('owner1', 'Siraj', 'trainer'); // re-joining replaces
    s.setHelperOnly(true);
    final again = await Store.load();
    expect(again.helping, [
      {'owner': 'owner1', 'name': 'Siraj', 'role': 'trainer'},
    ]);
    expect(again.helperOnly && again.onboarded, isTrue);
  });

  test('goal: lose, keep and gain set the target, month targets, burn or eat, and medals', () async {
    const base = Profile(male: true, age: 30, heightCm: 170);
    final m = base.tdee(70);
    expect(base.kcal(70), lessThan(m)); // lose: under maintenance
    expect((base.copyWith(goal: 1).kcal(70) - m).abs(), lessThan(50)); // keep: maintenance
    expect(base.copyWith(goal: 2).kcal(70), greaterThan(m + 250)); // gain: about 300 over
    double mid(String r) => r.split('–').map(double.parse).reduce((a, b) => a + b) / 2;
    expect(mid(base.targets(70).last.$2), lessThan(70));
    expect(mid(base.copyWith(goal: 1).targets(70).last.$2), 70);
    expect(mid(base.copyWith(goal: 2).targets(70).last.$2), greaterThan(70));

    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setProfile(base.copyWith(goal: 2));
    expect(s.gaining, isTrue);
    s.logMeal(meals[0]);
    expect(s.burnLeft, 0); // a gain never burns off
    expect(s.eatLeft, s.kcalGoal - s.kcal);
    for (final x in meals) {
      s.logMeal(x);
    }
    s.addExtras([const Eaten('Kacchi', 900, 30)]);
    expect(s.eatLeft, 0);
    expect(s.burnLeft, 0);
    final ids = medalsFor(s).map((x) => x.id);
    expect(ids, contains('up-1'));
    expect(ids, isNot(contains('kg-1')));
    expect(s.coachSummary()['goal'], 2);
  });

  test('diet chart: a trainer\'s chart replaces the plan, survives a restart, resets to the plan', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    final lunch = defaultMeals[1].withOptions([
      const MealOption('Beef + rice', ['150 g beef', '1 cup cooked rice', 'Salad'], 620, 45),
    ], 'From Coach Rafi');
    s.setChart([defaultMeals[0], lunch, defaultMeals[2], defaultMeals[3]], by: 'Coach Rafi');
    expect(meals[1].options.single.name, 'Beef + rice');
    s.choose(meals[1], 0);
    expect(s.chosen(meals[1]).items, contains('150 g beef'));

    final again = await Store.load();
    expect(meals[1].options.single.name, 'Beef + rice');
    expect(again.chartBy, 'Coach Rafi');
    expect(again.mealKcal(meals[1]), greaterThan(0));
    // a chart that isn't four meals is ignored, never half-applied
    again.setChart([defaultMeals[0]]);
    expect(meals.length, 4);
    expect(meals[1].name, 'Lunch');
    again.setChart(null);
    expect(meals[1].options.length, defaultMeals[1].options.length);
  });

  test('cooking picks: a helper\'s choice changes what\'s planned, never a meal already eaten', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.logMeal(meals[0]); // breakfast eaten with its default
    final before = s.chosen(meals[0]).name;
    final said = s.applyCook({'m1': 0, 'm4': 1}, at: '2026-10-10T12:00:00.000');
    expect(s.chosen(meals[0]).name, before); // eaten stays eaten
    expect(s.chosen(meals[3]).name, meals[3].options[1].name);
    expect(said, ['Dinner: ${meals[3].options[1].name}']);
    expect(s.applyCook({'m4': 99}, at: '2026-10-10T12:01:00.000'), isEmpty); // out of range: ignored
    expect(s.cookAt, '2026-10-10T12:01:00.000');
    final sum = s.coachSummary();
    expect((sum['chart'] as List).length, 4);
    expect(((sum['meals'] as List)[3] as Map)['option'], 1);
  });

  test('chart changes say what a trainer changed, meal by meal', () {
    final after = [
      defaultMeals[0],
      defaultMeals[1].withOptions([
        defaultMeals[1].options[0],
        const MealOption('Beef + rice', ['150 g beef', '1 cup rice'], 620, 45),
      ]),
      defaultMeals[2],
      defaultMeals[3].withOptions([
        for (final o in defaultMeals[3].options)
          o.name == 'Fish' ? MealOption(o.name, o.items, o.kcal + 40, o.protein) : o,
      ], 'Less oil'),
    ];
    expect(chartChanges(defaultMeals, after), [
      'Lunch: Beef + rice added',
      'Lunch: Fish: rui + 1 cup rice removed',
      'Dinner: Fish changed',
      'Dinner: note changed',
    ]);
    expect(chartChanges(defaultMeals, defaultMeals), isEmpty);
  });

  test('workout: a trainer\'s workout replaces the list and plans, keeps history, round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.logSet('Lat pulldown', 12, 55);
    final before = workoutFrom(s.workout);
    expect(before['Pull']!.map((x) => x.$1), contains('Lat pulldown'));

    final after = workoutFrom(s.workout);
    after['Push']!.add(('Dips', const ExPlan(3, 8, 0)));
    after['Pull']!.removeWhere((x) => x.$1 == 'Seated row');
    after['Legs']![0] = (after['Legs']![0].$1, const ExPlan(4, 10, 130));
    expect(workoutChanges(before, after), [
      'Push: Dips added',
      'Pull: Seated row removed',
      'Legs: ${after['Legs']![0].$1} 4 × 10 · 130 kg',
    ]);
    expect(workoutChanges(before, before), isEmpty);

    // through JSON, as it travels via Firestore
    s.setWorkout(jsonDecode(jsonEncode(workoutJson(after))) as Map, by: 'Coach Rafi', at: '2026-10-10T12:00:00.000');
    expect(s.exercisesOn('Push'), contains('Dips'));
    expect(s.exercises, isNot(contains('Seated row')));
    expect(s.plan(after['Legs']![0].$1).sets, 4);
    expect(s.setsToday('Lat pulldown').length, 1); // logged sets stay
    final again = await Store.load();
    expect(again.gymBy, 'Coach Rafi');
    expect(again.plan('Dips').reps, 8);
    expect(workoutChanges(after, workoutFrom(again.coachSummary()['workout'] as Map)), isEmpty);
    // an empty workout is ignored, never half-applied
    again.setWorkout({'Push': [], 'Pull': [], 'Legs': []});
    expect(again.exercises, contains('Dips'));
    again.markPlanSeen('gym', '2026-10-11T08:00:00.000');
    expect(again.gymAt, '2026-10-11T08:00:00.000');
  });

  test('ramadan: Dhaka times, Sehri and Iftar meals, fasts kept and made up, reminders after iftar', () async {
    // the Islamic Foundation's Dhaka table, first day of Ramadan 2026
    final first = ramadanTimes(DateTime(2026, 2, 19));
    expect(first.sehri.toUtc(), DateTime.utc(2026, 2, 18, 23, 12)); // 05:12 in Dhaka
    expect(first.iftar.toUtc(), DateTime.utc(2026, 2, 19, 11, 58)); // 17:58
    // another district, and a summer in London where the sun never gets 18° down
    useRamadanPlace('Sylhet');
    expect(ramadanTimes(DateTime(2026, 2, 19)).iftar.isBefore(first.iftar), isTrue); // east: earlier
    useRamadanPlace('London');
    final june = ramadanTimes(DateTime(2026, 6, 21));
    expect(june.iftar.toUtc().hour, 20); // sunset about 21:21 BST
    expect(june.sehri.toUtc().hour, 2); // about 03:40 BST: a seventh of the night before sunrise
    expect(placeForZone('Europe/London'), 'London');
    expect(placeForZone('Asia/Dhaka'), 'Dhaka');
    useRamadanPlace('Dhaka');

    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.setFast('16:8');
    s.setRamadan(true);
    expect(s.fastPlan, isNull); // the Ramadan fast replaces the 16:8 window
    expect(meals.map((m) => m.name), ['Sehri', 'Iftar', 'Snack', 'Dinner']);
    final rt = ramadanTimes(DateTime.now());
    expect(meals[0].window.split('–').last, hhmm(rt.sehri));
    expect(meals[1].window.split('–').first, hhmm(rt.iftar));
    expect(meals.any(s.fasted), isFalse);
    expect(s.fastGoal, rt.iftar.difference(rt.sehri).inHours);

    // a trainer's chart sent in Ramadan is for Ramadan only
    s.setChart([
      meals[0],
      meals[1].withOptions([
        const MealOption('Dates + soup', ['3 dates', 'Soup'], 300, 12),
      ]),
      meals[2],
      meals[3],
    ]);
    expect(meals[1].options.single.name, 'Dates + soup');
    expect(s.chart, isNull);

    s.missFastToday(true);
    expect(s.fastingToday, isFalse);
    expect(s.ramadanMissed, [s.today]);
    expect(s.ramadanKept, 0);
    s.setRamadan(false);
    expect(meals[0].name, 'Breakfast');
    expect(meals[1].options.length, defaultMeals[1].options.length);
    expect(s.ramadanMissed.length, 1); // still owed after Ramadan
    s.madeUpFast();
    expect(s.ramadanMissed, isEmpty);

    // reminders: sehri and iftar by the sun, water only after iftar
    s.setRamadan(true);
    s.setReminders(true);
    final day = DateTime.now().add(const Duration(days: 1));
    final times = ramadanTimes(day);
    final p = Reminders.plan(s, DateTime.now()).where((x) => x.when.day == day.day).toList();
    expect(p.firstWhere((x) => x.title.startsWith('Iftar')).when, times.iftar.subtract(const Duration(minutes: 10)));
    // sehri can fall on the phone's day before when the phone's zone isn't the place's (CI runs in UTC)
    final sehris = Reminders.plan(s, DateTime.now()).where((x) => x.title.startsWith('Sehri')).map((x) => x.when);
    expect(sehris, contains(times.sehri.subtract(const Duration(minutes: 45))));
    expect(p.where((x) => x.channel == 'water').every((x) => x.when.isAfter(times.iftar)), isTrue);
  });

  test('students: who needs the trainer, and why, most urgent first', () {
    final now = DateTime(2026, 10, 10, 21);
    String ago(int days) => dayKey(now.subtract(Duration(days: days)));
    final onTrack = {
      'lap': 20,
      'goal': 0,
      'day': dayKey(now),
      'kgWeek': -0.6,
      'fullDays': 6,
      'sessions': [
        [ago(1), 'Push', 12],
      ],
      'burnLeft': 0,
      'eatLeft': 0,
    };
    expect(studentFlags(onTrack, now.subtract(const Duration(hours: 2)), now), isEmpty);
    final slipping = {
      ...onTrack,
      'day': ago(3),
      'kgWeek': 0.1,
      'fullDays': 2,
      'sessions': [
        [ago(6), 'Legs', 10],
      ],
      'burnLeft': 400,
    };
    expect(studentFlags(slipping, now.subtract(const Duration(days: 3)), now), [
      'Not opened in 3 days',
      'No gym in 6 days',
      'Weight not moving this week',
      'Logged 2 of 7 days',
      // "over today" only counts when the summary is today's
    ]);
    final gainer = {...onTrack, 'goal': 2, 'kgWeek': -0.1, 'eatLeft': 350};
    expect(studentFlags(gainer, now, now), ['Not gaining this week', '350 kcal short today']);
    expect(studentFlags({'lap': 1}, null, now), ['Never opened Daur']);
  });

  test('couple: what a partner sees, the race week and its points', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    s.logMeal(meals[0]);
    s.logWeight(108.6);
    final food = s.mealLabel(meals[0]);
    expect(jsonEncode(s.partnerSummary()), contains('108.6'));

    s.setPartnerHide('weight', true);
    s.setPartnerHide('meals', true);
    final p = s.partnerSummary(), json = jsonEncode(p);
    expect(json.contains('108.6'), isFalse); // no weight anywhere
    expect(json.contains(food), isFalse); // nor the food
    expect(((p['meals'] as List).first as Map)['status'], 'done'); // still counts for the race
    expect(p['hidden'], containsAll(['weight', 'meals']));
    expect(jsonEncode(s.coachSummary()), contains('108.6')); // the trainer still sees it
    expect(SideBySide.legs(p), 1);

    // the week starts on Saturday
    expect(raceWeekStart('2026-10-10'), '2026-10-10'); // a Saturday
    expect(raceWeekStart('2026-10-16'), '2026-10-10'); // Friday
    expect(raceWeekStart('2026-10-11'), '2026-10-10');
    // 100 each for meals, water and steps, capped; days before the week don't count
    final d = {
      'waterGoal': 14,
      'days': [
        ['2026-10-09', 4, 9000, 8000, 14],
        ['2026-10-10', 4, 12000, 8000, 20],
        ['2026-10-11', 2, 4000, 8000, 7],
      ],
    };
    expect(racePoints(d, '2026-10-10'), 300 + (50 + 50 + 50));

    s.setStake('Makes tea');
    expect(s.partnerSummary()['stake'], 'Makes tea');

    // the leaderboard's weekly totals: kg × reps, steps, full days, water
    final ex = s.exercises.first;
    s.logSet(ex, 10, 40);
    s.logSet(ex, 8, 42.5);
    expect(s.weekLifted, 400 + 340);
    s.setManualSteps(5200);
    s.setWater(9);
    expect(s.weekSteps, 5200);
    expect(s.weekWater, 9);
    expect(s.weekFullDays, 0); // one meal logged so far
  });
}
