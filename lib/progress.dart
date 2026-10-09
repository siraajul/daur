import 'package:flutter/material.dart';

import 'badges.dart';
import 'motion.dart';
import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'visuals.dart';
import 'streak.dart' show RecapScreen;
import 'today.dart' show MenuButton, niceDate, thousands, undoToast;

/// Progress: how far down (and the chart that shows it), whether the pace is right, how this week
/// went, the 84 days, and the month targets. Weigh-in history sits behind one row.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = store;
    final now = s.trendKg ?? s.latestKg;
    final thisWeek = s.avgKg(0, 7), lastWeek = s.avgKg(7, 14);
    final change = thisWeek != null && lastWeek != null ? thisWeek - lastWeek : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              const MenuButton(),
              Expanded(child: Text('Progress', style: t.title())),
              IconButton.filledTonal(
                onPressed: () => logWeight(context, s),
                tooltip: 'Log today\'s weight',
                icon: Icon(Icons.add, color: t.ink),
                style: IconButton.styleFrom(backgroundColor: t.ink.withValues(alpha: .18)),
              ),
            ],
          ),
          Text('Day ${s.lap} of $laps', style: t.sec()),
          const SizedBox(height: 20),
          // the hero: kilos since day 1, on the weekly average when there is one
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Odometer(
                text: now == null ? s.startKg.toStringAsFixed(1) : _signed(now - s.startKg),
                style: t.x(64, weight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Text('kg', style: t.x(26)),
            ],
          ),
          Text(
            now == null
                ? 'Starting weight · weigh in to start the chart'
                : '${now.toStringAsFixed(1)} kg now${s.trendKg != null ? ' · 7-day average' : ''} · started ${s.startKg.toStringAsFixed(1)}',
            style: t.sec(),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: now == null
                ? 'Weight chart, no weigh-ins yet'
                : 'Weight chart: ${now.toStringAsFixed(1)} kilos now, started at ${s.startKg.toStringAsFixed(1)}',
            excludeSemantics: true,
            child: SizedBox(
              height: 200,
              child: CustomPaint(painter: _WeightChart(t, s), size: Size.infinite),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            children: [
              _legend(t, Container(width: 14, height: 3, color: t.ink), '7-day average'),
              _legend(t, CircleAvatar(radius: 3, backgroundColor: t.ink2), 'weigh-in'),
              _legend(t, Container(width: 10, height: 10, color: t.accent.withValues(alpha: .5)), 'month target'),
            ],
          ),
          const SizedBox(height: 24),
          // this week's change against the goal's pace (Lose 0.6–0.9 down, Gain 0.2–0.4 up, Keep steady)
          PaceGauge(change: change, goal: s.goal, kcal: s.kcalGoal, stalled: s.stalled),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Text('This week', style: t.meta())),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecapScreen(store: s))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Recap ›', style: t.sec(t.ink)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _weekTiles(t, s),
          const SizedBox(height: 28),
          _strength(t, s),
          const SizedBox(height: 28),
          Text('Month targets', style: t.meta()),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, (name, range, day)) in s.targets.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _target(t, s, name, range, day)),
              ],
            ],
          ),
          const SizedBox(height: 28),
          Text('$laps days', style: t.meta()),
          const SizedBox(height: 8),
          _Season(store: s),
          const SizedBox(height: 16),
          if (s.weights.isNotEmpty)
            InkWell(
              onTap: () => _history(context, s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.rule, width: .5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monitor_weight_outlined, color: t.ink),
                    const SizedBox(width: 12),
                    Expanded(child: Text('All weigh-ins', style: t.body())),
                    Text('${s.weights.length}', style: t.sec()),
                    Icon(Icons.chevron_right_rounded, color: t.ink2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _signed(double v) =>
      '${v > 0
          ? '+'
          : v < 0
          ? '−'
          : ''}${v.abs().toStringAsFixed(1)}';

  Widget _legend(Daur t, Widget mark, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: 6),
      Text(label, style: t.meta()),
    ],
  );

  /// The last 7 finished days as four tiles: calories, protein, gym, sleep. Each with a bar.
  Widget _weekTiles(Daur t, Store s) {
    final f = s.weekFood;
    final (lo, hi) = s.proteinRange;
    final nights = s.lastDays(7).map((d) => s.sleepHistory[d]).whereType<int>().toList();
    final sleep = nights.isEmpty ? null : nights.reduce((a, b) => a + b) ~/ nights.length;
    // (icon, label, value, line, bar 0..1). A full bar is yellow (good), except calories: over isn't good
    final tiles = <(IconData, String, String, String, double)>[
      (
        Icons.local_fire_department_rounded,
        'Calories',
        f.days == 0 ? '—' : thousands(f.kcal),
        f.days == 0
            ? 'no full days yet'
            : f.kcal > s.kcalGoal
            ? 'avg · ${thousands(f.kcal - s.kcalGoal)} over goal'
            : 'avg · goal ${thousands(s.kcalGoal)}',
        f.days == 0 ? 0 : f.kcal / s.kcalGoal,
      ),
      (
        Icons.egg_alt_outlined,
        'Protein',
        f.days == 0 ? '—' : '${f.protein} g',
        'avg · goal $lo–$hi g',
        f.days == 0 ? 0 : f.protein / lo,
      ),
      (Icons.fitness_center_rounded, 'Gym', '${s.gymThisWeek}', 'sessions · aim 3–5', s.gymThisWeek / 3),
      (
        Icons.bedtime_outlined,
        'Sleep',
        sleep == null ? '—' : '${sleep ~/ 60}h ${(sleep % 60).toString().padLeft(2, '0')}',
        sleep == null ? 'not tracked yet' : 'avg · goal 7–8 h',
        sleep == null ? 0 : sleep / 420,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        for (final (icon, label, value, sub, frac) in tiles)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: t.ink),
                    const SizedBox(width: 6),
                    Text(label, style: t.sec(t.ink)),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: t.x(24)),
                ),
                Text(sub, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac.clamp(0, 1).toDouble(),
                    minHeight: 6,
                    color: frac >= 1 && label != 'Calories' ? t.accent : t.ink,
                    backgroundColor: t.lane.withValues(alpha: .35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String amount(double v, String unit) => switch (unit) {
    'kg' => '${v == v.roundToDouble() ? v.toInt() : v} kg',
    's' => v >= 60 ? '${v ~/ 60}:${(v.toInt() % 60).toString().padLeft(2, '0')}' : '${v.toInt()} s',
    _ => '${v.toInt()} reps',
  };

  /// Each exercise since its first session: a trend line, start → now, the change.
  Widget _strength(Daur t, Store s) {
    final rows = s.strength;
    final up = rows.where((r) => r.now > r.start).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Strength', style: t.meta()),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          const Tip(Icons.fitness_center_rounded, 'Log sets on two gym days to see each lift grow')
        else ...[
          _overall(t, s),
          const SizedBox(height: 12),
          Text('Stronger in $up of ${rows.length} exercises', style: t.body()),
          const SizedBox(height: 8),
          for (final r in rows)
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.rule, width: .5)),
              ),
              child: Semantics(
                label: '${r.ex}: from ${amount(r.start, r.unit)} to ${amount(r.now, r.unit)}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(
                      switch (r.unit) {
                        's' => Icons.timer_outlined,
                        'reps' => Icons.accessibility_new_rounded,
                        _ => Icons.fitness_center_rounded,
                      },
                      size: 20,
                      color: t.ink2,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.ex,
                            style: t.body(weight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('${amount(r.start, r.unit)} → ${amount(r.now, r.unit)}', style: t.sec()),
                        ],
                      ),
                    ),
                    SizedBox(width: 56, height: 26, child: CustomPaint(painter: _Spark(t, r.series))),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          r.start == 0
                              ? '—'
                              : '${r.now >= r.start ? '+' : '−'}${((r.now - r.start).abs() / r.start * 100).round()}%',
                          maxLines: 1,
                          style: t.x(16, color: r.now > r.start ? t.accent : t.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Overall strength: one ring per body area (full = +50%), the overall gain in the middle.
  Widget _overall(Daur t, Store s) {
    final sum = s.strengthSummary;
    String pct(double g) => '${g >= 0 ? '+' : '−'}${(g.abs() * 100).round()}%';
    const order = ['Push', 'Pull', 'Legs', 'Core'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Semantics(
            label: 'Overall strength ${sum.overall == null ? 'not measured yet' : pct(sum.overall!)}',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 164,
              child: CustomPaint(
                painter: _Rings(t, [for (final a in order) sum.areas[a]]),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sum.overall == null ? '—' : pct(sum.overall!), style: t.x(20, weight: FontWeight.w900)),
                      Text('overall', style: t.meta()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall strength', style: t.body()),
                const SizedBox(height: 8),
                for (final (i, a) in order.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        // the ring's own mark: outermost ring first, getting lighter inward
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: _Rings.shade(t, i), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a, style: t.sec(t.ink))),
                        Text(sum.areas[a] == null ? '—' : pct(sum.areas[a]!), style: t.x(14)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A month target as a chip: yellow once the weekly average is inside or under it.
  Widget _target(Daur t, Store s, String name, String range, int day) {
    final hi = double.parse(range.split('–').last);
    final hit = s.trendKg != null && s.trendKg! <= hi;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: hit ? t.accent : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hit ? t.accent : t.lane, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: t.meta(hit ? t.onAccent : null))),
              Icon(hit ? Icons.check_circle_rounded : Icons.flag_outlined, size: 16, color: hit ? t.onAccent : t.ink2),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(range, style: t.x(16, color: hit ? t.onAccent : t.ink)),
          ),
          Text('day $day', style: t.meta(hit ? t.onAccent : null)),
        ],
      ),
    );
  }

  /// Every weigh-in, newest first, each with a delete (undoable).
  Future<void> _history(BuildContext context, Store s) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: s,
      builder: (ctx, _) {
        final t = Daur.of(ctx);
        final ws = s.weights.reversed.toList();
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 24),
            children: [
              Text('Weigh-ins', style: t.title(t.sheetInk)),
              const SizedBox(height: 8),
              for (final (i, w) in ws.indexed)
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.sheetRule, width: .5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          niceDate(DateTime.parse(w.day)),
                          style: t.body(color: t.sheetInk, weight: FontWeight.w400),
                        ),
                      ),
                      if (i + 1 < ws.length) Text(_signed(w.kg - ws[i + 1].kg), style: t.sec(t.sheetInk2)),
                      const SizedBox(width: 12),
                      Text('${w.kg.toStringAsFixed(1)} kg', style: t.x(16, color: t.sheetInk)),
                      IconButton(
                        tooltip: 'Delete this weigh-in',
                        icon: Icon(Icons.close_rounded, size: 20, color: t.sheetInk2),
                        onPressed: () {
                          final snap = s.snapshot();
                          s.removeWeight(w);
                          undoToast(context, 'Weigh-in deleted', () => s.restore(snap));
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  /// Also opened from the weigh-in reminder and the welcome-back sheet.
  static Future<void> logWeight(BuildContext context, Store store) async {
    final v = await askNumber(context, 'Weight this morning', suffix: 'kg', decimal: true);
    if (v != null && v > 20 && v < 300) {
      store.logWeight(v);
      if (context.mounted) await checkBadges(context, store); // first weigh-in, kg milestones, month targets
    }
  }
}

/// 84 laps as small ovals, each drawn as far as that day was run (meals eaten / 4).
class _Season extends StatelessWidget {
  const _Season({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final start = DateTime.parse(store.startDay);
    return GridView.count(
      crossAxisCount: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        // column = week, row = weekday, like the design
        for (var i = 0; i < laps; i++)
          () {
            final day = (i % 12) * 7 + i ~/ 12; // row-major grid → week columns
            final key = dayKey(start.add(Duration(days: day)));
            final isToday = key == store.today;
            return CustomPaint(painter: _Oval(t, (isToday ? store.legsDone : store.lapHistory[key] ?? 0) / 4, isToday));
          }(),
      ],
    );
  }
}

class _Oval extends CustomPainter {
  _Oval(this.t, this.frac, this.today);
  final Daur t;
  final double frac;
  final bool today;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: 24, height: 13),
      const Radius.circular(6.5),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = t.faint,
    );
    if (frac <= 0) return;
    final m = (Path()..addRRect(r)).computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * frac),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = today ? t.accent : t.ink,
    );
  }

  @override
  bool shouldRepaint(_Oval o) => o.frac != frac || o.t != t || o.today != today;
}

