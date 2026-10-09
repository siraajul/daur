import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'plan.dart';
import 'store.dart';
import 'today.dart' show thousands;
import 'water_walk.dart' show litres;
import 'widget_sync.dart';

/// Local reminders (design: design/notifications.html). Scheduled on the phone, no server.
/// The next 7 days are rescheduled whenever data changes, so nothing fires for a meal already
/// logged, water already drunk or a weigh-in already done, and reminders keep coming for a week
/// even if the app isn't opened. Nothing 22:00–07:00.
class Reminders {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  /// Taps that need the app (Something else, Log weight): Shell listens and routes them.
  static final route = ValueNotifier<String?>(null);

  static bool get _supported => !kIsWeb;
  static const _base = 1000; // scheduled ids live in 1000–1399 (50 per day); 4400 is the live workout
  static const days = 7;

  static const _channels = {
    'meals': ('Meals', 'When a meal window opens'),
    'water': ('Water', 'Glass checks through the day'),
    'weigh': ('Weigh-in', 'Morning weigh-in'),
    'walk': ('Evening walk', 'Only when you are short of steps'),
    'streak': ('Streak', 'At 21:30 when today isn\'t complete'),
    'fasting': ('Fasting', 'When the eating window opens and is about to close'),
    'checkins': ('Check-ins', 'Pace check, junk rule, end of the plan, a nudge after 2 days away'),
  };

