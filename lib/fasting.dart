import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'plan.dart';
import 'store.dart';
import 'targets.dart' show groundChip;
import 'theme.dart';
import 'today.dart' show thousands;
import 'visuals.dart';

String _hh(int h) => '${(h % 24).toString().padLeft(2, '0')}:00';
String _dur(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

/// Where today stands: fasting (how long, until when) or inside the eating window.
({bool eating, Duration elapsed, Duration left, double frac}) fastNow(Store s, DateTime now) {
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

/// One row on Today while fasting is on: the fast's progress, or the eating window's.
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
                Icon(f.eating ? Icons.restaurant_rounded : Icons.hourglass_bottom_rounded, size: 18, color: t.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.eating ? 'Eating window · ${_dur(f.left)} left' : 'Fasting ${_dur(f.elapsed)} of ${s.fastHours}h',
                    style: t.body(),
                  ),
                ),
                Text(f.eating ? 'closes ${_hh(s.eatEnd)}' : 'eat at ${_hh(s.eatStart)}', style: t.sec()),
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

/// Drawer → Fasting: pick a plan, move the window, see which meals fall inside it.
class FastingScreen extends StatelessWidget {
  const FastingScreen({super.key, required this.store});
  final Store store;

  static const plans = ['14:10', '16:8', '18:6'];

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        final on = s.fastPlan != null;
        final day = meals.fold(0, (a, m) => a + s.mealKcal(m) * (s.fasted(m) ? 0 : 1));
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Fasting', sub: 'Eat inside a window, fast the rest'),
                const SizedBox(height: 20),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    groundChip(context, 'Off', !on, () => s.setFast(null)),
                    for (final p in plans) groundChip(context, p, s.fastPlan == p, () => s.setFast(p)),
                  ],
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1.6,
                  child: Semantics(
                    label: on
                        ? 'Eating window ${_hh(s.eatStart)} to ${_hh(s.eatEnd)}, ${s.fastHours} hour fast'
                        : 'Fasting off',
                    excludeSemantics: true,
                    child: CustomPaint(
                      painter: _Clock(t, on ? s.eatStart : null, on ? s.eatEnd : null, DateTime.now()),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(on ? '${s.fastHours}h' : 'Off', style: t.x(44, weight: FontWeight.w900)),
                            Text(on ? 'fast' : 'eat on the plan\'s times', style: t.meta()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (on) ...[
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  const Tip(Icons.call_split_rounded, 'Meals inside the window get bigger, so the day stays the same'),
                ],
                const Tip(Icons.local_cafe_outlined, 'While fasting: water, black tea, black coffee'),
                const Tip(Icons.medical_services_outlined, 'Diabetic or on medicine? Ask your doctor first'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A 24-hour dial: the eating window as a thick yellow arc, a dot for now. Midnight at the top.
class _Clock extends CustomPainter {
  _Clock(this.t, this.start, this.end, this.now);
  final Daur t;
  final int? start, end;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    double ang(double h) => -math.pi / 2 + h / 24 * 2 * math.pi;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = t.lane.withValues(alpha: .4);
    canvas.drawCircle(c, r, ring);
    if (start != null && end != null) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        ang(start!.toDouble()),
        (end! - start!) / 24 * 2 * math.pi,
        false,
        ring
          ..color = t.accent
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final (h, label) in const [(0, '00'), (6, '06'), (12, '12'), (18, '18')]) {
      final a = ang(h.toDouble());
      final tp = TextPainter(
        text: TextSpan(text: label, style: t.meta()),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 26);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    final a = ang(now.hour + now.minute / 60);
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(p, 9, Paint()..color = t.ink);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.ground,
    );
  }

  @override
  bool shouldRepaint(_Clock o) => o.start != start || o.end != end || o.now.minute != now.minute || o.t != t;
}