/// Weight over the 84 days: weigh-ins as dots, the 7-day average as the line, month targets as
/// yellow bands at their day, today as a faint line. Day 1 on the left.
class _WeightChart extends CustomPainter {
  _WeightChart(this.t, this.s);
  final Daur t;
  final Store s;

  @override
  void paint(Canvas canvas, Size size) {
    final start = DateTime.parse(s.startDay);
    int dayOf(String key) => DateTime.parse(key).difference(start).inDays;
    final pts = [for (final w in s.weights) (dayOf(w.day), w.kg)].where((p) => p.$1 >= 0).toList();
    final targets = [
      for (final (_, r, d) in s.targets) (d, double.parse(r.split('–').first), double.parse(r.split('–').last)),
    ];
    final todayX = dayOf(s.today);
    final days = [laps, todayX + 1, ...pts.map((p) => p.$1 + 1)].reduce((a, b) => a > b ? a : b);
    final ks = [s.startKg, ...pts.map((p) => p.$2), ...targets.map((x) => x.$2), ...targets.map((x) => x.$3)];
    final lo = ks.reduce((a, b) => a < b ? a : b) - 1, hi = ks.reduce((a, b) => a > b ? a : b) + 1;
    const left = 34.0, bottom = 18.0;
    final w = size.width - left, h = size.height - bottom;
    double x(num d) => left + d / (days - 1) * w;
    double y(double kg) => (hi - kg) / (hi - lo) * h;
    TextPainter label(String text) => TextPainter(
      text: TextSpan(text: text, style: t.meta()),
      textDirection: TextDirection.ltr,
    )..layout();

    // grid: three kg lines with labels
    final grid = Paint()
      ..color = t.rule
      ..strokeWidth = 1;
    for (final kg in [hi - 1, (hi + lo) / 2, lo + 1]) {
      canvas.drawLine(Offset(left, y(kg)), Offset(size.width, y(kg)), grid);
      final l = label(kg.toStringAsFixed(0));
      l.paint(canvas, Offset(0, y(kg) - l.height / 2));
    }
    for (final (d, text) in [(0, 'Day 1'), (days - 1, 'Day $days')]) {
      final l = label(text);
      l.paint(canvas, Offset((x(d) - (d == 0 ? 0 : l.width)).clamp(left, size.width - l.width), h + 4));
    }

    // month targets: a yellow band at the target day
    for (final (d, a, b) in targets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x(d) - 5, y(b), x(d) + 5, y(a)), const Radius.circular(4)),
        Paint()..color = t.accent.withValues(alpha: .5),
      );
    }
    // today
    canvas.drawLine(
      Offset(x(todayX), 0),
      Offset(x(todayX), h),
      Paint()
        ..color = t.lane
        ..strokeWidth = 1,
    );

    if (pts.isEmpty) return;
    // weigh-ins
    for (final (d, kg) in pts) {
      canvas.drawCircle(Offset(x(d), y(kg)), 2.6, Paint()..color = t.ink2);
    }
    // 7-day average at each weigh-in day
    final avg = <Offset>[
      for (final (d, _) in pts)
        () {
          final win = pts.where((p) => p.$1 <= d && p.$1 > d - 7).map((p) => p.$2).toList();
          return Offset(x(d), y(win.reduce((a, b) => a + b) / win.length));
        }(),
    ];
    if (avg.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(avg, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = t.ink,
      );
    }
    canvas.drawCircle(avg.last, 6, Paint()..color = t.accent);
    canvas.drawCircle(
      avg.last,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = t.ground,
    );
  }

  @override
  bool shouldRepaint(_WeightChart o) => true; // cheap; the store changes rarely here
}