  static Future<void> init() async {
    if (_ready || !_supported) return;
    _ready = true;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_daur'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'meal',
              actions: [
                DarwinNotificationAction.plain('log', 'Log as planned'),
                DarwinNotificationAction.plain(
                  'other',
                  'Something else',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain('skip', 'Skip'),
              ],
            ),
            DarwinNotificationCategory('water', actions: [DarwinNotificationAction.plain('glass', '+ Glass')]),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _foreground,
      onDidReceiveBackgroundNotificationResponse: notificationAction,
    );
  }

  /// Ask for permission (Android 13+ / iOS) at the moment reminders are turned on.
  static Future<bool> requestPermission() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          sound: true,
        ) ??
        false;
  }

  static void attach(Store s) {
    if (!_supported) return;
    s.addListener(() => schedule(s));
    schedule(s);
  }

  static void schedule(Store s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => reschedule(s));
  }

  static NotificationDetails _details(
    String channel, {
    List<AndroidNotificationAction> actions = const [],
    String? cat,
  }) {
    final (name, desc) = _channels[channel]!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daur_$channel',
        name,
        channelDescription: desc,
        importance: channel == 'meals' ? Importance.high : Importance.defaultImportance,
        priority: channel == 'meals' ? Priority.high : Priority.defaultPriority,
        color: const Color(0xFFAD3B26),
        icon: 'ic_stat_daur',
        groupKey: 'daur',
        actions: actions,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: channel, categoryIdentifier: cat),
    );
  }

  /// Everything the next [days] days need, from the current state. Pure: tested in store_test.dart.
  static List<Planned> plan(Store s, DateTime now, {int? steps}) {
    final out = <Planned>[];
    if (!s.remindersOn) return out;
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d < days; d++) {
      if (d == 0 && s.pausedToday) continue;
      final day = DateTime(today.year, today.month, today.day + d);
      final lap = s.lapIn(d);
      DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
      void add(int slot, DateTime when, String channel, String title, String body, String payload) {
        if (when.isAfter(now)) out.add(Planned(_base + d * 50 + slot, when, channel, title, body, payload));
      }

      if (s.reminderOn('weigh') && !(d == 0 && s.weighedToday)) {
        add(1, at(7, 30), 'weigh', 'Weigh-in · day $lap', 'After the bathroom, before breakfast.', 'weigh');
      }
      if (s.reminderOn('meals')) {
        for (final (i, m) in meals.indexed) {
          if (s.fasted(m) || (d == 0 && (s.done.containsKey(m.id) || s.skipped.contains(m.id)))) continue;
          final p = m.window.split('–').first.split(':').map(int.parse).toList();
          final opt = s.chosen(m);
          final last = i == meals.length - 1;
          add(
            10 + i,
            at(p[0], p[1]),
            'meals',
            '${m.name} · ${m.window.split('–').first}',
            '${opt.name} · ${s.optKcal(m, opt)} kcal. ${last ? 'The last meal of the day.' : 'Log it in one tap.'}',
            'meal:${m.id}',
          );
        }
      }
      if (s.reminderOn('water')) {
        for (final (i, (h, mm, of14)) in [(11, 0, 5), (14, 30, 9), (18, 0, 12)].indexed) {
          final goal = (of14 * s.waterGoal / 14).round(); // checkpoints scaled to the day's goal
          if (d == 0 && s.water >= goal) continue;
          add(
            20 + i,
            at(h, mm),
            'water',
            d == 0 ? 'Water · ${litres(s.water)} of ${litres(s.waterGoal)} L' : 'Water',
            'Aim for ${litres(goal)} L by now. One glass, 250 ml.',
            'water',
          );
        }
      }
      if (s.reminderOn('walk')) {
        final target = stepTargetForDay(lap);
        if (d > 0 || steps == null) {
          add(
            30,
            at(21, 15),
            'walk',
            'Evening walk',
            'Short of ${thousands(target)} steps? 20 minutes after dinner covers most of it.',
            'walk',
          );
        } else if (steps < target) {
          add(
            30,
            at(21, 15),
            'walk',
            'Walk · ${thousands(steps)} of ${thousands(target)}',
            '20 minutes after dinner covers the rest.',
            'walk',
          );
        }
      }
      // fasting: the window opens, and 30 minutes before it closes (inside 07:00–22:00 only)
      if (s.fastPlan != null && s.reminderOn('fasting')) {
        final open = s.eatStart, close = s.eatEnd;
        if (open >= 7 && open < 22) {
          add(
            32,
            at(open, 0),
            'fasting',
            'Eating window open',
            d == 0 && s.fastFrom != null
                ? 'Until ${close.toString().padLeft(2, '0')}:00. End your fast in Daur.'
                : 'Until ${close.toString().padLeft(2, '0')}:00.',
            'fasting',
          );
        }
        if (close > 7 && close <= 22) {
          add(
            33,
            at(close - 1, 30),
            'fasting',
            'Window closes in 30 min',
            'Last bite by ${close.toString().padLeft(2, '0')}:00, then the fast starts.',
            'fasting',
          );
        }
      }
      // the streak at risk: today only when it's really open; later days as a plain check-in
      if (s.reminderOn('streak') && (d > 0 || s.legsDone < 4)) {
        final left = 4 - s.legsDone;
        final n = d == 0 ? s.streak : 0;
        add(
          31,
          at(21, 30),
          'streak',
          n > 0 ? 'Your $n-day streak ends at midnight' : 'Close today',
          d == 0
              ? 'Log the last ${left == 1 ? 'meal' : '$left meals'}, or mark ${left == 1 ? 'it' : 'them'} skipped.'
              : 'Log what\'s left before midnight.',
          'open',
        );
      }
      // Sunday evening: the week in one screen
      if (s.reminderOn('checkins') && day.weekday == DateTime.sunday) {
        final w = s.week;
        add(
          43,
          at(20, 30),
          'checkins',
          'Your week',
          d == 0
              ? '${w.full} of 7 full days${w.kgChange == null ? '' : ' · ${w.kgChange! <= 0 ? '−' : '+'}${w.kgChange!.abs().toStringAsFixed(1)} kg'}. Tap for the recap.'
              : 'Full days, weight, steps, gym and spending. Tap for the recap.',
          'recap',
        );
      }
      if (s.reminderOn('checkins')) {
        const checkins = {
          28: (40, 9, 0, 'Day 28 · pace check', 'Four weeks in. See how your weight trend compares with the plan.'),
          31: (
            41,
            9,
            0,
            'Day 31 · the junk rule changes',
            'From today: one controlled junk meal a week, never a cheat day.',
          ),
          laps: (42, 21, 30, 'Day 84 · the last day', 'Log it and choose what comes next.'),
        };
        final c = checkins[lap];
        if (c != null) add(c.$1, at(c.$2, c.$3), 'checkins', c.$4, c.$5, 'open');
      }
    }
    // re-engagement: if the app isn't opened for two days, one gentle nudge at 19:00
    if (s.reminderOn('checkins')) {
      final when = DateTime(today.year, today.month, today.day + 2, 19);
      out.add(
        Planned(
          _base + 390,
          when,
          'checkins',
          'Day ${s.lapIn(2)} of your plan',
          'One tap logs a meal. Pick up where you left off.',
          'open',
        ),
      );
    }
    return out;
  }

  static Future<void> reschedule(Store s) async {
    if (!_supported) return;
    try {
      await init();
      final pending = await plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _base && p.id < _base + 400) await plugin.cancel(id: p.id);
      }
      for (final p in plan(s, DateTime.now(), steps: WidgetSync.steps)) {
        final actions = switch (p.channel) {
          'meals' => const [
            AndroidNotificationAction('log', 'Log as planned'),
            AndroidNotificationAction('other', 'Something else', showsUserInterface: true),
            AndroidNotificationAction('skip', 'Skip'),
          ],
          'water' => const [AndroidNotificationAction('glass', '+ Glass')],
          _ => const <AndroidNotificationAction>[],
        };
        await plugin.zonedSchedule(
          id: p.id,
          scheduledDate: tz.TZDateTime.from(p.when, tz.local),
          notificationDetails: _details(
            p.channel,
            actions: actions,
            cat: p.channel == 'meals'
                ? 'meal'
                : p.channel == 'water'
                ? 'water'
                : null,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // no exact-alarm permission needed
          title: p.title,
          body: p.body,
          payload: p.payload,
        );
      }
    } catch (e) {
      debugPrint('Reminders.reschedule: $e');
    }
  }

  /// App open: apply quick actions to the live store, route the rest to a screen.
  static Future<void> _foreground(NotificationResponse r) async {
    final s = _live;
    if (s != null && await _apply(s, r)) return;
    route.value = r.actionId == 'other' ? r.payload : (r.payload ?? 'open');
  }

  static Store? _live;
  static void bind(Store s) => _live = s;
  static Store? get bound => _live;

  /// The app was opened by tapping a notification (cold start).
  static Future<void> handleLaunch() async {
    if (!_supported) return;
    await init();
    final d = await plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d?.didNotificationLaunchApp == true && r != null) await _foreground(r);
  }

  /// Log / Skip / + Glass. Returns true if handled.
  static Future<bool> _apply(Store s, NotificationResponse r) async {
    final payload = r.payload ?? '';
    final meal = payload.startsWith('meal:') ? meals.where((m) => m.id == payload.substring(5)).firstOrNull : null;
    switch (r.actionId) {
      case 'log' when meal != null:
        if (!s.done.containsKey(meal.id)) s.logMeal(meal);
      case 'skip' when meal != null:
        s.skipMeal(meal);
      case 'glass':
        s.setWater(s.water + 1);
      default:
        return false;
    }
    await s.saved;
    return true;
  }
}

/// Notification buttons pressed while the app is closed (Android; iOS when it allows background).
@pragma('vm:entry-point')
Future<void> notificationAction(NotificationResponse r) async {
  final s = await Store.load();
  if (await Reminders._apply(s, r)) {
    await WidgetSync.push(s);
    await Reminders.reschedule(s);
  }
}

class Planned {
  final int id;
  final DateTime when;
  final String channel, title, body, payload;
  const Planned(this.id, this.when, this.channel, this.title, this.body, this.payload);
}
