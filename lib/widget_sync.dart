import 'l10n.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import 'burn.dart' show burnWays, hoursMinutes;
import 'plan.dart';
import 'reminders.dart';
import 'steps.dart';
import 'store.dart';
import 'today.dart' show niceDate, thousands;
import 'water_walk.dart' show litres;

/// Widget buttons land here, in a background isolate (Android; iOS opens the app via daur:// links).
/// Every ~30 minutes, even with Daur closed (Android): read steps and redraw the widgets.
@pragma('vm:entry-point')
void backgroundRefresh() => Workmanager().executeTask((task, _) async {
  final s = await Store.load();
  final v = await Steps.today();
  if (v != null) {
    WidgetSync.steps = v;
    s.noteSteps(v);
    await s.saved;
  }
  await WidgetSync.push(s);
  await Reminders.reschedule(s); // the evening walk reminder follows the new step count
  return true;
});

/// Schedule [backgroundRefresh]. Android only: iOS gives widgets no background Health access.
Future<void> scheduleBackgroundRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundRefresh);
    await Workmanager().registerPeriodicTask(
      'daur-refresh',
      'refresh',
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    debugPrint('scheduleBackgroundRefresh: $e');
  }
}

@pragma('vm:entry-point')
Future<void> widgetAction(Uri? uri) async {
  final s = await Store.load();
  switch (uri?.host) {
    case 'water':
      s.setWater(s.water + 1);
    case 'meal':
      final m = s.nextMeal;
      if (m != null) s.logMeal(m);
  }
  await s.saved;
  await WidgetSync.push(s);
  await Reminders.reschedule(s); // e.g. no snack reminder once the widget logged it
}

/// Keeps the home-screen widgets in step with the app. Widgets only draw what's saved here.
/// Android: DaurWidgetProvider (Today), DaurWaterWidget, DaurMealWidget, DaurWalkWidget.
/// iOS: the DaurWidget extension (same keys, read from the App Group).
class WidgetSync {
  static const appGroup = 'group.com.siraj.daur';
  static const _android = [
    'com.siraj.daur.DaurWidgetProvider',
    'com.siraj.daur.DaurLargeWidget',
    'com.siraj.daur.DaurWaterWidget',
    'com.siraj.daur.DaurMealWidget',
    'com.siraj.daur.DaurWalkWidget',
  ];
  static const _iosKinds = ['DaurWidget', 'DaurWaterWidget', 'DaurMealWidget', 'DaurWalkWidget'];

  static bool get _supported => !kIsWeb;
  static Timer? _debounce;
  static int? steps; // set by the app when it reads Health Connect / Apple Health

  static Future<void> attach(Store s) async {
    if (!_supported) return;
    await HomeWidget.setAppGroupId(appGroup);
    await HomeWidget.registerInteractivityCallback(widgetAction);
    s.addListener(() => schedule(s));
    schedule(s);
  }

  /// Coalesce bursts of changes (logging a meal saves several times) into one widget update.
  static void schedule(Store s) {
    if (!_supported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => push(s));
  }

