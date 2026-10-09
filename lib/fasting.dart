import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'plan.dart';
import 'store.dart';
import 'targets.dart' show groundChip;
import 'theme.dart';
import 'today.dart' show thousands, Cta, undoToast;
import 'visuals.dart';
import 'water_walk.dart' show WeekBars;

String _hh(int h) => '${(h % 24).toString().padLeft(2, '0')}:00';
String _dur(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

/// The stages of a fast in plain words, from the hour each starts. A rough guide: bodies vary,
/// and no app can measure this; it's there to make the hours feel like they are going somewhere.
const fastStages = <(int, String, IconData)>[
  (0, 'Digesting', Icons.restaurant_rounded),
  (4, 'Sugar dropping', Icons.trending_down_rounded),
  (8, 'Switching to fat', Icons.sync_rounded),
  (12, 'Burning fat', Icons.local_fire_department_rounded),
  (16, 'Deep fast', Icons.auto_awesome_rounded),
];

int stageAt(Duration d) => fastStages.lastIndexWhere((st) => d.inMinutes >= st.$1 * 60);

/// Where the fast stands now: the one started by hand if there is one, else the plan's schedule
/// (fasting outside the eating window, eating inside it).
({bool eating, Duration elapsed, Duration left, double frac}) fastNow(Store s, DateTime now) {
  if (s.fastFrom != null) {
    final total = Duration(hours: s.fastGoal), e = now.difference(s.fastFrom!), l = total - e;
    return (eating: false, elapsed: e, left: l.isNegative ? Duration.zero : l, frac: e.inSeconds / total.inSeconds);
  }
  final start = DateTime(now.year, now.month, now.day, s.eatStart);
  final end = DateTime(now.year, now.month, now.day, s.eatEnd);
  if (!now.isBefore(start) && now.isBefore(end)) {
    final total = end.difference(start);
    return (
      eating: true,
      elapsed: now.difference(start),
      left: end.difference(now),
      frac: now.difference(start).inSeconds / total.inSeconds,
    );
  }
  // the fast runs from the window's close to its next open
  final fastStart = now.isBefore(start) ? end.subtract(const Duration(days: 1)) : end;
  final fastEnd = now.isBefore(start) ? start : start.add(const Duration(days: 1));
  final total = fastEnd.difference(fastStart);
  return (
    eating: false,
    elapsed: now.difference(fastStart),
    left: fastEnd.difference(now),
    frac: now.difference(fastStart).inSeconds / total.inSeconds,
  );
}

/// One row on Today while fasting is on: the fast's progress and stage, or the eating window's.
class FastBar extends StatelessWidget {
  const FastBar({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = store;
    final f = fastNow(s, DateTime.now());
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FastingScreen(store: s))),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(f.eating ? Icons.restaurant_rounded : fastStages[stageAt(f.elapsed)].$3, size: 18, color: t.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.eating
                        ? 'Eating window · ${_dur(f.left)} left'
                        : 'Fasting ${_dur(f.elapsed)} · ${fastStages[stageAt(f.elapsed)].$2}',
                    style: t.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  f.eating
                      ? 'closes ${_hh(s.eatEnd)}'
                      : s.fastFrom == null
                      ? 'eat at ${_hh(s.eatStart)}'
                      : f.left == Duration.zero
                      ? 'goal done'
                      : '${_dur(f.left)} left',
                  style: t.sec(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f.frac.clamp(0, 1).toDouble(),
                minHeight: 6,
                color: f.eating ? t.ink : t.accent,
                backgroundColor: t.lane.withValues(alpha: .35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drawer → Fasting. Off: the three plans as cards. On: the fast as a live ring through its stages,
/// Start / End to log real fasts, the eating window, and the last 7 days.
class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key, required this.store});
  final Store store;

  static const plans = ['14:10', '16:8', '18:6'];

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  late final Timer _tick;
  int? _stage; // to buzz once when a new stage starts while watching

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _end(BuildContext context) {
    final s = widget.store, snap = s.snapshot();
    final d = s.endFast()!;
    d.inMinutes >= s.fastGoal * 60 ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
    undoToast(context, d.inMinutes < 30 ? 'Fast ended · too short to keep' : 'Fast saved · ${_dur(d)}', () {
      s.restore(snap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store;
        final on = s.fastPlan != null;
        final live = on || s.fastFrom != null;
        final f = fastNow(s, DateTime.now());
        final stage = f.eating ? null : stageAt(f.elapsed);
        if (_stage != null && stage != null && stage > _stage!) HapticFeedback.mediumImpact();
        _stage = stage;
        final day = meals.fold(0, (a, m) => a + s.mealKcal(m) * (s.fasted(m) ? 0 : 1));
        final days = s.lastDays(7);
        final streak = s.fastStreak;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      PageHeader(
                        'Fasting',
                        sub: on
                            ? 'Eat ${_hh(s.eatStart)}–${_hh(s.eatEnd)} · fast ${s.fastHours}h'
                            : 'Eat inside a window, fast the rest',
                      ),
                      const SizedBox(height: 20),
                      if (!live) ...[
                        for (final (p, eat, how) in const [
                          ('14:10', 10, 'Easy start'),
                          ('16:8', 8, 'The usual one'),
                          ('18:6', 6, 'Hard'),
                        ])
                          _PlanCard(plan: p, eat: eat, how: how, onTap: () => s.setFast(p)),
                        const SizedBox(height: 8),
                        const Tip(Icons.restaurant_rounded, 'Same food for the day, eaten in fewer hours'),
                      ] else ...[
                        if (on)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              groundChip(context, 'Off', false, () => s.setFast(null)),
                              for (final p in FastingScreen.plans)
                                groundChip(context, p, s.fastPlan == p, () => s.setFast(p)),
                            ],
                          ),
                        const SizedBox(height: 24),
                        _StageRing(f: f, goal: s.fastGoal, byHand: s.fastFrom != null),
                        if (!f.eating) ...[
                          const SizedBox(height: 24),
                          _StageLine(elapsed: f.elapsed, goal: s.fastGoal),
                        ],
                        if (on) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Eat from', style: t.body(weight: FontWeight.w400)),
                              ),
                              IconButton(
                                tooltip: 'Earlier',
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  s.setFast(s.fastPlan, start: s.eatStart - 1);
                                },
                                icon: Icon(Icons.remove, color: t.ink),
                              ),
                              Text('${_hh(s.eatStart)}–${_hh(s.eatEnd)}', style: t.x(18)),
                              IconButton(
                                tooltip: 'Later',
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  s.setFast(s.fastPlan, start: s.eatStart + 1);
                                },
                                icon: Icon(Icons.add, color: t.ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final m in meals)
                            Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: t.rule, width: .5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(mealIcon(m.id), size: 20, color: s.fasted(m) ? t.ink2 : t.ink),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(m.name, style: t.body(color: s.fasted(m) ? t.ink2 : t.ink)),
                                  ),
                                  Text(
                                    s.fasted(m) ? 'fasting' : '${thousands(s.mealKcal(m))} kcal',
                                    style: s.fasted(m) ? t.sec() : t.x(15),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: t.rule, width: .5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text('Your day', style: t.body())),
                                Text('${thousands(day)} kcal', style: t.x(17)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Text('Last 7 days', style: t.meta())),
                            Text(
                              streak > 0 ? '$streak-day fasting streak' : 'tap Start to log a fast',
                              style: t.meta(t.ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        WeekBars(
                          days: days,
                          values: [for (final d in days) s.fastMinOn(d)],
                          target: s.fastGoal * 60,
                          max: (s.fastGoal + 6) * 60,
                        ),
                        const SizedBox(height: 16),
                        const Tip(Icons.insights_rounded, 'Stages are a rough guide · bodies vary'),
                      ],
                      const Tip(Icons.local_cafe_outlined, 'While fasting: water, black tea, black coffee'),
                      const Tip(Icons.medical_services_outlined, 'Diabetic or on medicine? Ask your doctor first'),
                    ],
                  ),
                ),
                if (live)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: s.fastFrom != null
                        ? Cta(label: 'End fast', trailing: _dur(f.elapsed), onTap: () => _end(context))
                        : Cta(
                            label: 'Start fast now',
                            trailing: 'goal ${s.fastGoal}h',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              s.startFast();
                            },
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.eat, required this.how, required this.onTap});
  final String plan, how;
  final int eat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: t.infield,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(plan, style: t.x(26, weight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(how, style: t.body()),
                      Text('eat $eat hours · fast ${24 - eat}', style: t.meta()),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero: a ring that fills to the goal, a stage notch at each stage's hour, a breathing yellow
/// tip; inside, the stage's icon (springs in when a stage starts), the clock and the stage's name.
class _StageRing extends StatefulWidget {
  const _StageRing({required this.f, required this.goal, required this.byHand});
  final ({bool eating, Duration elapsed, Duration left, double frac}) f;
  final int goal;
  final bool byHand;

  @override
  State<_StageRing> createState() => _StageRingState();
}

class _StageRingState extends State<_StageRing> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _pulse.stop() : _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final f = widget.f;
    final st = f.eating ? null : fastStages[stageAt(f.elapsed)];
    final d = f.elapsed;
    final done = !f.eating && f.left == Duration.zero && widget.byHand;
    final icon = st?.$3 ?? Icons.restaurant_rounded;
    final name = f.eating ? 'Eating window' : st!.$2;
    return Semantics(
      label: f.eating ? 'Eating window, ${_dur(f.left)} left' : 'Fasting ${_dur(d)} of ${widget.goal} hours, ${st!.$2}',
      excludeSemantics: true,
      child: Center(
        child: SizedBox.square(
          dimension: 248,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: f.frac.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, frac, child) => AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) =>
                  CustomPaint(painter: _StagePainter(frac, widget.goal, f.eating, _pulse.value, t), child: child),
              child: child,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (c, a) => ScaleTransition(
                      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                      child: FadeTransition(opacity: a, child: c),
                    ),
                    child: Icon(icon, key: ValueKey(icon), size: 30, color: f.eating ? t.ink : t.accent),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}',
                        style: t.x(44, weight: FontWeight.w900),
                      ),
                      Text(':${(d.inSeconds % 60).toString().padLeft(2, '0')}', style: t.x(16, color: t.ink2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(name, key: ValueKey(name), style: t.body()),
                  ),
                  Text(
                    f.eating
                        ? '${_dur(f.left)} left to eat'
                        : done
                        ? 'Goal done · ${widget.goal}h'
                        : 'of ${widget.goal}h',
                    style: t.meta(done ? t.accent : null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.frac, this.goal, this.eating, this.pulse, this.t);
  final double frac, pulse;
  final int goal;
  final bool eating;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0, top = -math.pi / 2;
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - stroke / 2 - 12;
    Offset at(double f) => c + Offset(r * math.cos(top + f * 2 * math.pi), r * math.sin(top + f * 2 * math.pi));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = t.ink.withValues(alpha: .12),
    );
    if (frac > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        top,
        frac * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = frac >= 1 ? t.accent : t.ink,
      );
    }
    // a notch where each stage starts: cut into the arc once passed, a faint dot ahead
    if (!eating) {
      for (final (h, _, _) in fastStages) {
        if (h == 0 || h >= goal) continue;
        final f = h / goal;
        canvas.drawCircle(at(f), 4, Paint()..color = f <= frac ? t.ground : t.ink.withValues(alpha: .45));
      }
    }
    // the tip breathes: a yellow dot with a ring spreading out and fading
    final p = at(frac);
    canvas.drawCircle(p, 12 + 12 * pulse, Paint()..color = t.accent.withValues(alpha: .4 * (1 - pulse)));
    canvas.drawCircle(p, 12, Paint()..color = t.accent);
    canvas.drawCircle(
      p,
      12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.ground,
    );
  }

  @override
  bool shouldRepaint(_StagePainter o) =>
      o.frac != frac || o.pulse != pulse || o.goal != goal || o.eating != eating || o.t != t;
}

