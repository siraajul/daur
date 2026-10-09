import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, SnackBarBehavior, Text;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';

import 'fasting.dart' show fastStages;
import 'reminders.dart';
import 'store.dart';
import 'widget_sync.dart' show WidgetSync;

/// Live workout status outside the app, while the rest timer or treadmill runs:
/// Android → an ongoing notification whose chronometer ticks on the lock screen and status bar;
/// iOS → a Live Activity (Lock Screen + Dynamic Island), drawn by the DaurWidget extension.
/// Clocks tick on their own from a start/end time, so nothing needs to run in the background.
class Live {
  static FlutterLocalNotificationsPlugin get _notes => Reminders.plugin; // one plugin, one set of handlers
  static final _activities = LiveActivities();
  static const _noteId = 4400;
  static const _activityId = 'daur-workout';
  static bool _ready = false, _iosActive = false;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      if (_android) {
        await Reminders.init();
        // asked here, in context, the first time a workout goes live
        await _notes
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (_ios) {
        await Reminders.init();
        await _activities.init(appGroupId: WidgetSync.appGroup, urlScheme: 'daur');
      }
    } catch (e) {
      debugPrint('Live.init: $e');
    }
  }

  static AndroidNotificationDetails _details({required int when, required bool countDown, bool ticking = true}) =>
      AndroidNotificationDetails(
        'workout',
        'Workout',
        channelDescription: 'Rest timer and treadmill while they run',
        importance: Importance.low, // silent; it's a status, not an alert
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: when,
        usesChronometer: ticking,
        chronometerCountDown: countDown,
        visibility: NotificationVisibility.public, // readable on the lock screen
        category: AndroidNotificationCategory.workout,
        color: const Color(0xFFAD3B26),
        icon: 'ic_stat_daur',
        largeIcon: const DrawableResourceAndroidBitmap('notif_workout'),
      );

  /// Rest between sets: counts down to [end].
  static Future<void> rest({required DateTime end, required String exercise, required String next}) async {
    await _init();
    try {
      if (_android) {
        await _notes.show(
          id: _noteId,
          title: 'Rest · $exercise',
          body: 'Next: $next',
          notificationDetails: NotificationDetails(
            android: _details(when: end.millisecondsSinceEpoch, countDown: true),
          ),
        );
      } else if (_ios) {
        await _upsertIos({
          'kind': 'rest',
          'title': 'Rest · $exercise',
          'sub': 'Next: $next',
          'end': end.millisecondsSinceEpoch / 1000,
          'total': end.difference(DateTime.now()).inSeconds.clamp(1, 3600), // lap glyph: share of rest used
        });
      }
    } catch (e) {
      debugPrint('Live.rest: $e');
    }
  }

  /// Treadmill: elapsed time counts up from [startedAt] (adjusted for pauses); [paused] freezes it.
  static Future<void> treadmill({
    required DateTime startedAt,
    required bool paused,
    required int elapsedSeconds,
    required double km,
    required int kcal,
  }) async {
    await _init();
    final sub = '${km.toStringAsFixed(2)} km · ≈ $kcal kcal${paused ? ' · paused' : ''}';
    try {
      if (_android) {
        await _notes.show(
          id: _noteId,
          title: paused ? 'Treadmill · paused at ${_clock(elapsedSeconds)}' : 'Treadmill',
          body: sub,
          notificationDetails: NotificationDetails(
            android: _details(when: startedAt.millisecondsSinceEpoch, countDown: false, ticking: !paused),
          ),
        );
      } else if (_ios) {
        await _upsertIos({
          'kind': 'treadmill',
          'title': paused ? 'Treadmill · paused' : 'Treadmill',
          'sub': sub,
          'start': startedAt.millisecondsSinceEpoch / 1000,
          'paused': paused ? 1 : 0,
          'elapsed': elapsedSeconds,
        });
      }
    } catch (e) {
      debugPrint('Live.treadmill: $e');
    }
  }

  /// The first time a workout goes live, say where it went (once).
  static void announce(BuildContext context, String what) {
    final s = Reminders.bound;
    if (kIsWeb || s == null || s.seenHints.contains('live')) return;
    s.dismissHint('live');
    final where = defaultTargetPlatform == TargetPlatform.iOS
        ? 'Lock Screen and Dynamic Island'
        : 'lock screen and status bar';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text('$what is on your $where now. Pocket the phone.')),
    );
  }

  static Future<void> end() async {
    try {
      if (_android) await _notes.cancel(id: _noteId);
      if (_ios && _iosActive) {
        await _activities.endActivity(_activityId);
        _iosActive = false;
      }
    } catch (e) {
      debugPrint('Live.end: $e');
    }
  }

  static Future<void> _upsertIos(Map<String, dynamic> data) async {
    if (!await _activities.areActivitiesEnabled()) return;
    if (_iosActive) {
      await _activities.updateActivity(_activityId, data);
    } else {
      await _activities.createActivity(_activityId, data, removeWhenAppIsKilled: true);
      _iosActive = true;
    }
  }

  // ---- the running fast ----

  static const _fastChannel = MethodChannel('daur/fast'); // android/…/FastLive.kt
  static const _fastActivityId = 'daur-fast';
  static String? _fastKey; // what's shown now, so unrelated store changes don't redraw it

  /// Keep the fast's live notification (Android) or Live Activity (iOS) in step with the store.
  static void watchFast(Store s) {
    if (kIsWeb) return;
    s.addListener(() => syncFast(s));
    syncFast(s);
  }

  static Future<void> syncFast(Store s) async {
    final from = s.fastFrom;
    final key = from == null ? null : '${from.millisecondsSinceEpoch}/${s.fastGoal}';
    if (key == _fastKey) return;
    _fastKey = key;
    try {
      if (_android) {
        if (from == null) {
          await _fastChannel.invokeMethod('cancel');
        } else {
          await _init(); // notification permission, asked in context
          await _fastChannel.invokeMethod('show', {
            'from': from.millisecondsSinceEpoch,
            'goal': s.fastGoal,
            'hours': [for (final st in fastStages) st.$1],
            'names': [for (final st in fastStages) st.$2],
          });
        }
      } else if (_ios) {
        await _init();
        if (from == null) {
          await _activities.endActivity(_fastActivityId);
        } else if (await _activities.areActivitiesEnabled()) {
          final end = from.add(Duration(hours: s.fastGoal));
          await _activities.createOrUpdateActivity(_fastActivityId, {
            'kind': 'fast',
            'title': 'Fasting',
            'sub':
                'Goal ${s.fastGoal}h · done at ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
            'start': from.millisecondsSinceEpoch / 1000,
            'end': end.millisecondsSinceEpoch / 1000,
            'total': s.fastGoal * 3600,
          }, removeWhenAppIsKilled: false);
        }
      }
    } catch (e) {
      debugPrint('Live.syncFast: $e');
    }
  }

  static String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
