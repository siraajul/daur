import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'plan.dart';
import 'steps.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, thousands, niceDate;
import 'visuals.dart';

String litres(int glasses) => glasses % 4 == 0 ? '${glasses ~/ 4}' : '${glasses / 4}'; // 0, 0.25, 1.75, 2
const _dayLetters = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Water: 14 glasses of 250 ml. Tap a glass to set the count, or drink one from the button.
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store, g = s.water, goal = s.waterGoal;
        final days = s.lastDays(7);
        final full = g >= goal;
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
                        sub: '${niceDate(DateTime.now())} · each glass is 250 ml',
                        menu: [
                          ('Undo last glass', g > 0 ? () => s.setWater(g - 1) : null),
                          ('Reset today', g > 0 ? () => s.setWater(0) : null),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _Hero(big: litres(g), small: 'of ${litres(goal)} L'),
                      const SizedBox(height: 24),
                      GridView.count(
                        clipBehavior: Clip.none, // droplets fly above the glasses
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 10,
                        childAspectRatio: .6,
                        children: [
                          for (var i = 0; i < goal; i++)
                            Semantics(
                              button: true,
                              label: 'Glass ${i + 1}${i < g ? ', drunk' : ''}',
                              child: Semantics(
                                button: true,
                                label: 'Glass ${i + 1}, ${i < g ? 'drunk' : 'not yet'}',
                                child: GestureDetector(
                                  // tap glass n to set the count to n; tap the last full glass to empty it
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    s.setWater(g == i + 1 ? i : i + 1);
                                  },
                                  child: WaterGlass(full: i < g, next: i == g, wave: g >= goal, index: i),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('This week', style: t.meta()),
                      const SizedBox(height: 10),
                      WeekBars(
                        days: days,
                        values: [for (final d in days) d == s.today ? g : s.waterHistory[d] ?? 0],
                        target: goal,
                        max: goal + 3, // headroom so the goal line shows
                      ),
                      const SizedBox(height: 24),
                      const Tip(Icons.fitness_center_rounded, 'Gym day or hot day: drink more'),
                      const Tip(Icons.medical_services_outlined, 'A doctor limits your fluids? Follow that'),
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
    if (!mounted) return;
    setState(() {
      _week = w;
      if (w != null) _steps = w[s.today];
      _loading = false;
    });
  }

  Future<void> _enter() async {
    final c = TextEditingController(text: s.manualSteps?.toString() ?? '');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Steps today'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'From your phone\'s step counter'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: const Text('Save'))],
      ),
    );
    if (v != null) s.setManualSteps(v);
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

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        _Header(title: 'Walk', sub: 'Week $week · target ${thousands(target)} steps'),
                        const SizedBox(height: 24),
                        _Hero(big: thousands(walked), small: 'steps'),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: CustomPaint(painter: _LanePainter(walked, target, t), size: Size.infinite),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            style: t.sec(),
                            children: togo == 0
                                ? [
                                    TextSpan(
                                      text: 'Target done. ',
                                      style: t.sec(t.ink).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const TextSpan(text: 'Anything more is a bonus.'),
                                  ]
                                : [
                                    TextSpan(
                                      text: '${thousands(togo)} to go, ',
                                      style: t.sec(t.ink).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: 'about ${(togo / 105).ceil()} minutes of brisk walking.'),
                                  ],
                          ),
                        ),
                        Text('${km.toStringAsFixed(1)} km so far · ≈ ${kcal.round()} kcal', style: t.sec()),
                        const SizedBox(height: 20),
                        for (final (label, steps, sub, active) in [
                          ('Weeks 1–2', '7,000', 'about 5 km a day', s.lap <= 14),
                          ('Weeks 3–4', '8,000', 'about 6 km a day', s.lap > 14 && s.lap <= 28),
                          ('Weeks 5–12', '10,000', '9,000–10,000, about 7 km', s.lap > 28),
                        ])
                          _Rung(label: active ? '$label · now' : label, steps: steps, sub: sub, active: active),
                        const SizedBox(height: 24),
                        Text('This week', style: t.meta()),
                        const SizedBox(height: 10),
                        WeekBars(
                          days: days,
                          values: [for (final d in days) d == s.today ? walked : _week?[d] ?? s.stepsHistory[d] ?? 0],
                          target: target,
                          max: 12000,
                        ),
                        const SizedBox(height: 20),
                        const Tip(Icons.wb_sunny_outlined, '15–20 min after lunch'),
                        const Tip(Icons.bedtime_outlined, '15–20 min after dinner'),
                        const Tip(Icons.directions_run_rounded, 'Treadmill steps count'),
                        const Tip(Icons.healing_outlined, 'Knees or feet hurt? Hold the step count a week'),
                        const SizedBox(height: 12),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.sub, this.menu = const []});
  final String title, sub;
  final List<(String, VoidCallback?)> menu;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return PageHeader(
      title,
      sub: sub,
      actions: [
        if (menu.isNotEmpty)
          PopupMenuButton<int>(
            icon: Icon(Icons.more_horiz, color: t.ink),
            onSelected: (i) => menu[i].$2?.call(),
            itemBuilder: (_) => [
              for (final (i, (label, f)) in menu.indexed)
                PopupMenuItem(value: i, enabled: f != null, child: Text(label)),
            ],
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.big, required this.small});
  final String big, small;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(big, style: t.x(68, weight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 10),
        Text(small, style: t.x(24)),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.label, required this.steps, required this.sub, required this.active});
  final String label, steps, sub;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(steps, style: t.x(22, color: active ? t.accent : t.ink2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: t.body(color: active ? t.ink : t.ink2)),
                Text(sub, style: t.meta()),
              ],
            ),
          ),
        ],
      ),
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

/// A straight lane from 0 to the day's target, a mark every 1,000 steps, the runner at today's steps.
class _LanePainter extends CustomPainter {
  _LanePainter(this.steps, this.target, this.t);
  final int steps, target;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = h / 2;
    final lane = Paint()
      ..color = t.lane
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, 2), Offset(w, 2), lane);
    canvas.drawLine(Offset(0, h - 2), Offset(w, h - 2), lane);
    double x(num v) => 12 + (v / target).clamp(0, 1) * (w - 24);
    for (var k = 1000; k <= target; k += 1000) {
      canvas.drawLine(
        Offset(x(k), 6),
        Offset(x(k), k % 4000 == 0 || k == target ? h - 6 : 16),
        Paint()
          ..color = k <= steps ? t.ink : t.faint
          ..strokeWidth = 2,
      );
    }
    canvas.drawLine(
      Offset(x(0), mid),
      Offset(x(steps), mid),
      Paint()
        ..color = t.ink
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(steps), mid), 11.75, Paint()..color = t.ground);
    canvas.drawCircle(Offset(x(steps), mid), 10, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(_LanePainter o) => o.steps != steps || o.target != target || o.t != t;
}