/// The stages as a line of discs: passed ones filled, the current one yellow, the rest outlined;
/// the line between them fills as the hours pass.
class _StageLine extends StatelessWidget {
  const _StageLine({required this.elapsed, required this.goal});
  final Duration elapsed;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final stages = fastStages.where((st) => st.$1 <= goal).toList();
    final n = stages.length, cur = stageAt(elapsed).clamp(0, n - 1);
    final hrs = elapsed.inMinutes / 60;
    final next = cur + 1 < n ? stages[cur + 1].$1 : null;
    final along = cur + (next == null ? 0 : ((hrs - stages[cur].$1) / (next - stages[cur].$1)).clamp(0.0, 1.0));
    const disc = 40.0;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / n;
        return Stack(
          children: [
            // the line from the first disc's centre to the last, filled up to now
            Positioned(
              left: w / 2,
              right: w / 2,
              top: disc / 2 - 2,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(color: t.lane.withValues(alpha: .35)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: n == 1 ? 1 : along / (n - 1)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        alignment: Alignment.centerLeft,
                        child: Container(color: t.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (h, name, icon)) in stages.indexed)
                  Expanded(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          width: i == cur ? disc : disc - 8,
                          height: i == cur ? disc : disc - 8,
                          margin: EdgeInsets.all(i == cur ? 0 : 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == cur
                                ? t.accent
                                : i < cur
                                ? t.ink
                                : t.ground,
                            border: i > cur ? Border.all(color: t.lane, width: 1.5) : null,
                          ),
                          child: Icon(
                            icon,
                            size: i == cur ? 20 : 16,
                            color: i == cur
                                ? t.onAccent
                                : i < cur
                                ? t.ground
                                : t.ink2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(name, textAlign: TextAlign.center, maxLines: 2, style: t.meta(i == cur ? t.ink : null)),
                        Text('${h}h', style: t.meta(t.ink2)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
