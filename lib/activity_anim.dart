import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'theme.dart';
import 'today.dart' show thousands;

// Each activity moves its own way when it shows up: water sloshes up, steps walk across, sleep
// floats z's, the scale's needle swings, the dumbbell lifts, the flame flickers, a heart bursts.
// Every one plays once (or a few loops) and then rests; with reduced motion it is simply there.

/// Plays 0 → 1 after [delay] when it shows (again each time its tab comes back); 1 straight away
/// with reduced motion.
class Play extends StatefulWidget {
  const Play({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.child,
  });
  final Widget Function(BuildContext context, double v, Widget? child) builder;
  final Duration delay, duration;
  final Curve curve;
  final Widget? child;

  @override
  State<Play> createState() => _PlayState();
}

class _PlayState extends State<Play> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // a tab built while hidden waits until it's shown, and plays again each time it comes back
    if (!Visibility.of(context)) {
      _shown = false;
      return;
    }
    if (_shown) return;
    _shown = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, widget.curve.transform(_c.value), child),
  );
}

/// Slides a row in from below, a beat after the one before it, when its screen shows.
class SlideIn extends StatelessWidget {
  const SlideIn({super.key, required this.i, required this.child, this.after = const Duration(milliseconds: 250)});
  final int i;
  final Widget child;
  final Duration after; // before the first row

  @override
  Widget build(BuildContext context) => Play(
    delay: after + Duration(milliseconds: 70 * math.min(i, 8)), // a long list doesn't keep you waiting
    duration: const Duration(milliseconds: 520),
    child: child,
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: child),
    ),
  );
}

/// A tile in the shape of [Tiles]' (icon, value, label) with something alive behind it.
class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.icon, required this.value, required this.label, this.back});
  final IconData icon;
  final String value, label;
  final Widget? back; // painted behind the text, clipped to the tile

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final ic = Icon(icon, size: 18, color: t.ink);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: t.infield,
        child: Stack(
          children: [
            if (back != null) Positioned.fill(child: back!),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ic,
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
          ],
        ),
      ),
    );
  }
}

// ---- water: liquid fills its box to the level on a liquid spring, sloshes, settles; again on change ----

class Liquid extends StatefulWidget {
  const Liquid({super.key, required this.frac});
  final double frac; // 0..1 of the box
  @override
  State<Liquid> createState() => _LiquidState();
}

class _LiquidState extends State<Liquid> with TickerProviderStateMixin {
  late final _level = AnimationController.unbounded(vsync: this, value: 0);
  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  bool _started = false;

  double get _to => widget.frac.clamp(0, 1).toDouble();

  void _pour() {
    if (reduceMotion(context)) {
      _level.value = _to;
      return;
    }
    _level.animateWith(SpringSimulation(Springs.liquid, _level.value, _to, _level.velocity));
    _wave.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _pour();
  }

  @override
  void didUpdateWidget(Liquid old) {
    super.didUpdateWidget(old);
    if (old.frac != widget.frac) _pour();
  }

  @override
  void dispose() {
    _level.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_level, _wave]),
        builder: (context, _) =>
            CustomPaint(painter: _LiquidPainter(_level.value, _wave.value, t), size: Size.infinite),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter(this.level, this.wave, this.t);
  final double level, wave;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final amp = 5 * (1 - wave); // sloshes hard at first, then flat
    for (final (shift, alpha) in const [(0.0, .16), (2.2, .10)]) {
      final surface = size.height * (1 - level.clamp(0, 1.08));
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        path.lineTo(x, surface + math.sin(x / size.width * 2 * math.pi * 1.3 + wave * 14 + shift) * amp);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = t.ink.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_LiquidPainter old) => old.level != level || old.wave != wave;
}

class WaterTile extends StatelessWidget {
  const WaterTile({super.key, required this.frac, required this.value, required this.label});
  final double frac; // of the day's goal
  final String value, label;

  @override
  Widget build(BuildContext context) => _TileFrame(
    icon: Icons.water_drop_outlined,
    value: value,
    label: label,
    back: Liquid(frac: frac),
  );
}

// ---- steps: footprints walk across the bottom of the box, one per ninth of the target ----

class Footprints extends StatefulWidget {
  const Footprints({super.key, required this.frac, this.delay = Duration.zero});
  final double frac; // of the day's target
  final Duration delay;
  @override
  State<Footprints> createState() => _FootprintsState();
}

class _FootprintsState extends State<Footprints> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void didUpdateWidget(Footprints old) {
    super.didUpdateWidget(old);
    // more steps: walk the trail again
    if (widget.frac > old.frac && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _Prints(_c.value, widget.frac.clamp(0, 1).toDouble(), t), size: Size.infinite),
      ),
    );
  }
}

class StepsTile extends StatelessWidget {
  const StepsTile({
    super.key,
    required this.steps,
    required this.frac,
    required this.label,
    this.delay = Duration.zero,
  });
  final int steps;
  final double frac;
  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) => Play(
    delay: delay,
    duration: const Duration(milliseconds: 1600),
    builder: (context, v, back) => _TileFrame(
      icon: Icons.directions_walk_rounded,
      value: thousands((steps * v).round()),
      label: label,
      back: back,
    ),
    child: Footprints(frac: frac, delay: delay),
  );
}

