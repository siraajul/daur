import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reminders.dart';
import 'store.dart';
import 'theme.dart';
import 'visuals.dart';
import 'widget_sync.dart';

/// Reminders (design: design/notifications.html, app-reminders): what nudges, when, on this phone only.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.store});
  final Store store;

  static const _types = [
    ('meals', 'Meals', '08:00 · 13:00 · 16:30 · 20:00, quiet once logged'),
    ('water', 'Water', '11:00 · 14:30 · 18:00, with + glass'),
    ('weigh', 'Weigh-in', '07:30, quiet once you have weighed'),
    ('walk', 'Evening walk', '21:15, only if you are short of steps'),
    ('streak', 'Streak', '21:30, only if today isn\'t complete'),
    ('checkins', 'Check-ins', 'Day 28 pace, day 31 junk rule, day 84, a nudge after 2 days away'),
  ];

  /// Turn reminders on, asking for notification permission right here (in context).
  static Future<bool> turnOn(BuildContext context, Store s) async {
    final ok = await Reminders.requestPermission();
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Notifications are off · allow them in Settings'),
          ),
        );
      }
      return false;
    }
    s.setReminders(true);
    HapticFeedback.mediumImpact();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        final next = Reminders.plan(s, DateTime.now(), steps: WidgetSync.steps)
          ..sort((a, b) => a.when.compareTo(b.when));
        Widget toggle(String title, String sub, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) =>
            Container(
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.rule, width: .5)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: t.ground,
                activeTrackColor: t.ink,
                inactiveTrackColor: t.ink.withValues(alpha: .22),
                title: Text(title, style: t.body(color: enabled ? t.ink : t.ink2)),
                subtitle: Text(sub, style: t.meta()),
              ),
            );
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Reminders', sub: 'On this phone only · quiet 22:00–07:00'),
                const SizedBox(height: 20),
                toggle('Reminders', s.remindersOn ? 'On' : 'Off: Daur stays quiet', s.remindersOn, (v) async {
                  v ? await turnOn(context, s) : s.setReminders(false);
                }),
                if (s.remindersOn && next.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.rule, width: .5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Next: ${next.first.title}', style: t.body()),
                              Text(
                                '${_hm(next.first.when)}${_dayWord(next.first.when)} · ${next.first.body}',
                                style: t.meta(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final (key, title, sub) in _types)
                  toggle(title, sub, s.reminderOn(key), (v) => s.setReminderType(key, v), enabled: s.remindersOn),
                toggle(
                  'Pause for today',
                  'Back tomorrow at 07:30',
                  s.pausedToday,
                  (v) => s.setPausedToday(v),
                  enabled: s.remindersOn,
                ),
                const SizedBox(height: 20),
                Text('Scheduled on this phone · no server', style: t.meta()),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _dayWord(DateTime d) {
    final n = DateTime.now();
    return d.day == n.day ? '' : ' tomorrow';
  }
}
