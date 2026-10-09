import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';

/// Picks up where the system splash leaves off. Android 12+ only lets the OS splash show a still
/// icon, so the first Flutter frame redraws that exact icon at the same size and spot. Then the
/// runner sprints to the line, breaks the tape, and the infield opens like a window onto today.
/// Geometry is design/app-icon.html's "fg" svg (viewBox -86 -86 516 516).
class SplashIntro extends StatefulWidget {
  const SplashIntro({super.key, required this.child});
  final Widget child;
  @override
  State<SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<SplashIntro> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  bool _done = false, _buzzed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_buzzed && _c.value >= _IntroPainter.finish) {
        _buzzed = true;
        HapticFeedback.lightImpact();
      }
    });
    // run once the first frame is really on screen, after a beat on the still icon
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _c.forward().whenComplete(() => setState(() => _done = true));
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) _done = true; // the OS splash was enough
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final reveal = _IntroPainter.reveal(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            // today settles back as the window opens over it
            Transform.scale(scale: 1 + .08 * (1 - Curves.easeOutCubic.transform(reveal)), child: child),
            IgnorePointer(
              child: CustomPaint(
                painter: _IntroPainter(_c.value, dark ? const Color(0xFF3D140C) : const Color(0xFFAD3B26)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IntroPainter extends CustomPainter {
  _IntroPainter(this.t, this.ground);
  final double t; // 0..1 over the whole intro
  final Color ground;

  static const ink = Color(0xFFFFF8F3), accent = Color(0xFFFFD23F), ring = Color(0xFFAD3B26);
  static const hold = .06, finish = .52; // sprint runs hold..finish, then the window opens

  /// The OS draws the splash icon in a 288 dp box (Android 12+); older Android, iOS and web
  /// draw the 1024 px image as 4x, so 256.
  static double get box => defaultTargetPlatform == TargetPlatform.android ? 288 : 256;

  static double reveal(double t) => ((t - finish) / (1 - finish)).clamp(0.0, 1.0);

  // the middle of the lane, run the same way as Today's track: from the finish line, right,
  // up the far bend, back along the top, down the near bend
  static final PathMetric _lane =
      (Path()
            ..moveTo(214, 241)
            ..lineTo(218, 241)
            ..arcToPoint(const Offset(218, 103), radius: const Radius.circular(69), clockwise: false)
            ..lineTo(126, 103)
            ..arcToPoint(const Offset(126, 241), radius: const Radius.circular(69), clockwise: false)
            ..close())
          .computeMetrics()
          .first;

  // where the icon's runner stands (98, 113), as a distance along the lane
  static final double _start = () {
    var best = 0.0, bestD = double.infinity;
    for (var i = 0; i <= 400; i++) {
      final s = _lane.length * i / 400;
      final d = (_lane.getTangentForOffset(s)!.position - const Offset(98, 113)).distanceSquared;
      if (d < bestD) (best, bestD) = (s, d);
    }
    return best;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final r = reveal(t);
    final k = box / 516;
    final c = size.center(Offset.zero);
    // geometric zoom reads as constant speed to the eye; ease-in so it gathers pace
    final cover = size.longestSide / (45.5 * k) * 1.25;
    final zoom = math.pow(cover, Curves.easeInCubic.transform(r)).toDouble();

    canvas.translate(c.dx, c.dy);
    canvas.scale(k * zoom);
    canvas.translate(-172, -172); // svg centre

    // the ground, with the infield cut out once the window starts opening
    final screen = Rect.fromCenter(
      center: const Offset(172, 172),
      width: size.width / (k * zoom) + 2,
      height: size.height / (k * zoom) + 2,
    );
    final ground = Path()..addRect(screen);
    if (r > 0) {
      ground
        ..fillType = PathFillType.evenOdd
        ..addRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(80.5, 126.5, 263.5, 217.5), const Radius.circular(45.5)),
        );
    }
    canvas.drawPath(ground, Paint()..color = this.ground);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..color = ink;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 86, 264, 172), const Radius.circular(86)), stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(74, 120, 196, 104), const Radius.circular(52)),
      stroke..color = ink.withValues(alpha: .55),
    );

    // the runner: still, then accelerating hard, crossing the line at full speed
    final run = ((t - hold) / (finish - hold)).clamp(0.0, double.infinity);
    final p = run <= 1 ? run * run : 1 + 2 * (run - 1); // ease-in, then keep the exit speed
    final dist = _lane.length - _start;
    final s = _start + dist * p;
    final speed = run <= 0 ? 0.0 : math.min(1.0, 2 * math.min(run, 1.0)); // 0..1

    // chalk trail behind the runner
    if (speed > 0) {
      final tail = 150 * speed;
      for (var i = 0; i < 3; i++) {
        final a = s - tail * i / 3, b = s - tail * (i + 1) / 3;
        canvas.drawPath(
          _segment(math.max(b, _start), a),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8 - i * 2
            ..strokeCap = StrokeCap.round
            ..color = accent.withValues(alpha: (.7 - i * .22) * (1 - r)),
        );
      }
    }

    // the finish tape; at the line it snaps and the halves swing away
    final snap = Curves.easeOutCubic.transform(((t - finish) / .22).clamp(0.0, 1.0));
    final tape = Paint()
      ..strokeWidth = 7
      ..color = ink.withValues(alpha: 1 - snap);
    for (final (pivot, end, dir) in [
      (const Offset(214, 224), const Offset(214, 241), -1.0),
      (const Offset(214, 258), const Offset(214, 241), 1.0),
    ]) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(dir * snap * 1.3);
      canvas.drawLine(Offset.zero, end - pivot, tape);
      canvas.restore();
    }

    // the runner itself, stretched along its heading by speed
    final at = _lane.getTangentForOffset(s % _lane.length)!;
    final pos = run <= 0 ? const Offset(98, 113) : at.position;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-at.angle);
    final fade = (1 - r * 2.5).clamp(0.0, 1.0); // gone before the zoom makes it huge
    final oval = Rect.fromCenter(center: Offset.zero, width: 54 * (1 + .45 * speed), height: 54 * (1 - .12 * speed));
    canvas.drawOval(oval, Paint()..color = accent.withValues(alpha: fade));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = ring.withValues(alpha: fade),
    );
    canvas.restore();
  }

  Path _segment(double from, double to) {
    final l = _lane.length;
    if (to <= l) return _lane.extractPath(from, to);
    return _lane.extractPath(from, l)..addPath(_lane.extractPath(0, to - l), Offset.zero);
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.t != t || old.ground != ground;
}
