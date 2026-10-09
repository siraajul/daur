import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dau.dart';
import 'adaptive.dart';
import 'burn.dart';
import 'coach.dart';
import 'coaching.dart' show NoteCard;
import 'fasting.dart';
import 'meal_sheet.dart';
import 'plan.dart';
import 'steps.dart';
import 'streak.dart';
import 'store.dart';
import 'theme.dart';
import 'motion.dart';
import 'track.dart';
import 'visuals.dart';
import 'water_walk.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String niceDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// "Junk this week" line, shared by Today, the meal sheet and the Food tab.
(String, String) junkStatus(Store s, {int adding = 0}) {
  final n = s.junkThisWeek + adding, a = s.junkAllowance;
  final resets = 'resets ${niceDate(s.weekResets)}';
  if (a == 0) {
    return (n == 0 ? 'No junk this week' : 'Junk this week: $n', 'Month 1: keep junk to a minimum · $resets');
  }
  return (
    n > a ? 'Junk this week: $n, over the 1 allowed' : 'Junk this week: $n of 1',
    '1 controlled meal a week · $resets',
  );
}

/// Opens the app drawer from any tab's header.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key, this.dot = false});
  final bool dot; // a one-time hint that the drawer holds more (day 3)
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () => openMenu(context),
    icon: Badge(
      isLabelVisible: dot,
      backgroundColor: Daur.of(context).accent,
      smallSize: 9,
      // Android: the drawer's ≡; iPhone: a profile button that opens the More page
      child: Icon(isIOS(context) ? CupertinoIcons.person_crop_circle : Icons.menu, color: Daur.of(context).ink),
    ),
    tooltip: dot ? 'Menu: Food guide, Reminders and more' : 'Menu',
  );
}

void undoToast(BuildContext context, String msg, VoidCallback undo) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Undo', onPressed: undo),
    ),
  );

/// Open the logging sheet; whatever it changes can be undone exactly from the snackbar.
Future<void> openMeal(BuildContext context, Store s, {Meal? meal, int n = 0}) async {
  final snap = s.snapshot();
  final junkBefore = s.rareToday;
  final msg = await showMealSheet(context, s, meal: meal, n: n);
  if (msg != null && context.mounted) undoToast(context, msg, () => s.restore(snap));
  // first junk meal in month 1: one gentle pointer to the rule
  if (s.rareToday > junkBefore && s.junkAllowance == 0) s.showHintNow('junk-first');
}