class _Prints extends CustomPainter {
  _Prints(this.v, this.frac, this.t);
  final double v, frac;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    // as many prints as the day's share of the target, left foot, right foot
    final n = (frac * 9).ceil(); // none until there's a step
    for (var i = 0; i < n; i++) {
      final at = (v * (n + 2) - i).clamp(0, 1).toDouble(); // each one lands after the last
      if (at <= 0) break;
      final left = i.isEven;
      final c = Offset(size.width - 14 - (n - 1 - i) * (size.width - 28) / 8, size.height - (left ? 16 : 26));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(math.pi / 2 + (left ? -.15 : .15));
      final p = Paint()..color = t.ink.withValues(alpha: .22 * at);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 11, height: 6), p);
      canvas.drawCircle(const Offset(8, 0), 2.4, p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Prints old) => old.v != v || old.frac != frac;
}

// ---- sleep: z's float up out of the box, three times, then still ----

class Zzz extends StatefulWidget {
  const Zzz({super.key, this.at = const Offset(30, 18)});
  final Offset at; // where the first z starts
  @override
  State<Zzz> createState() => _ZzzState();
}

class _ZzzState extends State<Zzz> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotion(context)) _c.repeat(count: 3);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final v = _c.value;
          return Stack(
            children: [
              for (var i = 0; i < 3; i++)
                Builder(
                  builder: (context) {
                    final k = ((v - i * .22) % 1 + 1) % 1; // each z a little behind the last
                    return Positioned(
                      left: widget.at.dx + i * 9 + 6 * math.sin(k * math.pi * 2),
                      top: widget.at.dy - k * 26,
                      child: Opacity(
                        opacity: math.sin(k * math.pi).clamp(0, 1).toDouble(),
                        child: Text('z', style: t.x(9.0 + i * 3, color: t.ink2)),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class SleepTile extends StatelessWidget {
  const SleepTile({super.key, required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) =>
      _TileFrame(icon: Icons.bedtime_outlined, value: value, label: label, back: const Zzz());
}

// ---- a stamp: when something gets done, its mark lands like a rubber stamp ----

class Stamp extends StatefulWidget {
  const Stamp({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  State<Stamp> createState() => _StampState();
}

class _StampState extends State<Stamp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);

  @override
  void didUpdateWidget(Stamp old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final v = _c.value;
      // comes down big and tilted, lands, squashes a little, settles
      final scale = v < .3
          ? 1.6 - .7 * Curves.easeIn.transform(v / .3)
          : .9 + .1 * Curves.elasticOut.transform((v - .3) / .7);
      return Transform.rotate(
        angle: -.35 * (1 - Curves.easeOut.transform(v)),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}

// ---- confetti: a burst of the app's colours, drawn in code, when [burst] turns true ----

class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.burst, required this.child, this.onShow = false});
  final bool burst;
  final bool onShow; // also burst the first time it shows, if [burst] is already true
  final Widget child;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _started = false;
  int _seed = 0;

  void _fire() {
    if (reduceMotion(context)) return;
    _seed++;
    HapticFeedback.heavyImpact();
    _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.onShow && widget.burst) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _fire();
      });
    }
  }

  @override
  void didUpdateWidget(Confetti old) {
    super.didUpdateWidget(old);
    if (widget.burst && !old.burst) _fire();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) =>
                  _c.isAnimating ? CustomPaint(painter: _ConfettiPainter(_c.value, _seed, t)) : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.v, this.seed, this.t);
  final double v;
  final int seed;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final colors = [t.accent, t.ink, t.accent, t.onAccent];
    final origin = Offset(size.width / 2, size.height * .45);
    for (var i = 0; i < 46; i++) {
      // each piece: thrown up and out, falls with gravity, spins, fades at the end
      final a = -math.pi / 2 + (r.nextDouble() - .5) * 2.4;
      final speed = 260 + r.nextDouble() * 320;
      final time = v * 2.2;
      final p = origin + Offset(math.cos(a) * speed * time * .55, math.sin(a) * speed * time * .55 + 340 * time * time);
      final spin = r.nextDouble() * 12 * time + r.nextDouble() * math.pi;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(spin);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: (1 - v).clamp(0, 1) * .95);
      i % 3 == 0
          ? canvas.drawCircle(Offset.zero, 3.2, paint)
          : canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 9, height: 4.5),
                const Radius.circular(1.5),
              ),
              paint,
            );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.v != v;
}

// ---- a card: weight on a bathroom-scale dial; gym with a lifting dumbbell and session dots ----

