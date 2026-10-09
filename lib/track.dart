import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'theme.dart';

/// The running track seen from above (design/DIRECTION.md, "Richness").
/// [meters] is how far round today's 400 m lap the runner is. The optional motion fields are
/// driven by [Track]; static uses (rest timer, treadmill, widgets) leave them at rest.
class TrackPainter extends CustomPainter {
  TrackPainter(
    this.meters,
    this.t, {
    this.lean = 0,
    this.trail = 0,
    this.ripple = 0,
    this.rippleAt = -1,
    this.finale = 0,
  });
  final double meters;
  final Daur t;
  final double lean; // runner stretch from speed, 0..1
  final double trail; // how many metres of chalk trail behind the runner
  final double ripple; // 0..1 landing ring at [rippleAt]
  final double rippleAt;
  final double finale; // 0..1 lap-complete sequence

  static const w = 402.0, h = 250.0;
  static const startLine = Offset(267, 215);

  /// The running lane, counter-clockwise from the start line on the home straight.
  static Path lane() {
    const r = 90.0;
    return Path()
      ..moveTo(267, 215)
      ..arcToPoint(const Offset(267, 35), radius: const Radius.circular(r), clockwise: false)
      ..lineTo(135, 35)
      ..arcToPoint(const Offset(135, 215), radius: const Radius.circular(r), clockwise: false)
      ..close();
  }

  static final PathMetric _metric = lane().computeMetrics().first;

  /// Where on the track (design space) [m] metres falls.
  static Tangent at(double m) => _metric.getTangentForOffset(_metric.length * (m % 400) / 400)!;

  /// Design-space → widget-space transform for a given widget size.
  static (double, Offset) fit(Size size) {
    final s = math.min(size.width / w, size.height / h);
    return (s, Offset((size.width - w * s) / 2, (size.height - h * s) / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (s, o) = fit(size);
    canvas.translate(o.dx, o.dy);
    canvas.scale(s);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = t.lane;
    for (final (x, y, w, h) in const [
      (24.0, 14.0, 354.0, 222.0),
      (38.0, 28.0, 326.0, 194.0),
      (52.0, 42.0, 298.0, 166.0),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(h / 2)), line);
    }
    final infield = RRect.fromRectAndRadius(const Rect.fromLTWH(66, 56, 270, 138), const Radius.circular(69));
    canvas.drawRRect(infield, Paint()..color = t.infield);

    // finale, part 2: the infield floods with runner yellow from the centre, then drains
    if (finale > 0) {
      final flood = math.sin(math.pi * ((finale - .25) / .75).clamp(0, 1));
      if (flood > 0) {
        canvas.save();
        canvas.clipRRect(infield);
        canvas.drawCircle(
          const Offset(201, 125),
          150 * Curves.easeOut.transform(flood.clamp(0, 1)),
          Paint()..color = t.accent.withValues(alpha: .26 * flood),
        );
        canvas.restore();
      }
    }
    canvas.drawRRect(infield, line);

    // the finish tape across the start line; in the finale it snaps and the halves fall away
    _tape(canvas);

    final metric = _metric;
    final m = meters.clamp(0, 400).toDouble();
    if (m > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * m / 400),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = t.ink,
      );
    }

    // finale, part 1: a bright pulse sweeps the whole lane, a lap of light
    if (finale > 0 && finale < .7) {
      final sweep = (finale / .55).clamp(0.0, 1.0);
      final head = metric.length * Curves.easeInOutCubic.transform(sweep);
      final tail = math.max(0.0, head - metric.length * .35);
      canvas.drawPath(
        metric.extractPath(tail, head),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = t.accent.withValues(alpha: (1 - finale / .7).clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // chalk trail: dust left on the lane behind a moving runner
    if (trail > 1) {
      for (var i = 1; i <= 7; i++) {
        final back = m - trail * i / 7;
        if (back <= 0) break;
        final p = at(back).position;
        canvas.drawCircle(p, 5.5 - i * .55, Paint()..color = t.ink.withValues(alpha: .5 * (1 - i / 8)));
      }
    }

    for (final d in const [100, 200, 300]) {
      final p = at(d.toDouble()).position;
      canvas.drawCircle(p, 5, Paint()..color = d <= m ? t.ink : t.ground);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = t.ink,
      );
    }

    // landing ripple at the mark the runner just reached
    if (ripple > 0 && ripple < 1 && rippleAt >= 0) {
      final p = at(rippleAt).position;
      canvas.drawCircle(
        p,
        10 + 34 * Curves.easeOut.transform(ripple),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ripple)
          ..color = t.ink.withValues(alpha: 1 - ripple),
      );
    }

    // the runner: leans (stretches along the lane) with speed, squashes a touch on landing
    final tan = at(m);
    canvas.save();
    canvas.translate(tan.position.dx, tan.position.dy);
    canvas.rotate(-tan.angle);
    final stretch = 1 + .55 * lean.clamp(0, 1);
    final squash = 1 / math.sqrt(stretch);
    final landing = ripple > 0 && ripple < .35 ? 1 - .18 * math.sin(ripple / .35 * math.pi) : 1.0;
    canvas.scale(stretch * (2 - landing), squash * landing);
    canvas.drawCircle(Offset.zero, 11.75, Paint()..color = t.ground);
    canvas.drawCircle(Offset.zero, 10, Paint()..color = t.accent);
    canvas.restore();
  }

