import 'package:flutter/material.dart';

import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show thousands;
import 'visuals.dart';
import 'water_walk.dart' show RingHero, Tiles;

/// Ways to burn it, with their MET (Compendium of Physical Activities). Time is worked out at the
/// user's weight, counting only what's above resting (resting is already in the body's burn).
const burnWays = <(IconData, String, String, double)>[
  (Icons.directions_walk_rounded, 'Brisk walk', '5.6 km/h', 4.3),
  (Icons.directions_run_rounded, 'Treadmill, uphill', '5 km/h · 6% incline', 6.0),
  (Icons.pedal_bike_rounded, 'Cycling', 'stationary, steady', 6.8),
  (Icons.stairs_rounded, 'Stairs', 'up and down, brisk', 8.8),
  (Icons.sports_tennis_rounded, 'Badminton', 'a friendly game', 5.5),
  (Icons.pool_rounded, 'Swimming', 'easy laps', 6.0),
];

String hoursMinutes(int min) => min < 60 ? '${min}m' : '${min ~/ 60}h ${(min % 60).toString().padLeft(2, '0')}m';

/// Drawer → Burn (and Today when over): eaten against burned today, what's left to burn to stay
/// on plan, and how long each way of burning it takes at this weight.
class BurnScreen extends StatelessWidget {
  const BurnScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store, left = s.burnLeft, m = s.moved, moved = s.movedKcal;
        final ahead = [
          for (final m in meals)
            if (!s.done.containsKey(m.id) && !s.skipped.contains(m.id) && !s.fasted(m)) m,
        ];
        final aheadKcal = ahead.fold(0, (a, m) => a + s.mealKcal(m));
        final tonight = s.bodyBurn + moved - (s.kcal > s.kcalGoal ? s.kcal : s.kcalGoal);
        final over = left > 0;
        // over the target: time to burn what's left; on plan: what 30 more minutes would add
        final goal = over ? left : null;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Burn', sub: 'Today · eaten against burned'),
                const SizedBox(height: 16),
                // over: what's left to burn. On plan: today's plan left, and the deficit it's heading for
                // (counting the whole day's burn against breakfast alone would flatter the morning)
                RingHero(
                  frac: over ? moved / (moved + left) : s.kcal / s.kcalGoal,
                  big: over ? thousands(left) : 'On plan',
                  small: over
                      ? 'kcal left to burn'
                      : '${thousands((s.kcalGoal - s.kcal).clamp(0, 1 << 30))} kcal of the plan left',
                  pill: over ? '${thousands(moved)} burned so far' : '≈ ${thousands(tonight)} kcal deficit by tonight',
                  done: false,
                  label: over
                      ? '$left kilocalories left to burn'
                      : 'On plan, heading for a $tonight kilocalorie deficit',
                ),
                const SizedBox(height: 20),
                Tiles([
                  (Icons.restaurant_rounded, thousands(s.kcal), 'eaten'),
                  (Icons.accessibility_new_rounded, thousands(s.bodyBurn), 'body burns'),
                  (Icons.local_fire_department_rounded, thousands(moved), 'moved'),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Target ${thousands(s.kcalGoal)} · steps ${thousands(m.walk)} · treadmill ${thousands(m.treadmill)}'
                  ' · gym ${thousands(m.gym)}',
                  style: t.meta(),
                ),
                // meals still to come add to the day; a smaller plate is the other way to close the gap
                if (ahead.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Tip(
                    Icons.schedule_rounded,
                    '${ahead.map((m) => m.name.toLowerCase()).join(', ')} to come · +${thousands(aheadKcal)} kcal',
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text(over ? 'Burn it with' : 'Want a head start?', style: t.meta())),
                    Text(over ? 'any one of these' : '30 more minutes', style: t.meta(t.ink)),
                  ],
                ),
                const SizedBox(height: 4),
                for (final (icon, name, how, met) in burnWays)
                  Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.rule, width: .5)),
                    ),
                    child: Row(
                      children: [
                        IconDisc(icon, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name, style: t.body()),
                              Text(
                                // a walk is easiest to picture in steps
                                name == 'Brisk walk' && goal != null
                                    ? '$how · ≈ ${thousands((s.minutesFor(goal, met) / 60 * 5.6 * 1350).round())} steps'
                                    : how,
                                style: t.meta(),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          goal != null
                              ? hoursMinutes(s.minutesFor(goal, met))
                              : '${((met - 1) * s.bodyKg / 2).round()} kcal',
                          style: t.x(17),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (over && left > 600)
                  const Tip(Icons.calendar_view_week_rounded, 'A lot for one day: split it over 2–3'),
                const Tip(Icons.restaurant_menu_rounded, 'Still eat your planned meals tomorrow'),
                const Tip(Icons.info_outline_rounded, 'Estimates at your weight · give or take 20%'),
              ],
            ),
          ),
        );
      },
    );
  }
}