/// One impact controller for Today: the track nudges the screen when the runner lands.
final _impact = ImpactController();

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.store, required this.steps, required this.onRefreshSteps});
  final Store store;
  final int? steps;
  final Future<void> Function() onRefreshSteps;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = store;
    final next = s.nextMeal;
    final stepTarget = stepTargetForDay(s.lap);
    final walked = steps ?? s.manualSteps ?? 0;
    final fastedLeft = meals.where((m) => s.fasted(m) && !s.done.containsKey(m.id)).length;

    return Impact(
      controller: _impact,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MenuButton(dot: s.drawerDot),
                      Text('DAY ${s.lap}', style: t.x(22)),
                      const SizedBox(width: 8),
                      Text('of $laps', style: t.meta()),
                      const Spacer(),
                      // the flame opens the streak: calendar of full days, best run, medals
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreakScreen(store: s))),
                        child: StreakFlame(streak: s.streak),
                      ),
                      const SizedBox(width: 10),
                      Text(niceDate(DateTime.now()), style: t.sec()),
                    ],
                  ),
                  CoachCard(store: s),
                  NoteCard(store: s),
                  if (s.fastPlan != null) FastBar(store: s),
                  const SizedBox(height: 8),
                  Track(
                    impact: _impact,
                    meters: s.legsDone * 100,
                    // fasted meals move the runner but aren't meals: "1 of 3", not "2 of 4"
                    count: s.legsDone - fastedLeft,
                    of: 4 - fastedLeft,
                    caption: s.legsDone == 4
                        ? 'Done for today\n${thousands(s.kcal)} kcal · ${s.protein} g protein'
                        : '${thousands(s.kcal)} of ${thousands(s.kcalGoal)} kcal\n${s.protein} of ${s.proteinText} g protein',
                  ),
                  if (s.kcal > 0) Center(child: _BurnPill(store: s)),
                  // the lap is run: Dau cheers (decoration; the caption already says it)
                  if (s.legsDone == 4) const Center(child: Dau(mood: DauMood.cheer, size: 96)),
                  const SizedBox(height: 8),
                  for (final (i, m) in meals.indexed) _Leg(store: s, meal: m, n: (i + 1) * 100, isNext: m == next),
                  for (final (i, e) in s.extras.indexed)
                    _Line(
                      lead: IconDisc(foodIcon(e.name, e.cat), size: 36, rare: e.rare),
                      title: e.qty == 1 ? e.name : '${qtyText(e.qty)} × ${e.name}',
                      sub: 'Extra · ${e.totalKcal} kcal',
                      right: '',
                      action: IconButton(
                        tooltip: 'Remove ${e.name}',
                        icon: Icon(Icons.close_rounded, color: t.ink2),
                        onPressed: () {
                          final snap = s.snapshot();
                          s.removeExtra(i);
                          undoToast(context, '${e.name} removed', () => s.restore(snap));
                        },
                      ),
                    ),
                  InkWell(
                    onTap: () => openMeal(context, s),
                    child: _Line(
                      lead: Icon(Icons.add_circle_outline, color: t.ink),
                      title: 'Ate something extra?',
                      sub: 'Tea with sugar, a singara…',
                      right: '',
                    ),
                  ),
                  // the junk count only when there is junk to count
                  if (s.junkThisWeek > 0)
                    Builder(
                      builder: (_) {
                        final (title, sub) = junkStatus(s);
                        final over = s.junkThisWeek > s.junkAllowance;
                        return _Line(
                          lead: Icon(
                            over ? Icons.warning_amber_rounded : Icons.fastfood_outlined,
                            color: over ? t.ink : t.ink2,
                          ),
                          title: title,
                          sub: sub,
                          right: '',
                        );
                      },
                    ),
                  // over the day's target: how much is left to burn, and the plainest way to do it
                  if (s.burnLeft > 0)
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BurnScreen(store: s))),
                      child: _Line(
                        lead: Icon(Icons.local_fire_department_rounded, color: t.accent),
                        title: '${thousands(s.kcal - s.kcalGoal)} kcal over',
                        sub:
                            'Burn ${thousands(s.burnLeft)} more · ${hoursMinutes(s.minutesFor(s.burnLeft, burnWays.first.$4))} brisk walk',
                        right: '',
                      ),
                    ),
                  const SizedBox(height: 24),
                  // water, walk, sleep: three tiles, each opens its screen; water adds a glass in one tap
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch, // three tiles, one height
                      children: [
                        Expanded(
                          child: _Tile(
                            icon: Icons.water_drop_outlined,
                            label: 'Water',
                            value: '${litres(s.water)} L',
                            sub: 'of ${litres(s.waterGoal)} L',
                            frac: s.water / s.waterGoal,
                            onOpen: () =>
                                Navigator.push(context, MaterialPageRoute(builder: (_) => WaterScreen(store: s))),
                            action: s.water >= s.waterGoal
                                ? null
                                : () {
                                    s.setWater(s.water + 1);
                                    HapticFeedback.lightImpact();
                                  },
                            actionIcon: Icons.add,
                            actionLabel: 'Add a glass',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Tile(
                            icon: Icons.directions_walk_rounded,
                            label: 'Walk',
                            value: thousands(walked),
                            sub: 'of ${thousands(stepTarget)}',
                            frac: walked / stepTarget,
                            action: steps != null ? onRefreshSteps : () => _enterSteps(context),
                            actionIcon: steps != null ? Icons.refresh_rounded : Icons.edit_rounded,
                            actionLabel: steps != null ? 'Refresh steps' : 'Enter steps',
                            onOpen: steps == null && !Steps.supported
                                ? () => _enterSteps(context)
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalkScreen(store: s, steps: steps, onRefresh: onRefreshSteps),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Tile(
                            icon: Icons.bedtime_outlined,
                            label: 'Sleep',
                            value: s.sleepMin == null
                                ? 'Add'
                                : '${s.sleepMin! ~/ 60}h ${(s.sleepMin! % 60).toString().padLeft(2, '0')}',
                            sub: 'of 7–8 h',
                            frac: (s.sleepMin ?? 0) / 450,
                            action: () => _enterSleep(context),
                            actionIcon: Icons.edit_rounded,
                            actionLabel: 'Enter sleep',
                            onOpen: () => _enterSleep(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: next == null
                  ? Cta(label: 'All meals logged · see you tomorrow', muted: true)
                  : Cta(
                      label: 'Log ${next.name.toLowerCase()}',
                      trailing: '${s.mealKcal(next)} kcal',
                      onTap: () {
                        final snap = s.snapshot();
                        s.logMeal(next);
                        s.legsDone == 4 ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
                        undoToast(context, '${next.name} logged: ${s.chosen(next).name}', () => s.restore(snap));
                      },
                      onLongPress: () => openMeal(context, s, meal: next, n: (meals.indexOf(next) + 1) * 100),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _enterSleep(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SleepScreen(store: store)));

  Future<void> _enterSteps(BuildContext context) async {
    final v = await askNumber(
      context,
      'Steps today',
      initial: store.manualSteps?.toString(),
      hint: 'From your step counter',
      side: Steps.supported
          ? (
              'Connect Health',
              () async {
                // Health Connect missing (Android 9–13): open its store page; otherwise ask for access
                await Steps.available() ? await Steps.today(ask: true) : await Steps.installHealthConnect();
                await onRefreshSteps();
              },
            )
          : null,
    );
    if (v != null) store.setManualSteps(v.round());
  }
}

/// Under the track: yellow "72 to burn · 13 min walk" once over today's target, a quiet
/// "1,398 kcal left today" before. Either way it opens Burn.
class _BurnPill extends StatelessWidget {
  const _BurnPill({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context), s = store, left = s.burnLeft;
    // Gain: what's still to eat, in yellow from 18:00 when the day is running out
    final over = s.gaining ? s.eatLeft > 0 && DateTime.now().hour >= 18 : left > 0;
    final text = s.gaining
        ? (s.eatLeft > 0 ? '${thousands(s.eatLeft)} kcal still to eat' : 'Today\'s target eaten')
        : over
        ? '${thousands(left)} to burn · ${hoursMinutes(s.minutesFor(left, burnWays.first.$4))} walk'
        : '${thousands((s.kcalGoal - s.kcal).clamp(0, 1 << 30))} kcal left today';
    return Semantics(
      button: true,
      label: '$text. Opens ${s.gaining ? 'Fuel' : 'Burn'}',
      excludeSemantics: true,
      child: Material(
        color: over ? t.accent : t.infield,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BurnScreen(store: s))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  over ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                  size: 18,
                  color: over ? t.onAccent : t.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: t.body(color: over ? t.onAccent : t.ink, weight: FontWeight.w700),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: over ? t.onAccent : t.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.store, required this.meal, required this.n, required this.isNext});
  final Store store;
  final Meal meal;
  final int n;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final eaten = store.done[meal.id];
    final skipped = store.skipped.contains(meal.id);
    final fasting = eaten == null && store.fasted(meal); // outside the eating window
    final rare = store.mealRare(meal);
    return InkWell(
      onTap: () => openMeal(context, store, meal: meal, n: n),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: n == 100 ? Colors.transparent : t.rule, width: .5)),
        ),
        child: Row(
          children: [
            // status, not a distance: ✓ eaten, – skipped, yellow ring = next
            SizedBox(
              width: 52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: eaten != null
                      ? 'eaten'
                      : fasting
                      ? 'fasting'
                      : skipped
                      ? 'skipped'
                      : isNext
                      ? 'next'
                      : 'not logged yet',
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: eaten != null ? t.ink : null,
                      border: Border.all(
                        color: eaten != null
                            ? t.ink
                            : isNext
                            ? t.accent
                            : t.lane,
                        width: isNext ? 2.5 : 1.5,
                      ),
                    ),
                    child: eaten != null
                        ? Icon(Icons.check_rounded, size: 18, color: t.ground)
                        : fasting
                        ? Icon(Icons.hourglass_bottom_rounded, size: 16, color: t.ink2)
                        : skipped
                        ? Icon(Icons.remove_rounded, size: 18, color: t.ink2)
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(mealIcon(meal.id), size: 18, color: skipped ? t.ink2 : t.ink),
                      const SizedBox(width: 6),
                      Text(meal.name, style: t.body(color: skipped ? t.ink2 : t.ink)),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fasting ? 'Fasting' : store.mealLabel(meal),
                          style: t.meta(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rare) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Junk food',
                          child: Icon(Icons.local_fire_department_rounded, size: 16, color: t.ink),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (isNext) ...[CircleAvatar(radius: 4, backgroundColor: t.accent), const SizedBox(width: 6)],
                    Text(eaten ?? (skipped || fasting ? '—' : meal.window), style: t.sec(t.ink)),
                  ],
                ),
                if (!skipped && !fasting) Text('${store.mealKcal(meal)} kcal', style: t.meta()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.lead, required this.title, required this.sub, required this.right, this.action});
  final Widget lead;
  final String title, sub, right;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(alignment: Alignment.centerLeft, child: lead),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.body(weight: FontWeight.w500)),
                Text(sub, style: t.meta()),
              ],
            ),
          ),
          Text(right, style: t.meta()),
          ?action,
        ],
      ),
    );
  }
}