/// A tiny trend line of an exercise's best set per session; the last point marked.
class _Spark extends CustomPainter {
  _Spark(this.t, this.v);
  final Daur t;
  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final lo = v.reduce((a, b) => a < b ? a : b), hi = v.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final pts = [
      for (final (i, x) in v.indexed)
        Offset(i / (v.length - 1) * size.width, size.height - 3 - (x - lo) / span * (size.height - 6)),
    ];
    canvas.drawPath(
      Path()..addPolygon(pts, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = t.ink,
    );
    canvas.drawCircle(pts.last, 3.5, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(_Spark o) => o.v != v || o.t != t;
}

/// Concentric rings, outermost first: each fills with its area's gain, a full ring at +50%.
/// An area without two sessions yet shows only its track; a loss shows a short faint arc.
class _Rings extends CustomPainter {
  _Rings(this.t, this.gains);
  final Daur t;
  final List<double?> gains;

  /// Yellow outside (the headline area), then ink getting lighter inward: one accent, one role.
  static Color shade(Daur t, int i) => i == 0 ? t.accent : t.ink.withValues(alpha: const [1.0, 1.0, .82, .64][i]);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0, gap = 3.0; // leaves the middle ~76 px across for the overall number
    final c = size.center(Offset.zero);
    for (final (i, g) in gains.indexed) {
      final r = size.shortestSide / 2 - stroke / 2 - i * (stroke + gap);
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = t.ink.withValues(alpha: .12),
      );
      if (g == null) continue;
      final frac = (g / .5).clamp(0.03, 1.0); // a sliver even for a loss, so the ring reads as measured
      canvas.drawArc(
        rect,
        -1.5708,
        frac * 6.2832,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = g < 0 ? t.ink2.withValues(alpha: .5) : shade(t, i),
      );
    }
  }

  @override
  bool shouldRepaint(_Rings o) => o.gains != gains || o.t != t;
}
