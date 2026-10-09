import 'package:flutter/material.dart';

import 'motion.dart';
import 'plan.dart' as plan;
import 'plan.dart' show laps;
import 'store.dart';

/// Milestones worth a medal. Each is earned once (remembered in the store's seen hints).
class Milestone {
  final String id, title, sub;
  final IconData icon;
  final bool Function(Store s) earned;
  const Milestone(this.id, this.icon, this.title, this.sub, this.earned);
}

/// Loss on the 7-day trend (3+ weigh-ins), so one light morning can't mint a medal.
double _lost(Store s) => s.trendKg == null ? 0 : s.startKg - s.trendKg!;

/// Month targets are the person's own (plan.dart's for the original plan); medals are by name.
bool _hit(Store s, String month) {
  final t = s.targets.where((x) => x.$1 == month).firstOrNull;
  return t != null && s.trendKg != null && s.trendKg! <= double.parse(t.$2.split('–').last);
}

final medals = <Milestone>[
  Milestone(
    'weigh-1',
    Icons.monitor_weight_outlined,
    'First weigh-in',
    'The trend starts here. Weigh 3–7 mornings a week.',
    (s) => s.weights.isNotEmpty,
  ),
  Milestone(
    'kg-1',
    Icons.trending_down_rounded,
    '1 kg down',
    'The first one is the hardest to see. Keep logging.',
    (s) => _lost(s) >= 1,
  ),
  Milestone('kg-2.5', Icons.trending_down_rounded, '2.5 kg down', 'Right on the plan\'s pace.', (s) => _lost(s) >= 2.5),
  Milestone('kg-5', Icons.emoji_events_outlined, '5 kg down', 'Five kilos lighter than day 1.', (s) => _lost(s) >= 5),
  Milestone(
    'kg-7.5',
    Icons.emoji_events_outlined,
    '7.5 kg down',
    'Most people never get this far. You did.',
    (s) => _lost(s) >= 7.5,
  ),
  Milestone('kg-10', Icons.workspace_premium_outlined, '10 kg down', 'Double digits.', (s) => _lost(s) >= 10),
  for (final (name, _, day) in plan.milestones)
    Milestone(
      'target-$name',
      Icons.flag_outlined,
      '$name target hit',
      'Your 7-day average reached the $name goal (day $day).',
      (s) => _hit(s, name),
    ),
  Milestone(
    'perfect-1',
    Icons.star_rounded,
    'First perfect day',
    'Every meal, the water and the steps. All of it.',
    (s) => s.perfectDays >= 1,
  ),
  Milestone(
    'perfect-7',
    Icons.stars_rounded,
    '7 perfect days',
    'A week\'s worth of perfect.',
    (s) => s.perfectDays >= 7,
  ),
  Milestone(
    'streak-7',
    Icons.local_fire_department_rounded,
    '7 full days in a row',
    'A whole week, every meal logged.',
    (s) => s.streak >= 7,
  ),
  Milestone(
    'streak-21',
    Icons.local_fire_department_rounded,
    '21 full days in a row',
    'Three weeks without a missed meal.',
    (s) => s.streak >= 21,
  ),
  Milestone(
    'cut-done',
    Icons.military_tech_outlined,
    '84 days',
    'The 12-week plan, start to finish.',
    (s) => s.lap >= laps && s.legsDone == 4,
  ),
];

/// Show medals for anything newly earned, one after another. Call after a weigh-in or a lap.
Future<void> checkBadges(BuildContext context, Store s) async {
  final fresh = medals.where((b) => !s.seenHints.contains('badge:${b.id}') && b.earned(s)).toList();
  for (final b in fresh) {
    s.dismissHint('badge:${b.id}');
  }
  // several at once (e.g. a big first weigh-in): show the most impressive, mark the rest earned
  if (fresh.isEmpty || !context.mounted) return;
  final b = fresh.last;
  await showMedal(context, icon: b.icon, title: b.title, sub: b.sub);
}