  /// Android: show the launcher's "Add widget" prompt. False where unsupported (iOS: add from the home screen).
  static Future<bool> pin([String which = 'DaurWidgetProvider']) async {
    if (!_supported || defaultTargetPlatform != TargetPlatform.android) return false;
    if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: 'com.siraj.daur.$which');
    return true;
  }

  /// The widgets you can add, for the "Add home-screen widget" picker.
  static const catalog = [
    ('DaurLargeWidget', 'Today, large', 'The whole day: track and all four meals'),
    ('DaurWidgetProvider', 'Today', 'Track, next meal, kcal'),
    ('DaurMealWidget', 'Next meal', 'The next meal with a Log button'),
    ('DaurWaterWidget', 'Water', 'Glasses with a + button'),
    ('DaurWalkWidget', 'Walk', 'Steps on the home straight'),
  ];

  static Future<void> push(Store s) async {
    try {
      await HomeWidget.setAppGroupId(appGroup);
      final next = s.nextMeal;
      final walked = steps ?? s.manualSteps;
      final target = stepTargetForDay(s.lap);
      final allDone = next == null;
      String legState(Meal m) => s.done.containsKey(m.id)
          ? 'done'
          : s.skipped.contains(m.id)
          ? 'skip'
          : m == next
          ? 'next'
          : 'todo';
      final data = <String, Object>{
        'language': s.appLanguage,
        // Today (medium + large)
        'lap_n': s.lap,
        'meters': s.legsDone * 100,
        'date': niceDate(DateTime.now(), language: s.appLanguage),
        'next_name': allDone ? trLanguage(s.appLanguage, 'All meals logged') : trLanguage(s.appLanguage, next.name),
        'next_when': allDone ? trLanguage(s.appLanguage, 'Tomorrow · {value1}', {'value1': meals.first.window.split('–').first}) : next.window,
        // over today's target, the kcal line says what's left to burn (yellow on the widget)
        'kcal_text': s.burnLeft > 0
            ? trLanguage(s.appLanguage, '{value1} kcal to burn · {value2} walk', {'value1': thousands(s.burnLeft), 'value2': hoursMinutes(s.minutesFor(s.burnLeft, burnWays.first.$4))})
            : trLanguage(s.appLanguage, '{value1} / {value2} kcal', {'value1': thousands(s.kcal), 'value2': thousands(s.kcalGoal)}),
        'burn_over': s.burnLeft > 0 ? 1 : 0,
        'kcal_pct': math.min(100, s.kcal * 100 ~/ s.kcalGoal),
        'finish': s.lap >= laps && allDone ? 1 : 0,
        for (final (i, m) in meals.indexed) ...{
          'leg${i + 1}_name': trLanguage(s.appLanguage, m.name),
          'leg${i + 1}_sub': switch (legState(m)) {
            'done' => trLanguage(s.appLanguage, '{value1} · {value2} kcal', {'value1': s.done[m.id] ?? '', 'value2': s.mealKcal(m)}),
            'skip' => trLanguage(s.appLanguage, 'Skipped'),
            _ => m.window,
          },
          'leg${i + 1}_state': legState(m),
        },
        // Water
        'streak': s.streak,
        'water_glasses': s.water,
        'water_goal': s.waterGoal,
        'water_slots': (s.water * 14 ~/ s.waterGoal).clamp(0, 14), // the widget draws 14 glasses
        'water_goal_text': trLanguage(s.appLanguage, 'of {value1} L', {'value1': litres(s.waterGoal)}),
        // Next meal
        'meal_num': allDone ? 400 : (meals.indexOf(next) + 1) * 100,
        'meal_title': allDone ? trLanguage(s.appLanguage, 'All meals logged') : trLanguage(s.appLanguage, next.name),
        'meal_sub': allDone
            ? trLanguage(s.appLanguage, '{value1} kcal · {value2} g protein', {'value1': thousands(s.kcal), 'value2': s.protein})
            : trLanguage(s.appLanguage, '{value1} · {value2} kcal', {'value1': (s.ramadan ? s.ramadanChart : s.chart) == null ? trLanguage(s.appLanguage, s.chosen(next).name) : s.chosen(next).name, 'value2': s.mealKcal(next)}),
        'meal_when': allDone ? (s.done[meals.last.id] ?? '') : next.window,
        'meal_btn': allDone ? trLanguage(s.appLanguage, 'Open') : trLanguage(s.appLanguage, 'Log'),
        'meal_done': allDone ? 1 : 0,
        'meal_cap': trLanguage(s.appLanguage, 'Tomorrow · {value1}', {'value1': meals.first.window.split('–').first}),
        // Walk: only when steps are known (a background tap mustn't reset them to 0)
        if (walked != null) ...{
          'walk_steps': walked,
          'walk_target': target,
          'walk_sub': walked >= target
              ? trLanguage(s.appLanguage, '{value1} done · bonus now', {'value1': thousands(target)})
              : trLanguage(s.appLanguage, '{value1} to go', {'value1': thousands(target - walked)}),
        },
      };
      await Future.wait([for (final e in data.entries) HomeWidget.saveWidgetData(e.key, e.value)]);
      await _updateAll();
    } catch (e) {
      debugPrint('WidgetSync.push: $e'); // a widget hiccup must never break the app
    }
  }

  static Future<void> _updateAll() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      for (final a in _android) {
        await HomeWidget.updateWidget(qualifiedAndroidName: a);
      }
    } else {
      for (final k in _iosKinds) {
        await HomeWidget.updateWidget(iOSName: k);
      }
    }
  }
}
