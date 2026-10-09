import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Dau, the runner dot with a face: the yellow dot that runs the track, in four moods. Decoration
/// on top of the plain UI, never a control: success moments, empty screens, Ma's page.
/// Design: the Daur mascot canvas (direction A). Drawn in a 200 × 200 box, scaled to [size].
enum DauMood { cheer, waiting, tired, sprint }

class Dau extends StatefulWidget {
  const Dau({super.key, required this.mood, this.size = 120, this.label});
  final DauMood mood;
  final double size;
  final String? label; // for screen readers; null = decoration, skipped

  @override
  State<Dau> createState() => _DauState();
}

class _DauState extends State<Dau> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // three loops, then still: a moment, not a screen that never rests (battery, and the phone's
    // screen reader waits for a still screen)
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.repeat(count: 3).whenComplete(() => _c.value = 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final art = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _DauPainter(widget.mood, _c.value, t)),
      ),
    );
    return widget.label == null
        ? ExcludeSemantics(child: art)
        : Semantics(label: widget.label, image: true, child: art);
  }
}

class _DauPainter extends CustomPainter {
  _DauPainter(this.mood, this.phase, this.t);
  final DauMood mood;
  final double phase; // 0–1, one loop
  final Daur t;

  static const _dark = Color(0xFF3A1208), _cheek = Color(0xFFF2937B);

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _line(Canvas c, double x1, double y1, double x2, double y2, Paint p) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  /// The yellow body with the track-red ring round it, like the runner dot on the track.
  void _body(Canvas c, Rect r) {
    c.drawOval(r, Paint()..color = t.accent);
    c.drawOval(r, _stroke(t.ground, 6));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final wave = math.sin(phase * 2 * math.pi); // −1…1, once a loop
    final limb = _stroke(t.accent, 10);
    final face = _stroke(_dark, 5);
    final dark = Paint()..color = _dark;
    switch (mood) {
      case DauMood.cheer:
        canvas.translate(0, -6 * wave.abs()); // a little hop
        final sparkle = _stroke(t.ink, 5);
        _line(canvas, 38, 50, 26, 40, sparkle);
        _line(canvas, 162, 50, 174, 40, sparkle);
        _line(canvas, 100, 22, 100, 10, sparkle);
        // arms up, waving a little either side
        final a = wave * .15;
        _line(canvas, 64, 98, 64 - 22 * math.cos(a) - 38 * math.sin(a), 98 - 38 * math.cos(a) + 22 * math.sin(a), limb);
        _line(
          canvas,
          136,
          98,
          136 + 22 * math.cos(a) - 38 * math.sin(a),
          98 - 38 * math.cos(a) - 22 * math.sin(a),
          limb,
        );
        _line(canvas, 88, 148, 82, 178, limb);
        _line(canvas, 112, 148, 118, 178, limb);
        _body(canvas, Rect.fromCircle(center: const Offset(100, 108), radius: 46));
        final eye = _stroke(_dark, 6);
        canvas.drawPath(
          Path()
            ..moveTo(78, 102)
            ..quadraticBezierTo(86, 92, 94, 102),
          eye,
        );
        canvas.drawPath(
          Path()
            ..moveTo(106, 102)
            ..quadraticBezierTo(114, 92, 122, 102),
          eye,
        );
        canvas.drawPath(
          Path()
            ..moveTo(84, 116)
            ..quadraticBezierTo(100, 138, 116, 116)
            ..close(),
          dark,
        );
        canvas.drawCircle(const Offset(72, 118), 5, Paint()..color = _cheek);
        canvas.drawCircle(const Offset(128, 118), 5, Paint()..color = _cheek);
      case DauMood.waiting:
        _line(canvas, 16, 162, 184, 162, _stroke(t.ink.withValues(alpha: .5), 4));
        _line(canvas, 60, 126, 54, 150, limb);
        _line(canvas, 92, 150, 122, 158, limb);
        _line(canvas, 104, 152, 136, 156, limb);
        _body(canvas, Rect.fromCircle(center: const Offset(96, 116), radius: 44));
        final blink = phase > .9 ? .15 : 1.0; // a blink near the end of each loop
        canvas.drawOval(Rect.fromCenter(center: const Offset(104, 108), width: 10, height: 14 * blink), dark);
        canvas.drawOval(Rect.fromCenter(center: const Offset(124, 108), width: 10, height: 14 * blink), dark);
        _line(canvas, 106, 130, 122, 130, face);
        // thought dots, one after another
        for (final (i, p) in const [Offset(150, 70), Offset(166, 58), Offset(182, 46)].indexed) {
          final on = (phase * 4 - i).clamp(0.0, 1.0);
          canvas.drawCircle(p, 5, Paint()..color = t.ink.withValues(alpha: on));
        }
      case DauMood.tired:
        _line(canvas, 54, 122, 46, 152, limb);
        _line(canvas, 146, 122, 154, 152, limb);
        canvas.drawPath(
          Path()
            ..moveTo(88, 154)
            ..quadraticBezierTo(82, 166, 84, 178),
          limb,
        );
        canvas.drawPath(
          Path()
            ..moveTo(112, 154)
            ..quadraticBezierTo(118, 166, 116, 178),
          limb,
        );
        final breath = 1 + .03 * wave; // slow, heavy breathing
        _body(canvas, Rect.fromCenter(center: const Offset(100, 118), width: 100, height: 84 * breath));
        _line(canvas, 74, 108, 92, 108, face);
        _line(canvas, 108, 108, 126, 108, face);
        canvas.drawPath(
          Path()
            ..moveTo(76, 108)
            ..quadraticBezierTo(83, 116, 90, 108),
          face,
        );
        canvas.drawPath(
          Path()
            ..moveTo(110, 108)
            ..quadraticBezierTo(117, 116, 124, 108),
          face,
        );
        canvas.drawPath(
          Path()
            ..moveTo(86, 132)
            ..quadraticBezierTo(93, 126, 100, 132)
            ..quadraticBezierTo(107, 138, 114, 132),
          face,
        );
        // a sweat drop slides down and fades
        final dy = 10 * phase;
        canvas.drawPath(
          Path()
            ..moveTo(150, 70 + dy)
            ..quadraticBezierTo(160, 84 + dy, 150, 92 + dy)
            ..quadraticBezierTo(140, 84 + dy, 150, 70 + dy),
          Paint()..color = t.ink.withValues(alpha: 1 - phase * .7),
        );
      case DauMood.sprint:
        final drift = 8 * phase; // motion lines stream back
        final motion = _stroke(t.ink.withValues(alpha: .85), 5);
        _line(canvas, 14 - drift, 92, 46 - drift, 92, motion);
        _line(canvas, 8 - drift, 112, 42 - drift, 112, motion);
        _line(canvas, 20 - drift, 132, 42 - drift, 132, motion);
        canvas.save();
        canvas.translate(112, 110);
        canvas.rotate(-12 * math.pi / 180);
        canvas.translate(-112, -110);
        // legs and arms swap each half loop: a stride
        final s = (wave + 1) / 2;
        double mix(double a, double b) => a + (b - a) * s;
        _line(canvas, 76, 104, mix(58, 62), mix(126, 84), limb);
        _line(canvas, 148, 100, mix(164, 162), mix(82, 124), limb);
        _line(canvas, 102, 150, mix(86, 146), mix(180, 170), limb);
        _line(canvas, 122, 148, mix(150, 92), mix(168, 180), limb);
        _body(canvas, Rect.fromCircle(center: const Offset(112, 108), radius: 44));
        canvas.drawOval(Rect.fromCenter(center: const Offset(120, 104), width: 10, height: 14), dark);
        canvas.drawOval(Rect.fromCenter(center: const Offset(140, 104), width: 10, height: 14), dark);
        _line(canvas, 112, 90, 126, 95, face);
        _line(canvas, 148, 90, 136, 95, face);
        canvas.drawPath(
          Path()
            ..moveTo(122, 124)
            ..quadraticBezierTo(132, 130, 142, 124),
          face,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DauPainter o) => o.phase != phase || o.mood != mood || o.t != t;
}
