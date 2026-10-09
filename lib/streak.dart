import 'package:flutter/material.dart';

import 'badges.dart';
import 'store.dart';
import 'today.dart' show thousands;
import 'theme.dart';
import 'visuals.dart';

/// Tap the flame on Today: the streak, the best one, a calendar of full days, and the medals.
class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = store;
    final todayDone = s.legsDone == 4;
    // 5 weeks, Monday-first rows, ending with this week
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1) - 28);
    final days = [for (var i = 0; i < 35; i++) DateTime(monday.year, monday.month, monday.day + i)];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const PageHeader('Streak'),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department_rounded, size: 72, color: s.streak > 0 ? t.accent : t.faint),
                const SizedBox(width: 8),
                Text('${s.streak}', style: t.x(80, weight: FontWeight.w900)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.streak == 1 ? 'day in a row' : 'days in a row', style: t.x(20))),
              ],
            ),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 18, color: t.ink2),
                const SizedBox(width: 6),
                Text('Best ${s.bestStreak}', style: t.sec()),
                const SizedBox(width: 16),
                // a freeze saves the streak on a missed day; one is earned every 7 full days
                Tooltip(
                  message: 'A freeze saves the streak on a missed day. Earn one every 7 full days.',
                  child: Row(
                    children: [
                      Icon(Icons.ac_unit_rounded, size: 18, color: s.freezes > 0 ? t.ink : t.faint),
                      const SizedBox(width: 4),
                      Text('${s.freezes} ${s.freezes == 1 ? 'freeze' : 'freezes'}', style: t.sec()),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(todayDone ? Icons.check_circle_rounded : Icons.restaurant_outlined, size: 18, color: t.ink),
                const SizedBox(width: 6),
                Text(todayDone ? 'Today counted' : '${4 - s.legsDone} meals left today', style: t.sec(t.ink)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(child: Text(d, style: t.meta())),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [for (final d in days) _Day(store: s, day: d)],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legend(t, _key(t, color: t.accent), 'perfect: meals, water, steps'),
                _legend(t, _key(t, color: t.ink), 'all 4 meals'),
                _legend(t, Icon(Icons.ac_unit_rounded, size: 13, color: t.ink), 'frozen'),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecapScreen(store: s))),
              icon: Icon(Icons.insights_rounded, color: t.ink),
              label: Text('This week\'s recap', style: t.body()),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: t.lane),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 32),
            Text('Medals', style: t.title()),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .82,
              children: [for (final m in medals) _Medal(m: m, earned: s.seenHints.contains('badge:${m.id}'))],
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(Daur t, {required Color color}) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _legend(Daur t, Widget mark, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: 6),
      Text(label, style: t.meta()),
    ],
  );
}

class _Day extends StatelessWidget {
  const _Day({required this.store, required this.day});
  final Store store;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final key = dayKey(day);
    final n = key == store.today ? store.legsDone : store.lapHistory[key] ?? 0;
    final what = store.frozenDays.contains(key)
        ? 'frozen'
        : store.perfect(key)
        ? 'perfect day'
        : n == 4
        ? 'all 4 meals'
        : '$n of 4 meals';
    return Semantics(label: '${day.day}: $what', excludeSemantics: true, child: _cell(context, key));
  }

  Widget _cell(BuildContext context, String key) {
    final t = Daur.of(context);
    final isToday = key == store.today;
    final n = isToday ? store.legsDone : store.lapHistory[key] ?? 0;
    // days after today, and days before the plan started, are drawn faint
    final future = day.isAfter(DateTime.now()) || key.compareTo(store.startDay) < 0;
    final perfect = !future && store.perfect(key);
    if (store.frozenDays.contains(key)) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.ink, width: 1.5),
        ),
        child: Icon(Icons.ac_unit_rounded, size: 16, color: t.ink),
      );
    }
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: perfect
            ? t.accent
            : n == 4
            ? t.ink
            : null,
        border: Border.all(
          color: isToday
              ? t.accent
              : n > 0
              ? t.ink
              : t.lane.withValues(alpha: future ? .3 : 1),
          width: isToday ? 2.5 : 1.5,
        ),
      ),
      child: Text(
        '${day.day}',
        style: t.meta(
          perfect
              ? t.onAccent
              : n == 4
              ? t.ground
              : (future ? t.faint : null),
        ),
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.m, required this.earned});
  final Milestone m;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: earned ? t.accent : null,
            border: Border.all(color: earned ? t.accent : t.lane, width: 2),
          ),
          child: Icon(earned ? m.icon : Icons.lock_outline_rounded, color: earned ? t.onAccent : t.faint, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          m.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.meta(earned ? t.ink : t.ink2),
        ),
      ],
    );
  }
}

/// The week in one screen (Sunday's notification opens it): big numbers, one line each.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = store;
    final w = s.week;
    final kg = w.kgChange;
    final tiles = <(IconData, String, String)>[
      (Icons.restaurant_rounded, '${w.full}/7', 'full days'),
      (Icons.star_rounded, '${w.perfect}/7', 'perfect days'),
      (
        Icons.monitor_weight_outlined,
        kg == null ? '—' : '${kg <= 0 ? '−' : '+'}${kg.abs().toStringAsFixed(1)}',
        kg == null ? 'weigh 3+ mornings' : 'kg vs last week',
      ),
      (Icons.local_fire_department_rounded, '${s.streak}', 'day streak'),
      (Icons.fitness_center_rounded, '${w.gym}', 'gym sessions'),
      (Icons.water_drop_outlined, '${w.water}/7', 'water days'),
      (Icons.directions_walk_rounded, w.steps == 0 ? '—' : thousands(w.steps), 'steps a day'),
      (Icons.account_balance_wallet_outlined, '৳${thousands(w.spent)}', 'spent'),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const PageHeader('Your week'),
            const SizedBox(height: 8),

            Text(_verdict(w.full), style: t.title()),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                for (final (icon, big, label) in tiles)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: t.ink, size: 22),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(big, style: t.x(28, weight: FontWeight.w900)),
                        ),
                        Text(label, style: t.meta()),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _verdict(int full) => full == 7
      ? 'Seven for seven.'
      : full >= 5
      ? 'A strong week.'
      : full >= 3
      ? 'Halfway there. Next week, one more day.'
      : 'A fresh week starts Monday.';
}