class ActivityCard extends StatelessWidget {
  const ActivityCard.weight({super.key, required this.big, required this.small, required this.kg, this.locked = false})
    : dots = null;
  const ActivityCard.gym({super.key, required this.big, required this.small, required this.dots})
    : kg = null,
      locked = false;
  final String big, small;
  final bool locked;
  final double? kg; // weight: change since day 1, the needle's swing
  final (int, int)? dots; // gym: sessions of target

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Play(
      delay: const Duration(milliseconds: 300),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.linear,
      builder: (context, v, _) {
        final lift = dots != null ? -6 * math.sin(math.pi * 2 * (v * 1.4).clamp(0, 1)).abs() : 0.0;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform.translate(
                    offset: Offset(0, lift),
                    child: Icon(
                      locked
                          ? Icons.lock_outline_rounded
                          : dots != null
                          ? Icons.fitness_center_rounded
                          : Icons.monitor_weight_outlined,
                      size: 18,
                      color: t.ink,
                    ),
                  ),
                  const Spacer(),
                  if (dots case (final on, final of))
                    for (var i = 0; i < of; i++)
                      Builder(
                        builder: (context) {
                          final pop = Curves.elasticOut.transform(((v - .35 - i * .14) / .4).clamp(0, 1));
                          final full = i < on;
                          return Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 4),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: t.lane, width: 1.5),
                                  ),
                                ),
                                if (full)
                                  Transform.scale(
                                    scale: pop,
                                    child: Container(
                                      decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  if (kg case final kg? when !locked)
                    SizedBox(width: 44, height: 24, child: CustomPaint(painter: _Dial(kg, v, t))),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(big, style: t.x(22)),
              ),
              Text(small, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

/// A bathroom scale's dial: the needle swings past and settles on the change (−5 … +5 kg).
class _Dial extends CustomPainter {
  _Dial(this.kg, this.v, this.t);
  final double kg, v;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height);
    final r = size.height - 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = t.lane;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi, math.pi, false, stroke);
    for (var i = 0; i <= 4; i++) {
      final a = math.pi + i * math.pi / 4;
      canvas.drawLine(c + Offset.fromDirection(a, r - 4), c + Offset.fromDirection(a, r), stroke);
    }
    final target = (kg.clamp(-5, 5) / 5) * (math.pi / 2 - .2);
    final swing = target * Curves.elasticOut.transform(v.clamp(0, 1));
    canvas.drawLine(
      c,
      c + Offset.fromDirection(-math.pi / 2 + swing, r - 3),
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = t.accent,
    );
    canvas.drawCircle(c, 3, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(_Dial old) => old.v != v || old.kg != kg;
}

// ---- the streak: a flame that flickers for a moment and a count that runs up ----

class FlameCount extends StatefulWidget {
  const FlameCount({super.key, required this.count, required this.color, this.size = 20, this.textSize = 18});
  final int count;
  final Color color;
  final double size, textSize;
  @override
  State<FlameCount> createState() => _FlameCountState();
}

class _FlameCountState extends State<FlameCount> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    reduceMotion(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value, calm = 1 - v; // flickers hard, then burns steady
        final f = math.sin(v * 38) * calm;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1 - .06 * f, 1 + .14 * f.abs(), 1)
                ..rotateZ(.08 * math.sin(v * 23) * calm),
              child: Icon(Icons.local_fire_department_rounded, color: widget.color, size: widget.size),
            ),
            const SizedBox(width: 4),
            Text(
              '${(widget.count * Curves.easeOutCubic.transform((v * 2.2).clamp(0, 1))).round()}',
              style: t.x(widget.textSize, color: widget.color),
            ),
          ],
        );
      },
    );
  }
}

// ---- a heart that pops and throws little hearts when tapped ----

class LoveButton extends StatefulWidget {
  const LoveButton({super.key, required this.loved, required this.onTap, this.tooltip = 'Love it'});
  final bool loved;
  final VoidCallback? onTap;
  final String tooltip;
  @override
  State<LoveButton> createState() => _LoveButtonState();
}

class _LoveButtonState extends State<LoveButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(LoveButton old) {
    super.didUpdateWidget(old);
    if (widget.loved && !old.loved && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final pop = widget.loved ? 1 + .45 * math.sin(math.pi * (v / .35).clamp(0, 1)) : 1.0;
        return SizedBox(
          width: 44,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // the burst: six small hearts fly out and up, fade
              if (_c.isAnimating)
                for (var i = 0; i < 6; i++)
                  Builder(
                    builder: (context) {
                      final a = -math.pi / 2 + (i - 2.5) * .5;
                      final d = 30 * Curves.easeOut.transform(v);
                      return Transform.translate(
                        offset: Offset.fromDirection(a, d) + Offset(0, -10 * v),
                        child: Opacity(
                          opacity: (1 - v).clamp(0, 1),
                          child: Icon(Icons.favorite_rounded, size: 9 + (i % 3) * 2, color: t.accent),
                        ),
                      );
                    },
                  ),
              IconButton(
                tooltip: widget.tooltip,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onTap == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        widget.onTap!();
                      },
                icon: Transform.scale(
                  scale: pop,
                  child: Icon(
                    widget.loved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: widget.loved ? t.accent : t.ink2,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
