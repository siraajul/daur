import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Daur motion. Rules (design/DIRECTION.md, app-designer motion.md):
///  - physics springs, never fixed-duration curves: interruptible, velocity carried through
///  - motion comes from the track: the runner, the lane, chalk dust, a scoreboard odometer
///  - celebrate in place, on the thing that changed; no pop-up confetti layers
///  - every moment has a haptic; "remove animations" in system settings jumps straight to the end
bool reduceMotion(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

/// Spring presets (critically-damped for UI, under-damped only for celebrated objects).
abstract final class Springs {
  static const snappy = SpringDescription(mass: 1, stiffness: 520, damping: 44); // settles, no overshoot
  static const runner = SpringDescription(mass: 1, stiffness: 90, damping: 17); // sprint with a lean
  static const bouncy = SpringDescription(mass: 1, stiffness: 380, damping: 16); // celebrated pop
  static const liquid = SpringDescription(mass: 1, stiffness: 140, damping: 9); // water slosh
}

extension SpringTo on AnimationController {
  /// Spring from where we are, at the speed we're already moving, to [target].
  TickerFuture springTo(double target, {SpringDescription spring = Springs.snappy}) =>
      animateWith(SpringSimulation(spring, value, target, velocity));
}

// ---------------------------------------------------------------------------------------------
// Odometer: each digit rolls on its own column like a stadium scoreboard (the numericText feel).
// ---------------------------------------------------------------------------------------------

class Odometer extends StatefulWidget {
  const Odometer({super.key, required this.text, required this.style});
  final String text; // digits roll; other characters cross-fade
  final TextStyle style;
  @override
  State<Odometer> createState() => _OdometerState();
}

class _OdometerState extends State<Odometer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);
  late String _from = widget.text;

  @override
  void didUpdateWidget(Odometer old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    _from = old.text;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.value = 0;
      _c.springTo(1, spring: Springs.bouncy);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (widget.style.fontSize ?? 16) * (widget.style.height ?? 1.0) * 1.05;
    final to = widget.text, from = _from.padLeft(to.length).substring(math.max(0, _from.length - to.length));
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return ClipRect(
          child: SizedBox(
            height: h,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < to.length; i++) _digit(from.length > i ? from[i] : ' ', to[i], t, i, to.length, h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _digit(String a, String b, double t, int i, int n, double h) {
    Text txt(String s) => Text(s, style: widget.style);
    if (a == b || t >= 1) return txt(b);
    // columns further right roll a touch later, like a real counter
    final lag = (n - 1 - i) * .06;
    final p = ((t - lag) / (1 - lag)).clamp(0.0, 1.2);
    final up = (int.tryParse(b) ?? 0) >= (int.tryParse(a) ?? 0);
    final dy = (up ? -1 : 1) * p * h;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: 0, child: txt(b.length >= a.length ? b : a)), // width
        Transform.translate(offset: Offset(0, dy), child: txt(a)),
        Transform.translate(offset: Offset(0, dy + (up ? h : -h)), child: txt(b)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Chalk: small rectangles of lane-line chalk kicked up with real gravity, drag and spin.
// ---------------------------------------------------------------------------------------------

class ChalkController {
  _ChalkState? _s;

  /// Kick [count] chalk bits from [at] (local coordinates), in a cone around [angle] (radians).
  void kick(
    Offset at, {
    int count = 18,
    double angle = -math.pi / 2,
    double spread = 1.6,
    double power = 1,
    List<Color>? colors,
  }) => _s?._kick(at, count, angle, spread, power, colors);
}

class _Bit {
  _Bit(this.p, this.v, this.spin, this.size, this.color);
  Offset p, v;
  double rot = 0, life = 1;
  final double spin, size;
  final Color color;
}

class Chalk extends StatefulWidget {
  const Chalk({super.key, required this.controller, required this.child});
  final ChalkController controller;
  final Widget child;
  @override
  State<Chalk> createState() => _ChalkState();
}

class _ChalkState extends State<Chalk> with SingleTickerProviderStateMixin {
  final _bits = <_Bit>[];
  final _rnd = math.Random();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller._s = this;
  }

  void _kick(Offset at, int count, double angle, double spread, double power, List<Color>? palette) {
    if (reduceMotion(context)) return;
    final t = Daur.of(context);
    final colors = palette ?? [t.ink, t.ink, t.ink2, t.accent];
    for (var i = 0; i < count; i++) {
      final a = angle + (_rnd.nextDouble() - .5) * spread;
      final speed = (380 + _rnd.nextDouble() * 520) * power;
      _bits.add(
        _Bit(
          at,
          Offset(math.cos(a), math.sin(a)) * speed,
          (_rnd.nextDouble() - .5) * 18,
          3 + _rnd.nextDouble() * 4,
          colors[_rnd.nextInt(colors.length)],
        ),
      );
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    for (final b in _bits) {
      b.v = b.v * math.pow(.08, dt).toDouble() + const Offset(0, 1500) * dt; // air drag + gravity
      b.p += b.v * dt;
      b.rot += b.spin * dt;
      b.life -= dt / 1.1;
    }
    _bits.removeWhere((b) => b.life <= 0);
    if (_bits.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _ChalkPainter(_bits), child: widget.child);
}

class _ChalkPainter extends CustomPainter {
  _ChalkPainter(this.bits);
  final List<_Bit> bits;
  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      canvas.save();
      canvas.translate(b.p.dx, b.p.dy);
      canvas.rotate(b.rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: b.size * 1.8, height: b.size),
          const Radius.circular(1),
        ),
        Paint()..color = b.color.withValues(alpha: b.life.clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ChalkPainter o) => true;
}

// ---------------------------------------------------------------------------------------------
// Impact: a short directional nudge of the whole screen on a heavy landing (spring, decays fast).
// ---------------------------------------------------------------------------------------------

class ImpactController extends ChangeNotifier {
  double force = 0;
  void hit([double f = 1]) {
    force = f;
    notifyListeners();
  }
}

class Impact extends StatefulWidget {
  const Impact({super.key, required this.controller, required this.child});
  final ImpactController controller;
  final Widget child;
  @override
  State<Impact> createState() => _ImpactState();
}

class _ImpactState extends State<Impact> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_hit);
  }

  void _hit() {
    if (reduceMotion(context)) return;
    // a kick downward that springs back, like the screen took the landing
    _c.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 900, damping: 18),
        0,
        0,
        260 * widget.controller.force,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_hit);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Transform.translate(offset: Offset(0, _c.value.clamp(-14, 14)), child: child),
  );
}

