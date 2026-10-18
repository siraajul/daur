import 'l10n.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'burn.dart' show burnWays, hoursMinutes;
import 'plan.dart';
import 'ramadan.dart';
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
    'fasting': (
      'Fasting',
      'When the eating window opens and is about to close',
    ),
    'checkins': (
      'Check-ins',
      'Pace check, junk rule, end of the plan, a nudge after 2 days away',
    ),
  };

  static String _language = 'en';
  static Future<void> init({String? language}) async {
    final nextLanguage = language ?? _language;
    if ((_ready && nextLanguage == _language) || !_supported) return;
    _language = nextLanguage;
    _ready = true;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
      );
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
                DarwinNotificationAction.plain('log', trLanguage(_language, 'Log as planned')),
                DarwinNotificationAction.plain(
                  'other',
                  trLanguage(_language, 'Something else'),
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain('skip', trLanguage(_language, 'Skip')),
              ],
            ),
            DarwinNotificationCategory(
              'water',
              actions: [DarwinNotificationAction.plain('glass', trLanguage(_language, '+ Glass'))],
            ),
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
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
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

  /// Each kind of reminder in Daur's look: its own round icon, the plan day under the app name,
  /// the whole message (not cut at one line) and, where there's a count, a progress bar.
  static NotificationDetails _details(
    String channel, {
    List<AndroidNotificationAction> actions = const [],
    String? cat,
    String? sub,
    String? body,
    (int, int)? progress,
    List<String> lines = const [],
    Uint8List? picture,
    String? title,
  }) {
    final (name, desc) = _channels[channel]!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daur_$channel',
        trLanguage(_language, name),
        channelDescription: trLanguage(_language, desc),
        importance: channel == 'meals'
            ? Importance.high
            : Importance.defaultImportance,
        priority: channel == 'meals' ? Priority.high : Priority.defaultPriority,
        color: const Color(0xFF28645D),
        icon: 'ic_stat_daur',
        groupKey: 'daur',
        largeIcon: DrawableResourceAndroidBitmap('notif_$channel'),
        subText: sub,
        styleInformation: picture != null
            ? BigPictureStyleInformation(
                ByteArrayAndroidBitmap(picture),
                contentTitle: title,
                summaryText: body,
                hideExpandedLargeIcon: true,
              )
            : lines.isNotEmpty
            ? InboxStyleInformation(lines, contentTitle: title)
            : body == null
            ? null
            : BigTextStyleInformation(body),
        showProgress: progress != null,
        maxProgress: progress?.$2 ?? 0,
        progress: progress == null ? 0 : progress.$1.clamp(0, progress.$2),
        actions: actions,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: channel,
        categoryIdentifier: cat,
        subtitle: sub,
        // quiet for nudges, through Focus for the streak. Time-sensitive needs a paid developer account's
        // capability (com.apple.developer.usernotifications.time-sensitive); without it iOS treats it as active
        interruptionLevel: switch (channel) {
          'water' || 'walk' || 'checkins' => InterruptionLevel.passive,
          'streak' => InterruptionLevel.timeSensitive,
          _ => InterruptionLevel.active,
        },
      ),
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
      void add(
        int slot,
        DateTime when,
        String channel,
        String title,
        String body,
        String payload, {
        (int, int)? progress,
        List<String> lines = const [],
      }) {
        if (when.isAfter(now)) {
          out.add(
            Planned(
              _base + d * 50 + slot,
              when,
              channel,
              trLanguage(s.appLanguage, title),
              trLanguage(s.appLanguage, body),
              payload,
              sub: trLanguage(s.appLanguage, 'Day {value1} of {value2}', {
                'value1': lap,
                'value2': laps,
              }),
              progress: progress,
              lines: lines,
            ),
          );
        }
      }

      if (s.reminderOn('weigh') && !(d == 0 && s.weighedToday)) {
        add(
          1,
          at(7, 30),
          'weigh',
          trLanguage(s.appLanguage, 'Weigh-in · day {value1}', {'value1': lap}),
          trLanguage(s.appLanguage, 'After the bathroom, before breakfast.'),
          'weigh',
        );
      }
      // Ramadan's times move a minute a day: each day's meals get that day's
      final dayMeals = s.ramadan ? withRamadanTimes(meals, day) : meals;
      final rt = ramadanTimes(day);
      if (s.reminderOn('meals')) {
        for (final (i, m) in dayMeals.indexed) {
          if (s.fasted(m) ||
              (d == 0 &&
                  (s.done.containsKey(m.id) || s.skipped.contains(m.id))))
            { continue; }
          final p = m.window
              .split('–')
              .first
              .split(':')
              .map(int.parse)
              .toList();
          final opt = s.chosen(m);
          final last = i == meals.length - 1;
          final (time, title, body) = switch (s.ramadan ? m.id : '') {
            // sehri: 45 minutes before it ends; iftar: 10 minutes before
            'm1' => (
              rt.sehri.subtract(const Duration(minutes: 45)),
              trLanguage(s.appLanguage, 'Sehri ends {value1}', {
                'value1': hhmm(rt.sehri),
              }),
              trLanguage(s.appLanguage, '{value1} · water too, 2–3 glasses.', {
                'value1': opt.name,
              }),
            ),
            'm2' => (
              rt.iftar.subtract(const Duration(minutes: 10)),
              trLanguage(s.appLanguage, 'Iftar at {value1}', {
                'value1': hhmm(rt.iftar),
              }),
              trLanguage(
                s.appLanguage,
                'Dates and water first, then {value1}.',
                {'value1': opt.name},
              ),
            ),
            _ => (
              at(p[0], p[1]),
              trLanguage(s.appLanguage, '{value1} · {value2}', {
                'value1': trLanguage(s.appLanguage, m.name),
                'value2': m.window.split('–').first,
              }),
              trLanguage(s.appLanguage, '{value1} · {value2} kcal. {value3}', {
                'value1': opt.name,
                'value2': s.optKcal(m, opt),
                'value3': trLanguage(
                  s.appLanguage,
                  last ? 'The last meal of the day.' : 'Log it in one tap.',
                ),
              }),
            ),
          };
          add(10 + i, time, 'meals', title, body, 'meal:${m.id}');
        }
      }
      if (s.reminderOn('water')) {
        // in Ramadan, water is for after iftar: none while fasting
        final iftarHour = rt.iftar.add(const Duration(minutes: 60));
        final checks = s.ramadan
            ? [(iftarHour.hour, iftarHour.minute, 5), (21, 0, 9), (22, 45, 12)]
            : [(11, 0, 5), (14, 30, 9), (18, 0, 12)];
        for (final (i, (h, mm, of14)) in checks.indexed) {
          final goal = (of14 * s.waterGoal / 14)
              .round(); // checkpoints scaled to the day's goal
          if (d == 0 && s.water >= goal) continue;
          add(
            20 + i,
            at(h, mm),
            'water',
            d == 0
                ? trLanguage(s.appLanguage, 'Water · {value1} of {value2} L', {
                    'value1': litres(s.water),
                    'value2': litres(s.waterGoal),
                  })
                : 'Water',
            trLanguage(
              s.appLanguage,
              'Aim for {value1} L by now. One glass, 250 ml.',
              {'value1': litres(goal)},
            ),
            'water',
            progress: d == 0 ? (s.water, s.waterGoal) : null,
          );
        }
      }
      if (s.reminderOn('walk')) {
        final target = stepTargetForDay(lap);
        if (d == 0 && s.burnLeft > 0) {
          // over today's target: the evening walk becomes the way to burn it off
          final min = s.minutesFor(s.burnLeft, burnWays.first.$4);
          add(
            30,
            at(21, 15),
            'walk',
            trLanguage(s.appLanguage, 'Walk off {value1} kcal', {
              'value1': thousands(s.burnLeft),
            }),
            trLanguage(
              s.appLanguage,
              '{value1} brisk walk covers it, about {value2} steps.',
              {
                'value1': hoursMinutes(min),
                'value2': thousands((min / 60 * 5.6 * 1350).round()),
              },
            ),
            'burn',
          );
        } else if (d > 0 || steps == null) {
          add(
            30,
            at(21, 15),
            'walk',
            trLanguage(s.appLanguage, 'Evening walk'),
            trLanguage(
              s.appLanguage,
              'Short of {value1} steps? 20 minutes after dinner covers most of it.',
              {'value1': thousands(target)},
            ),
            'walk',
          );
        } else if (steps < target) {
          add(
            30,
            at(21, 15),
            'walk',
            trLanguage(s.appLanguage, 'Walk · {value1} of {value2}', {
              'value1': thousands(steps),
              'value2': thousands(target),
            }),
            trLanguage(
              s.appLanguage,
              '20 minutes after dinner covers the rest.',
            ),
            'walk',
            progress: (steps, target),
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
            trLanguage(s.appLanguage, 'Eating window open'),
            d == 0 && s.fastFrom != null
                ? trLanguage(
                    s.appLanguage,
                    'Until {value1}:00. End your fast in Daur.',
                    {'value1': close.toString().padLeft(2, '0')},
                  )
                : trLanguage(s.appLanguage, 'Until {value1}:00.', {
                    'value1': close.toString().padLeft(2, '0'),
                  }),
            'fasting',
          );
        }
        if (close > 7 && close <= 22) {
          add(
            33,
            at(close - 1, 30),
            'fasting',
            trLanguage(s.appLanguage, 'Window closes in 30 min'),
            trLanguage(
              s.appLanguage,
              'Last bite by {value1}:00, then the fast starts.',
              {'value1': close.toString().padLeft(2, '0')},
            ),
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
          n > 0
              ? trLanguage(
                  s.appLanguage,
                  'Your {value1}-day streak ends at midnight',
                  {'value1': n},
                )
              : trLanguage(s.appLanguage, 'Close today'),
          d == 0
              ? trLanguage(
                  s.appLanguage,
                  'Log the last {value1}, or mark {value2} skipped.',
                  {
                    'value1': left == 1 ? 'meal' : '$left meals',
                    'value2': left == 1 ? 'it' : 'them',
                  },
                )
              : trLanguage(s.appLanguage, 'Log what\'s left before midnight.'),
          'open',
          progress: d == 0 ? (s.legsDone, 4) : null,
          // expanded: everything still open today, one line each (Android inbox style)
          lines: d > 0
              ? const []
              : [
                  for (final m in meals)
                    if (!s.fasted(m) &&
                        !s.done.containsKey(m.id) &&
                        !s.skipped.contains(m.id))
                      trLanguage(s.appLanguage, '{value1} · not logged yet', {
                        'value1': trLanguage(s.appLanguage, m.name),
                      }),
                  if (s.burnLeft > 0)
                    trLanguage(s.appLanguage, 'Burn · {value1} kcal over', {
                      'value1': thousands(s.burnLeft),
                    }),
                  if (s.water < s.waterGoal)
                    trLanguage(s.appLanguage, 'Water · {value1} L to go', {
                      'value1': litres(s.waterGoal - s.water),
                    }),
                  if (steps != null && steps < stepTargetForDay(lap))
                    trLanguage(s.appLanguage, 'Steps · {value1} short', {
                      'value1': thousands(stepTargetForDay(lap) - steps),
                    }),
                ],
        );
      }
      // Sunday evening: the week in one screen
      if (s.reminderOn('checkins') && day.weekday == DateTime.sunday) {
        final w = s.week;
        add(
          43,
          at(20, 30),
          'checkins',
          trLanguage(s.appLanguage, 'Your week'),
          d == 0
              ? trLanguage(
                  s.appLanguage,
                  '{value1} of 7 full days{value2}. Tap for the recap.',
                  {
                    'value1': w.full,
                    'value2': w.kgChange == null
                        ? ''
                        : ' · ${w.kgChange! <= 0 ? '−' : '+'}${w.kgChange!.abs().toStringAsFixed(1)} kg',
                  },
                )
              : trLanguage(
                  s.appLanguage,
                  'Full days, weight, steps, gym and spending. Tap for the recap.',
                ),
          'recap',
        );
      }
      // a trainer's Sunday: who needs them this week (counted when the dashboard was last open)
      if (s.reminderOn('checkins') &&
          s.role == 'trainer' &&
          s.studentsTotal > 0 &&
          day.weekday == DateTime.sunday) {
        add(
          44,
          at(19, 30),
          'checkins',
          s.studentsNeed == 0
              ? trLanguage(s.appLanguage, 'All {value1} students on track', {
                  'value1': s.studentsTotal,
                })
              : trLanguage(
                  s.appLanguage,
                  '{value1} of {value2} students need you',
                  {'value1': s.studentsNeed, 'value2': s.studentsTotal},
                ),
          trLanguage(s.appLanguage, 'Open Students to see who, and why.'),
          'students',
        );
      }
      if (s.reminderOn('checkins')) {
        final checkins = {
          28: (
            40,
            9,
            0,
            trLanguage(s.appLanguage, 'Day 28 · pace check'),
            trLanguage(
              s.appLanguage,
              'Four weeks in. See how your weight trend compares with the plan.',
            ),
          ),
          31: (
            41,
            9,
            0,
            trLanguage(s.appLanguage, 'Day 31 · the junk rule changes'),
            trLanguage(
              s.appLanguage,
              'From today: one controlled junk meal a week, never a cheat day.',
            ),
          ),
          laps: (
            42,
            21,
            30,
            trLanguage(s.appLanguage, 'Day 84 · the last day'),
            trLanguage(s.appLanguage, 'Log it and choose what comes next.'),
          ),
        };
        final c = checkins[lap];
        if (c != null)
          { add(c.$1, at(c.$2, c.$3), 'checkins', c.$4, c.$5, 'open'); }
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
          trLanguage(s.appLanguage, 'Day {value1} of your plan', {
            'value1': s.lapIn(2),
          }),
          trLanguage(
            s.appLanguage,
            'One tap logs a meal. Pick up where you left off.',
          ),
          'open',
        ),
      );
    }
    return out;
  }

  static Future<void> reschedule(Store s) async {
    if (!_supported) return;
    try {
      await init(language: s.appLanguage);
      final pending = await plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _base && p.id < _base + 400) await plugin.cancel(id: p.id);
      }
      final now = DateTime.now();
      for (final p in plan(s, now, steps: WidgetSync.steps)) {
        // today's Sunday recap carries the week as a picture; later Sundays don't know their week yet
        final picture = p.payload == 'recap' && p.when.day == now.day
            ? await recapPicture(s)
            : null;
        final actions = switch (p.channel) {
          'meals' => [
            AndroidNotificationAction(
              'log',
              trLanguage(s.appLanguage, 'Log as planned'),
            ),
            AndroidNotificationAction(
              'other',
              trLanguage(s.appLanguage, 'Something else'),
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'skip',
              trLanguage(s.appLanguage, 'Skip'),
            ),
          ],
          'water' => [
            AndroidNotificationAction(
              'glass',
              trLanguage(s.appLanguage, '+ Glass'),
            ),
          ],
          _ => const <AndroidNotificationAction>[],
        };
        await plugin.zonedSchedule(
          id: p.id,
          scheduledDate: tz.TZDateTime.from(p.when, tz.local),
          notificationDetails: _details(
            p.channel,
            actions: actions,
            sub: p.sub,
            body: p.body,
            progress: p.progress,
            lines: p.lines,
            picture: picture,
            title: p.title,
            cat: p.channel == 'meals'
                ? 'meal'
                : p.channel == 'water'
                ? 'water'
                : null,
          ),
          androidScheduleMode: AndroidScheduleMode
              .inexactAllowWhileIdle, // no exact-alarm permission needed
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
    final meal = payload.startsWith('meal:')
        ? meals.where((m) => m.id == payload.substring(5)).firstOrNull
        : null;
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
  final String? sub; // "Day 12 of 84", under the app name
  final (int, int)? progress; // done of total, drawn as a bar
  final List<String> lines; // expanded as a list (what's still open today)
  const Planned(
    this.id,
    this.when,
    this.channel,
    this.title,
    this.body,
    this.payload, {
    this.sub,
    this.progress,
    this.lines = const [],
  });
}

/// The Sunday recap as a picture for the notification: full days big, the week as 7 discs
/// (yellow = perfect, cream = all 4 meals, an arc for part of a day), the numbers under it.
Future<Uint8List?> recapPicture(Store s) async {
  try {
    const w = 1024.0, h = 512.0;
    const red = ui.Color(0xFFF6F3EC),
        ink = ui.Color(0xFF25342F),
        ink2 = ui.Color(0xFF58665F);
    const yellow = ui.Color(0xFF28645D), dark = ui.Color(0xFFFFFFFF);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawRect(const ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = red);
    void text(
      String t,
      double x,
      double y,
      double size,
      ui.Color color, {
      ui.FontWeight weight = ui.FontWeight.w700,
    }) {
      final b =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: size, fontWeight: weight),
            )
            ..pushStyle(ui.TextStyle(color: color))
            ..addText(t);
      c.drawParagraph(
        b.build()..layout(const ui.ParagraphConstraints(width: w - 112)),
        ui.Offset(x, y),
      );
    }

    final wk = s.week, days = s.lastDays(7);
    text('YOUR WEEK', 56, 36, 32, ink2, weight: ui.FontWeight.w600);
    text(
      '${wk.full} of 7 full days',
      56,
      76,
      84,
      ink,
      weight: ui.FontWeight.w900,
    );
    for (final (i, d) in days.indexed) {
      final cx = 56 + 54 + i * 136.0, cy = 296.0, r = 54.0;
      final legs = d == s.today ? s.legsDone : s.lapHistory[d] ?? 0;
      final ring = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 6;
      if (s.perfect(d) || legs >= 4) {
        c.drawCircle(
          ui.Offset(cx, cy),
          r,
          ui.Paint()..color = s.perfect(d) ? yellow : ink,
        );
      } else {
        c.drawCircle(
          ui.Offset(cx, cy),
          r - 3,
          ring..color = ink.withValues(alpha: .35),
        );
        if (legs > 0) {
          c.drawArc(
            ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r - 3),
            -1.5708,
            legs / 4 * 6.2832,
            false,
            ring
              ..color = ink
              ..strokeCap = ui.StrokeCap.round,
          );
        }
      }
      final letter = 'MTWTFSS'[DateTime.parse(d).weekday - 1];
      text(
        letter,
        cx - 11,
        cy - 19,
        34,
        s.perfect(d) || legs >= 4 ? dark : ink,
      );
    }
    final kg = wk.kgChange;
    text(
      [
        if (kg != null)
          '${kg <= 0 ? '−' : '+'}${kg.abs().toStringAsFixed(1)} kg',
        '${thousands(wk.steps)} steps a day',
        '${wk.gym} gym',
        '${wk.perfect} perfect',
      ].join('  ·  '),
      56,
      406,
      40,
      ink,
      weight: ui.FontWeight.w600,
    );
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } catch (e) {
    debugPrint('recapPicture: $e');
    return null;
  }
}
