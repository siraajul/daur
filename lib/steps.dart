import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Today's steps from the phone's health store:
/// Android → Health Connect (fed by Google Fit, Samsung Health, Fitbit, ...)
/// iOS     → Apple Health
/// Web     → none; the Walk row falls back to steps typed in by hand.
class Steps {
  static final _health = Health();
  static bool _configured = false;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Steps since local midnight, or null if no health store is available or access isn't granted.
  /// Only asks for permission when [ask] is true (onboarding, the Walk screen's Connect button).
  static Future<int?> today({bool ask = false}) async {
    if (!supported) return null;
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (!await _health.isHealthConnectAvailable()) return null;
        if (ask) await Permission.activityRecognition.request();
      }
      const types = [HealthDataType.STEPS];
      final has = await _health.hasPermissions(types); // always null on iOS: read access is private
      if (has != true) {
        if (ask) {
          if (!await _health.requestAuthorization(types)) return null;
        } else if (has == false) {
          return null;
        }
      }
      final now = DateTime.now();
      return await _health.getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);
    } catch (e) {
      debugPrint('Steps.today: $e');
      return null;
    }
  }

  /// Steps per local day for [dayKeys] (yyyy-mm-dd), or null without a health store.
  static Future<Map<String, int>?> week(List<String> dayKeys) async {
    if (await today() == null) return null; // also makes sure we are configured and allowed
    final out = <String, int>{};
    for (final k in dayKeys) {
      final p = k.split('-').map(int.parse).toList();
      final from = DateTime(p[0], p[1], p[2]);
      final to = DateTime(p[0], p[1], p[2] + 1);
      final now = DateTime.now();
      out[k] = await _health.getTotalStepsInInterval(from, to.isAfter(now) ? now : to) ?? 0;
    }
    return out;
  }

  /// Today's steps hour by hour (index = hour, up to now), or null without a health store.
  static Future<List<int>?> hourly() async {
    if (await today() == null) return null; // configured and allowed, or nothing
    final now = DateTime.now();
    final out = <int>[];
    for (var h = 0; h <= now.hour; h++) {
      final from = DateTime(now.year, now.month, now.day, h);
      final to = h == now.hour ? now : from.add(const Duration(hours: 1));
      out.add(await _health.getTotalStepsInInterval(from, to) ?? 0);
    }
    return out;
  }

  static List<HealthDataType> get _sleepTypes => [
    defaultTargetPlatform == TargetPlatform.iOS ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION,
  ];

  /// Minutes slept last night (sleep ending after 18:00 yesterday), from the health store's
  /// sleep tracker or a watch. Null without access or data. Asks only when [ask] is true.
  static Future<int?> sleepLastNight({bool ask = false}) async {
    if (!await available()) return null;
    try {
      final has = await _health.hasPermissions(_sleepTypes);
      if (has != true) {
        if (ask) {
          if (!await _health.requestAuthorization(_sleepTypes)) return null;
        } else if (has == false) {
          return null;
        }
      }
      final now = DateTime.now();
      final points = await _health.getHealthDataFromTypes(
        types: _sleepTypes,
        startTime: DateTime(now.year, now.month, now.day - 1, 18),
        endTime: now,
      );
      final min = _health
          .removeDuplicates(points)
          .fold<int>(0, (a, p) => a + p.dateTo.difference(p.dateFrom).inMinutes);
      return min > 0 ? min : null;
    } catch (e) {
      debugPrint('Steps.sleepLastNight: $e');
      return null;
    }
  }

  /// Android 14+: let the 30-minute widget refresh read steps while Daur is closed. Asks once
  /// (the Health Connect sheet); afterwards it's a no-op.
  static Future<void> allowBackground() async {
    if (defaultTargetPlatform != TargetPlatform.android || !await available()) return;
    try {
      if (await _health.isHealthDataInBackgroundAvailable() && !await _health.isHealthDataInBackgroundAuthorized()) {
        await _health.requestHealthDataInBackgroundAuthorization();
      }
    } catch (e) {
      debugPrint('Steps.allowBackground: $e');
    }
  }

  /// Is a health store present? (Health Connect ships with Android 14+; Android 9–13 need the app.)
  static Future<bool> available() async {
    if (!supported) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Opens the Play Store page for Health Connect (Android 9–13 need it installed).
  static Future<void> installHealthConnect() => _health.installHealthConnect();
}