  void _tape(Canvas canvas) {
    const a = Offset(267, 194), b = Offset(267, 236);
    final ink = Paint()
      ..color = t.ink
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (finale <= .08) {
      canvas.drawLine(a, b, ink);
      return;
    }
    // two halves fly apart and fall (ballistic, with spin)
    final k = ((finale - .08) / .6).clamp(0.0, 1.0);
    final fade = (1 - k).clamp(0.0, 1.0);
    for (final (from, dir) in [(a, -1.0), (b, 1.0)]) {
      final half = (b - a) / 2;
      final mid = from + half * (dir < 0 ? 1 : -1) * .5;
      final dx = 70 * k * (dir < 0 ? -.6 : .9), dy = dir * 30 * k + 160 * k * k;
      canvas.save();
      canvas.translate(mid.dx + dx, mid.dy + dy);
      canvas.rotate(dir * 2.4 * k);
      canvas.drawLine(Offset(0, -half.dy / 2), Offset(0, half.dy / 2), ink..color = t.ink.withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(TrackPainter old) =>
      old.meters != meters ||
      old.t != t ||
      old.lean != lean ||
      old.trail != trail ||
      old.ripple != ripple ||
      old.finale != finale;
}

/// The track with the metres in the infield. Changing [meters] runs the leg (the signature):
/// the runner springs along the lane leaving chalk, lands with a ripple and a haptic, and the
/// metres roll like a scoreboard. Reaching 400 closes the lap: the lane lights up end to end,
/// the infield floods yellow, the tape snaps and chalk kicks off the start line.
class Track extends StatefulWidget {
  const Track({super.key, required this.meters, required this.caption, this.impact, this.count, this.of = 4});
  final int meters;
  final int? count; // meals to show in the middle (default meters / 100); fasting shows fewer
  final int of;
  final String caption;
  final ImpactController? impact; // nudged on a heavy landing

  @override
  State<Track> createState() => _TrackState();
}

class _TrackState extends State<Track> with TickerProviderStateMixin {
  late final _run = AnimationController.unbounded(vsync: this, value: widget.meters.toDouble());
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final _finale = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  final _chalk = ChalkController();
  double _target = 0, _rippleAt = -1;
  bool _landed = true;

  @override
  void initState() {
    super.initState();
    _target = widget.meters.toDouble();
    _run.addListener(_watchLanding);
  }

  @override
  void didUpdateWidget(Track old) {
    super.didUpdateWidget(old);
    if (old.meters == widget.meters) return;
    _target = widget.meters.toDouble();
    if (reduceMotion(context)) {
      _run.value = _target;
      return;
    }
    _landed = false;
    if (widget.meters > old.meters) HapticFeedback.selectionClick();
    // the sprint: a soft spring with a little overshoot (a runner leaning past the mark)
    _run.animateWith(SpringSimulation(Springs.runner, _run.value, _target, _run.velocity));
  }

  void _watchLanding() {
    if (_landed) return;
    final arrived = (_run.value - _target).abs() < 4 && _run.velocity.abs() < 120;
    if (!arrived) return;
    _landed = true;
    _rippleAt = _target;
    _ripple.forward(from: 0);
    final lapDone = _target >= 400;
    if (lapDone) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
      widget.impact?.hit(1.2);
      _finale.forward(from: 0);
      _kickFromStart();
    } else if (_target > 0) {
      HapticFeedback.mediumImpact();
      widget.impact?.hit(.45);
    }
  }

  void _kickFromStart() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final (s, o) = TrackPainter.fit(box.size);
    final start = o + TrackPainter.startLine * s;
    _chalk.kick(start, count: 34, angle: -math.pi / 2, spread: 2.4, power: 1.1);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _chalk.kick(start, count: 22, angle: -math.pi / 2 - .5, spread: 1.4, power: .8);
    });
  }

  @override
  void dispose() {
    _run.dispose();
    _ripple.dispose();
    _finale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Semantics(
      label:
          '${widget.count ?? widget.meters.clamp(0, 400) ~/ 100} of ${widget.of} meals logged. ${widget.caption.replaceAll('\n', '. ')}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: TrackPainter.w / TrackPainter.h,
        child: Chalk(
          controller: _chalk,
          child: AnimatedBuilder(
            animation: Listenable.merge([_run, _ripple, _finale]),
            builder: (context, _) {
              final v = _run.velocity.abs();
              final m = _run.value.clamp(0, 400).toDouble();
              return CustomPaint(
                painter: TrackPainter(
                  m,
                  t,
                  lean: (v / 900).clamp(0, 1),
                  trail: (v / 14).clamp(0, 60),
                  ripple: _ripple.value,
                  rippleAt: _rippleAt,
                  finale: _finale.value,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // plain numbers: meals logged of 4 (the runner shows the same thing)
                          Odometer(
                            text: '${widget.count ?? widget.meters.clamp(0, 400) ~/ 100}',
                            style: t.x(52, weight: FontWeight.w900),
                          ),
                          Text(' of ${widget.of} meals', style: t.x(18)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Text(
                          widget.caption,
                          key: ValueKey(widget.caption),
                          textAlign: TextAlign.center,
                          style: t.meta(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
