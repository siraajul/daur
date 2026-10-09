import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';
import 'motion.dart';
import 'plan.dart';
import 'steps.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, thousands, niceDate;
import 'visuals.dart';

String litres(int glasses) => glasses % 4 == 0 ? '${glasses ~/ 4}' : '${glasses / 4}'; // 0, 0.25, 1.75, 2
const _dayLetters = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Water: a ring to today's goal, the glasses to tap, how far behind the day's pace you are.
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store, g = s.water, goal = s.waterGoal;
        final days = s.lastDays(7);
        final full = g >= goal;
        final values = [for (final d in days) d == s.today ? g : s.waterHistory[d] ?? 0];
        final drank = values.where((v) => v > 0).toList();
        final avg = drank.isEmpty ? 0 : drank.reduce((a, b) => a + b) / drank.length;
        final hit = values.where((v) => v >= goal).length;
        // pace: the goal spread evenly over 07:00–21:00
        final now = DateTime.now();
        final due = (goal * ((now.hour + now.minute / 60 - 7) / 14).clamp(0.0, 1.0)).floor();
        final behind = (due - g).clamp(0, goal);
        final perRow = (goal / 2).ceil();
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _Header(
                        title: 'Water',
                        sub: '${niceDate(now)} · each glass is 250 ml',
                        menu: [
                          MenuItem('Undo last glass', g > 0 ? () => s.setWater(g - 1) : null),
                          MenuItem('Reset today', g > 0 ? () => s.setWater(0) : null, destructive: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RingHero(
                        frac: g / goal,
                        big: '${litres(g)} L',
                        small: 'of ${litres(goal)} L',
                        pill: full ? 'Goal done' : '${goal - g} ${goal - g == 1 ? 'glass' : 'glasses'} to go',
                        done: full,
                        label: '${litres(g)} of ${litres(goal)} litres',
                      ),
                      const SizedBox(height: 20),
                      Tiles([
                        (Icons.local_drink_outlined, '$g', 'of $goal glasses'),
                        (Icons.schedule_rounded, '$behind', behind == 0 ? 'on pace' : 'behind pace'),
                        (Icons.event_available_rounded, '$hit of 7', 'days on goal'),
                      ]),
                      const SizedBox(height: 24),
                      _Head('Tap a glass', '${g * 250} ml'),
                      const SizedBox(height: 10),
                      GridView.count(
                        clipBehavior: Clip.none, // droplets fly above the glasses
                        crossAxisCount: perRow,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 8,
                        childAspectRatio: .7,
                        children: [
                          for (var i = 0; i < goal; i++)
                            Semantics(
                              button: true,
                              label: 'Glass ${i + 1}, ${i < g ? 'drunk' : 'not yet'}',
                              child: GestureDetector(
                                // tap glass n to set the count to n; tap the last full glass to empty it
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  s.setWater(g == i + 1 ? i : i + 1);
                                },
                                child: WaterGlass(full: i < g, next: i == g, wave: full, index: i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _Head('This week', 'avg ${litres((avg).round())} L a day'),
                      const SizedBox(height: 10),
                      WeekBars(days: days, values: values, target: goal, max: goal + 3),
                      const SizedBox(height: 24),
                      const _TipChips([
                        (Icons.fitness_center_rounded, 'Gym day: drink more'),
                        (Icons.wb_sunny_outlined, 'Hot day: drink more'),
                        (Icons.local_cafe_outlined, 'Plain tea counts'),
                        (Icons.medical_services_outlined, 'Doctor limits fluids? Follow that'),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: full
                      ? Cta(label: '${litres(goal)} L done today', muted: true)
                      : Cta(
                          label: 'Drink a glass',
                          trailing: 'glass ${g + 1} of $goal',
                          onTap: () {
                            s.setWater(g + 1);
                            g + 1 == goal ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
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

/// Sleep: last night's hours against 7–8, set with − / + or read from Health, and the week.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key, required this.store});
  final Store store;

  static String hours(int min) => (min / 60).toStringAsFixed(min % 60 == 0 ? 0 : 1);

  Future<void> _fromHealth(BuildContext context) async {
    final min = await Steps.sleepLastNight(ask: true);
    if (min != null) {
      store.setSleep(min);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No sleep in Health yet · a watch or sleep app adds it'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store, m = s.sleepMin;
        const goal = 420; // 7 h, the low end of 7–8
        final days = s.lastDays(7);
        final values = [for (final d in days) s.sleepHistory[d] ?? 0];
        final slept = values.where((v) => v > 0).toList();
        final avg = slept.isEmpty ? 0 : slept.reduce((a, b) => a + b) ~/ slept.length;
        final hit = values.where((v) => v >= goal).length;
        void nudge(int by) {
          HapticFeedback.selectionClick();
          s.setSleep(((m ?? goal) + (m == null ? 0 : by)).clamp(60, 16 * 60));
        }

        Widget round(IconData icon, String tip, VoidCallback f) => IconButton.filled(
          tooltip: tip,
          onPressed: f,
          style: IconButton.styleFrom(
            backgroundColor: t.infield,
            foregroundColor: t.ink,
            fixedSize: const Size(48, 48),
          ),
          icon: Icon(icon),
        );

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _Header(
                        title: 'Sleep',
                        sub: 'Last night · aim for 7–8 hours',
                        menu: [
                          MenuItem('Clear last night', m != null ? () => s.setSleep(null) : null, destructive: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RingHero(
                        frac: (m ?? 0) / goal,
                        big: m == null ? '–' : '${hours(m)} h',
                        small: 'of 7–8 hours',
                        pill: m == null
                            ? 'Not added yet'
                            : m >= goal
                            ? 'Enough sleep'
                            : '${hours(goal - m)} h short',
                        done: m != null && m >= goal,
                        label: m == null ? 'Sleep not added' : '${hours(m)} hours slept',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Hours slept', style: t.body(weight: FontWeight.w400)),
                          ),
                          round(Icons.remove, 'Half an hour less', () => nudge(-30)),
                          SizedBox(
                            width: 84,
                            child: Text(m == null ? '–' : hours(m), textAlign: TextAlign.center, style: t.x(24)),
                          ),
                          round(Icons.add, 'Half an hour more', () => nudge(30)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _Head('This week', slept.isEmpty ? 'nothing yet' : 'avg ${hours(avg)} h · $hit of 7 enough'),
                      const SizedBox(height: 10),
                      WeekBars(days: days, values: values, target: goal, max: 600),
                      const SizedBox(height: 24),
                      const _TipChips([
                        (Icons.restaurant_rounded, 'Short sleep = more hunger'),
                        (Icons.schedule_rounded, 'Same bedtime every night'),
                        (Icons.local_cafe_outlined, 'No tea after 17:00'),
                        (Icons.phone_android_rounded, 'Phone away in bed'),
                      ]),
                    ],
                  ),
                ),
                if (Steps.supported)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Cta(label: 'Get from Health', muted: m != null, onTap: () => _fromHealth(context)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Walk: today's steps against this week's target, the build-up ladder and the week.
class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key, required this.store, required this.steps, required this.onRefresh});
  final Store store;
  final int? steps; // from Health Connect / Apple Health, null if unavailable
  final Future<void> Function() onRefresh;
  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  Map<String, int>? _week; // from the health store
  List<int>? _hours; // today, hour by hour (health store only)
  late int? _steps = widget.steps;
  bool _loading = false;

  Store get s => widget.store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await widget.onRefresh();
    final w = await Steps.week(s.lastDays(7));
    final h = await Steps.hourly();
    if (!mounted) return;
    setState(() {
      _week = w;
      _hours = h;
      if (w != null) _steps = w[s.today];
      _loading = false;
    });
  }

  Future<void> _enter() async {
    final v = await askNumber(
      context,
      'Steps today',
      initial: s.manualSteps?.toString(),
      hint: 'From your phone\'s step counter',
    );
    if (v != null) s.setManualSteps(v.round());
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final fromHealth = _steps != null;
        final walked = _steps ?? s.manualSteps ?? 0;
        final target = stepTargetForDay(s.lap);
        final togo = (target - walked).clamp(0, 1 << 30);
        final km = walked / 1350; // ~0.74 m per step at your height
        final kcal = km * .5 * s.bodyKg; // walking ≈ 0.5 kcal per kg per km
        final week = (s.lap - 1) ~/ 7 + 1;
        final days = s.lastDays(7);

        final weekValues = [for (final d in days) d == s.today ? walked : _week?[d] ?? s.stepsHistory[d] ?? 0];
        final logged = weekValues.where((v) => v > 0).toList();
        final avg = logged.isEmpty ? 0 : logged.reduce((a, b) => a + b) ~/ logged.length;
        final hit = [for (final (i, d) in days.indexed) weekValues[i] >= s.stepTargetOn(d)].where((x) => x).length;
        final stage = s.lap <= 14
            ? 0
            : s.lap <= 28
            ? 1
            : 2;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        _Header(title: 'Walk', sub: 'Week $week · target ${thousands(target)} steps'),
                        const SizedBox(height: 16),
                        RingHero(
                          frac: walked / target,
                          big: thousands(walked),
                          small: 'of ${thousands(target)} steps',
                          pill: togo == 0 ? 'Target done' : '${thousands(togo)} to go',
                          done: togo == 0,
                          label: '${thousands(walked)} of ${thousands(target)} steps',
                        ),
                        const SizedBox(height: 20),
                        Tiles([
                          (Icons.straighten_rounded, km.toStringAsFixed(1), 'km'),
                          (Icons.local_fire_department_rounded, '${kcal.round()}', 'kcal'),
                          (Icons.timer_outlined, togo == 0 ? '0' : '${(togo / 105).ceil()}', 'min to go'),
                        ]),
                        if (_hours != null && _hours!.any((h) => h > 0)) ...[
                          const SizedBox(height: 24),
                          _Head('Today by the hour', 'most at ${_peak(_hours!)}:00'),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 84,
                            child: CustomPaint(painter: _HourBars(_hours!, t), size: Size.infinite),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _Head('This week', 'avg ${thousands(avg)} · $hit of 7 on target'),
                        const SizedBox(height: 10),
                        WeekBars(days: days, values: weekValues, target: target, max: 12000),
                        const SizedBox(height: 24),
                        Text('The build-up', style: t.meta()),
                        const SizedBox(height: 10),
                        // three steps of the plan; the yellow one is where you are
                        Row(
                          children: [
                            for (final (i, (weeks, steps)) in const [
                              ('Weeks 1–2', '7k'),
                              ('Weeks 3–4', '8k'),
                              ('Weeks 5–12', '10k'),
                            ].indexed) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: i == stage
                                            ? t.accent
                                            : i < stage
                                            ? t.ink
                                            : t.lane.withValues(alpha: .35),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(steps, style: t.x(18, color: i == stage ? t.ink : t.ink2)),
                                    Text(i == stage ? '$weeks · now' : weeks, style: t.meta(i == stage ? t.ink : null)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _TipChips([
                          (Icons.wb_sunny_outlined, '15–20 min after lunch'),
                          (Icons.bedtime_outlined, '15–20 min after dinner'),
                          (Icons.directions_run_rounded, 'Treadmill counts'),
                          (Icons.healing_outlined, 'Sore? Hold a week'),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                          fromHealth
                              ? 'From ${Theme.of(context).platform == TargetPlatform.iOS ? 'Apple Health' : 'Health Connect'}'
                                    ' · pull down to refresh'
                              : 'Typed in by hand',
                          style: t.meta(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: fromHealth
                      ? Cta(
                          label: _loading ? 'Refreshing…' : 'Refresh steps',
                          muted: true,
                          onTap: _loading ? null : _load,
                        )
                      : Cta(label: 'Enter today\'s steps', trailing: thousands(walked), onTap: _enter),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static int _peak(List<int> h) {
    var best = 0;
    for (var i = 1; i < h.length; i++) {
      if (h[i] > h[best]) best = i;
    }
    return best;
  }
}

/// The day's steps as a ring: lane track, ink arc (yellow once the target is done), runner dot.
class _Ring extends CustomPainter {
  _Ring(this.frac, this.t);
  final double frac;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - stroke / 2 - 4;
    final f = frac.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = t.ink.withValues(alpha: .12),
    );
    if (f <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708,
      f * 6.2832,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = f >= 1 ? t.accent : t.ink,
    );
    final a = -1.5708 + f * 6.2832;
    final p = c + Offset(r * math.cos(a), r * math.sin(a));
    canvas.drawCircle(p, 11, Paint()..color = t.accent);
    canvas.drawCircle(
      p,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.ground,
    );
  }

  @override
  bool shouldRepaint(_Ring o) => o.frac != frac || o.t != t;
}

/// Steps per hour from 5:00 to now; the busiest hour in yellow.
class _HourBars extends CustomPainter {
  _HourBars(this.h, this.t);
  final List<int> h;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    const first = 5, last = 23;
    final top = h.fold(1, (a, b) => b > a ? b : a);
    final peak = h.indexOf(top);
    const labelH = 16.0;
    final slot = size.width / (last - first + 1);
    for (var hr = first; hr <= last; hr++) {
      final v = hr < h.length ? h[hr] : 0;
      final x = (hr - first) * slot;
      final barH = v == 0 ? 2.0 : (size.height - labelH) * v / top;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + slot * .18, size.height - labelH - barH, slot * .64, barH),
          const Radius.circular(3),
        ),
        Paint()
          ..color = hr == peak
              ? t.accent
              : hr < h.length
              ? t.ink
              : t.lane.withValues(alpha: .3),
      );
      if (hr % 6 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$hr', style: t.meta()),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + slot / 2 - tp.width / 2, size.height - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_HourBars o) => o.h != h || o.t != t;
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.sub, this.menu = const []});
  final String title, sub;
  final List<MenuItem> menu;

  @override
  Widget build(BuildContext context) => PageHeader(title, sub: sub, actions: [if (menu.isNotEmpty) MoreButton(menu)]);
}

/// A ring that fills to today's target, a yellow dot at its tip; the number inside, a pill under it.
class RingHero extends StatelessWidget {
  const RingHero({
    super.key,
    required this.frac,
    required this.big,
    required this.small,
    required this.pill,
    required this.done,
    required this.label,
  });
  final double frac;
  final String big, small, pill, label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Center(
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: 220,
          child: CustomPaint(
            painter: _Ring(frac, t),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: Text(big, style: t.x(44, weight: FontWeight.w900)),
                    ),
                    Text(small, style: t.sec()),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: done ? t.accent : t.infield,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(pill, style: t.meta(done ? t.onAccent : t.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of equal tiles: icon, a number, what it is.
class Tiles extends StatelessWidget {
  const Tiles(this.items, {super.key});
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Row(
      children: [
        for (final (i, (icon, value, label)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: t.ink),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: t.x(22)),
                  ),
                  Text(label, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section label on the left, its one-line summary on the right.
class _Head extends StatelessWidget {
  const _Head(this.left, this.right);
  final String left, right;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Row(
      children: [
        Expanded(child: Text(left, style: t.meta())),
        Text(right, style: t.meta(t.ink)),
      ],
    );
  }
}

/// Tips as outlined chips, one icon and a few words each.
class _TipChips extends StatelessWidget {
  const _TipChips(this.tips);
  final List<(IconData, String)> tips;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, text) in tips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: t.lane, width: 1.5)),
            ),
            child: Stat(icon, text, color: t.ink, size: 13),
          ),
      ],
    );
  }
}

/// Seven daily bars with a dashed target line; today solid.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, required this.values, required this.target, required this.max});
  final List<String> days;
  final List<int> values;
  final int target, max;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    const h = 72.0;
    return SizedBox(
      height: h + 22,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 22 + h * (target / max).clamp(0, 1),
            child: CustomPaint(painter: _Dash(t.lane), size: const Size.fromHeight(1.5)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in days.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: (h * (values[i] / max)).clamp(3, h).toDouble(),
                          decoration: BoxDecoration(
                            color: i == days.length - 1 ? t.ink : t.faint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i == days.length - 1 ? 'Today' : _dayLetters[DateTime.parse(d).weekday - 1],
                          style: t.meta(i == days.length - 1 ? t.ink : null),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dash extends CustomPainter {
  _Dash(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Dash o) => o.c != c;
}