/// Water, Walk or Sleep at a glance. All three are built the same, so they line up: label, value,
/// the target, and a bar with the tile's one-tap action beside it (+ glass, refresh, edit).
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.frac,
    required this.onOpen,
    required this.action,
    required this.actionIcon,
    required this.actionLabel,
  });
  final IconData icon, actionIcon;
  final String label, value, sub, actionLabel;
  final double frac;
  final VoidCallback onOpen;
  final VoidCallback? action; // null = done for today (the button dims)

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Material(
      color: t.infield,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: t.ink),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(label, style: t.sec(t.ink), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.x(22)),
              ),
              Text(sub, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: frac.clamp(0, 1).toDouble(),
                        minHeight: 6,
                        color: frac >= 1 ? t.accent : t.ink,
                        backgroundColor: t.lane.withValues(alpha: .35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: action,
                    tooltip: actionLabel,
                    icon: Icon(actionIcon, size: 16, color: action == null ? t.ink2 : t.onAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: t.accent,
                      disabledBackgroundColor: t.lane.withValues(alpha: .25),
                      minimumSize: const Size(32, 32),
                      fixedSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Cta extends StatelessWidget {
  const Cta({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.muted = false,
    this.onDark = true,
  });
  final String label;
  final String? trailing;
  final VoidCallback? onTap, onLongPress;
  final bool muted, onDark;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final bg = muted ? (onDark ? t.ink.withValues(alpha: .14) : t.sheetRule) : t.accent;
    final fg = muted ? (onDark ? t.ink : t.sheetInk) : t.onAccent;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        onLongPress: onLongPress,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