// ---------------------------------------------------------------------------------------------
// Pop: a value that springs up and settles when [trigger] changes (streak flame, badges).
// ---------------------------------------------------------------------------------------------

class Pop extends StatefulWidget {
  const Pop({super.key, required this.trigger, required this.child, this.amount = .35});
  final Object trigger;
  final Widget child;
  final double amount;
  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 0);

  @override
  void didUpdateWidget(Pop old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !reduceMotion(context)) {
      _c.animateWith(SpringSimulation(Springs.bouncy, 0, 0, 9 * widget.amount * 3));
    }
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
    builder: (context, child) => Transform.scale(scale: 1 + _c.value.clamp(-.3, .8), child: child),
  );
}

// ---------------------------------------------------------------------------------------------
// Streak flame: laps in a row. Pops and rolls when it grows.
// ---------------------------------------------------------------------------------------------

class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final on = streak > 0;
    return Tooltip(
      message: '$streak full ${streak == 1 ? 'day' : 'days'} in a row',
      child: Pop(
        trigger: streak,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
          decoration: BoxDecoration(
            color: on ? t.ink.withValues(alpha: .16) : null,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 22, color: on ? t.accent : t.ink2),
              const SizedBox(width: 2),
              Odometer(
                text: '$streak',
                style: t.x(16, color: on ? t.ink : t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Medal: a milestone (first kg, 5 kg, month targets, the full cut). A native sheet; the medal is
// minted in front of you: the ring draws, the face springs in, the ribbon drops, chalk kicks.
// ---------------------------------------------------------------------------------------------

Future<void> showMedal(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String sub,
  String button = 'Nice',
}) {
  HapticFeedback.heavyImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MedalSheet(icon: icon, title: title, sub: sub, button: button),
  );
}

class _MedalSheet extends StatefulWidget {
  const _MedalSheet({required this.icon, required this.title, required this.sub, required this.button});
  final IconData icon;
  final String title, sub, button;
  @override
  State<_MedalSheet> createState() => _MedalSheetState();
}

class _MedalSheetState extends State<_MedalSheet> with TickerProviderStateMixin {
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _face = AnimationController.unbounded(vsync: this, value: 0);
  late final _ribbon = AnimationController.unbounded(vsync: this, value: 0);
  final _chalk = ChalkController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _ring.value = 1;
        _face.value = 1;
        _ribbon.value = 1;
        return;
      }
      await _ring.animateTo(1, curve: Curves.easeInOutCubic);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _face.animateWith(SpringSimulation(Springs.bouncy, 0, 1, 0));
      _chalk.kick(const Offset(110, 96), count: 26, spread: math.pi * 2, power: .7);
      await Future.delayed(const Duration(milliseconds: 160));
      if (mounted) _ribbon.animateWith(SpringSimulation(Springs.bouncy, 0, 1, 0));
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    _face.dispose();
    _ribbon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chalk(
              controller: _chalk,
              child: SizedBox(
                width: 220,
                height: 210,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_ring, _face, _ribbon]),
                  builder: (context, _) => CustomPaint(
                    painter: _MedalPainter(_ring.value, _face.value, _ribbon.value, t),
                    child: Align(
                      alignment: const Alignment(0, -.12),
                      child: Transform.scale(
                        scale: _face.value.clamp(0, 1.4),
                        child: Icon(widget.icon, size: 56, color: t.onAccent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: t.x(26, color: t.sheetInk),
            ),
            const SizedBox(height: 8),
            Text(widget.sub, textAlign: TextAlign.center, style: t.sec(t.sheetInk2)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  shape: const StadiumBorder(),
                ),
                child: Text(widget.button, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  _MedalPainter(this.ring, this.face, this.ribbon, this.t);
  final double ring, face, ribbon;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, 96);
    const r = 66.0;
    // ribbon tails drop from behind the medal
    if (ribbon > 0) {
      final drop = 70 * ribbon.clamp(0, 1.2);
      for (final s in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(c.dx + s * 14, c.dy + r * .6)
          ..lineTo(c.dx + s * 44, c.dy + r * .6 + drop)
          ..lineTo(c.dx + s * 30, c.dy + r * .6 + drop - 12)
          ..lineTo(c.dx + s * 18, c.dy + r * .6 + drop)
          ..lineTo(c.dx + s * 2, c.dy + r * .6)
          ..close();
        canvas.drawPath(path, Paint()..color = t.ground);
      }
    }
    // face
    canvas.drawCircle(c, r * face.clamp(0, 1.15), Paint()..color = t.accent);
    // the ring draws itself, a lap of the medal
    final rect = Rect.fromCircle(center: c, radius: r + 6);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..color = t.ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MedalPainter o) => o.ring != ring || o.face != face || o.ribbon != ribbon;
}

// ---------------------------------------------------------------------------------------------
// 3-2-1 GO for the rest timer: each digit drops onto the infield and settles; GO kicks chalk.
// ---------------------------------------------------------------------------------------------

class CountdownDigit extends StatefulWidget {
  const CountdownDigit({super.key, required this.left, required this.style, required this.goStyle});
  final int left; // 3, 2, 1; 0 = GO
  final TextStyle style, goStyle;
  @override
  State<CountdownDigit> createState() => _CountdownDigitState();
}

class _CountdownDigitState extends State<CountdownDigit> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(CountdownDigit old) {
    super.didUpdateWidget(old);
    if (old.left != widget.left && !reduceMotion(context)) {
      _c.value = 0;
      _c.animateWith(SpringSimulation(Springs.bouncy, 0, 1, 0));
      widget.left == 0 ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final v = _c.value;
      return Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * -40),
          child: Transform.scale(
            scale: .6 + .4 * v,
            child: Text(
              widget.left == 0 ? 'GO' : '${widget.left}',
              style: widget.left == 0 ? widget.goStyle : widget.style,
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Water glass: the level rises on a spring; the surface sloshes with a damped wave.
// ---------------------------------------------------------------------------------------------

class WaterGlass extends StatefulWidget {
  const WaterGlass({super.key, required this.full, required this.next, this.wave = false, this.index = 0});
  final bool full, next; // drunk / the next one to drink
  final bool wave; // turning true makes full glasses slosh one after another (the 3.5 L wave)
  final int index;
  @override
  State<WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<WaterGlass> with TickerProviderStateMixin {
  late final _level = AnimationController.unbounded(vsync: this, value: widget.full ? 1 : 0);
  late final _slosh = AnimationController.unbounded(vsync: this, value: 0);
  late final _phase = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _drops = ChalkController();

  @override
  void didUpdateWidget(WaterGlass old) {
    super.didUpdateWidget(old);
    final still = reduceMotion(context);
    final t0 = Daur.of(context);
    if (old.full != widget.full) {
      still ? _level.value = widget.full ? 1 : 0 : _level.springTo(widget.full ? 1 : 0, spring: Springs.liquid);
      if (!still) _shake(widget.full ? 1 : .6);
      if (widget.full && !still) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _drops.kick(
            Offset(box.size.width / 2, box.size.height * .15),
            count: 8,
            spread: 1.2,
            power: .45,
            colors: [t0.ink, t0.ink2],
          );
        }
      }
    }
    if (!old.wave && widget.wave && widget.full && !still) {
      Future.delayed(Duration(milliseconds: 60 * widget.index), () {
        if (mounted) _shake(.9);
      });
    }
  }

  void _shake(double f) {
    _slosh.animateWith(SpringSimulation(Springs.liquid, 0, 0, 6 * f));
    _phase.repeat();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _phase.stop();
    });
  }

  @override
  void dispose() {
    _level.dispose();
    _slosh.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Chalk(
      controller: _drops,
      child: AnimatedBuilder(
        animation: Listenable.merge([_level, _slosh, _phase]),
        builder: (context, _) => CustomPaint(
          painter: _GlassPainter(
            level: _level.value.clamp(0, 1.08),
            slosh: _slosh.value.clamp(-1.2, 1.2),
            phase: _phase.value,
            next: widget.next,
            t: t,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({required this.level, required this.slosh, required this.phase, required this.next, required this.t});
  final double level, slosh, phase;
  final bool next;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );
    if (level > 0) {
      canvas.save();
      canvas.clipRRect(r);
      final y = size.height * (1 - level);
      final amp = 6 * slosh;
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 2) {
        final wave = math.sin(x / size.width * math.pi * 2 + phase * math.pi * 2) * amp * .5;
        final tilt = (x / size.width - .5) * amp; // the surface tips as it sloshes
        path.lineTo(x, y + wave + tilt);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = t.ink);
      canvas.restore();
    }
    canvas.drawRRect(
      r.deflate(next ? 1.25 : .75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = next ? 2.5 : 1.5
        ..color = level > .98 ? t.ink : (next ? t.accent : t.lane),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter o) => o.level != level || o.slosh != slosh || o.phase != phase || o.next != next;
}
