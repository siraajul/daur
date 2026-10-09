import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';
import 'live.dart';
import 'motion.dart';
import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show MenuButton;
import 'workout.dart';
import 'visuals.dart';

String planText(ExPlan p) =>
    p.timed ? '${p.sets} × ${p.reps} s' : '${p.sets} × ${p.reps}${p.kg > 0 ? ' · ${kgText(p.kg)} kg' : ''}';
String kgText(double kg) => kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toString();

/// Gym session: each exercise shows its sets as circles; tap the next one to log it at the plan,
/// and a rest bar counts down at the top. Tap the exercise for reps, weight or stopping early.
class GymScreen extends StatefulWidget {
  const GymScreen({super.key, required this.store});
  final Store store;
  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  DateTime? _restEnd;
  String _restNext = '';
  Timer? _tick;
  bool _buzzed = false;

  int get _left => _restEnd == null ? 0 : _restEnd!.difference(DateTime.now()).inSeconds.clamp(0, 3600);

  /// One tap logs the next set: today's last weight and reps, else the plan.
  void _logNext(String ex) {
    final s = widget.store, p = s.plan(ex), logged = s.setsToday(ex);
    final last = logged.isEmpty ? null : logged.last;
    final reps = last?.reps ?? p.reps, kg = last?.kg ?? p.kg;
    final msg = s.logSet(ex, reps, kg);
    final n = s.setsToday(ex).length;
    if (n >= p.sets) {
      HapticFeedback.heavyImpact();
      _stopRest();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg ?? '$ex done')));
      return;
    }
    HapticFeedback.mediumImpact();
    _startRest(ex, 'Set ${n + 1} · ${p.timed ? '$reps s' : '$reps × ${kgText(kg)} kg'}');
  }

  void _startRest(String ex, String next) {
    _tick?.cancel();
    setState(() {
      _restEnd = DateTime.now().add(const Duration(seconds: restSeconds));
      _restNext = '$ex · $next';
      _buzzed = false;
    });
    Live.rest(end: _restEnd!, exercise: ex, next: next); // lock-screen countdown
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_left == 0 && !_buzzed) {
        _buzzed = true;
        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 350), HapticFeedback.vibrate);
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && _left == 0) _stopRest();
        });
      }
      if (mounted) setState(() {});
    });
  }

  void _stopRest() {
    _tick?.cancel();
    if (_restEnd != null) Live.end();
    if (mounted) setState(() => _restEnd = null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_restEnd != null) Live.end();
    super.dispose();
  }

  Widget _restBar(Daur t) {
    final go = _left == 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: go ? t.accent : t.infield,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(go ? Icons.play_arrow_rounded : Icons.timer_outlined, color: go ? t.onAccent : t.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(go ? 'Go' : 'Rest ${clock(_left)}', style: t.x(20, color: go ? t.onAccent : t.ink)),
                Text(_restNext, style: t.meta(go ? t.onAccent : null), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!go)
            TextButton(
              onPressed: () => setState(() => _restEnd = _restEnd!.add(const Duration(seconds: 15))),
              child: Text('+15 s', style: t.body()),
            ),
          IconButton(
            onPressed: _stopRest,
            tooltip: go ? 'Close' : 'Skip rest',
            icon: Icon(go ? Icons.close_rounded : Icons.skip_next_rounded, color: go ? t.onAccent : t.ink),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = widget.store;
    final day = s.gymDay, list = s.dayExercises; // push / pull / legs: only today's exercises
    final done = list.where(s.exerciseDone).length;
    final cardioMin = s.cardio.fold(0, (a, c) => a + c.seconds) ~/ 60;
    final cardioKm = s.cardio.fold(0.0, (a, c) => a + c.km);

    // the rest bar floats above the tab bar: in the thumb zone, and the list doesn't jump
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, _restEnd == null ? 24 : 110),
              children: [
                Row(
                  children: [
                    const MenuButton(),
                    Expanded(child: Text('Gym', style: t.title())),
                    MoreButton([
                      MenuItem('Clear today', s.clearGymTicks, destructive: true),
                      MenuItem('Restore default list', s.restoreGym),
                    ]),
                  ],
                ),
                // the rule is 3–5 sessions a week, not every day: say where the week stands
                Text(
                  s.gymToday
                      ? '$day day · session ${s.gymThisWeek} this week · ${s.setsDoneOn(list)} of ${s.setsPlannedOn(list)} sets'
                      : s.gymThisWeek >= 5
                      ? '${s.gymThisWeek} sessions this week · rest day'
                      : '$day day next · ${s.gymThisWeek} of 3–5 sessions this week',
                  style: t.sec(),
                ),
                const SizedBox(height: 14),
                // the split: today's day is picked from the rotation; tap another to switch
                Segments<String>(
                  items: [
                    for (final d in Store.splitDays)
                      (
                        d,
                        d,
                        switch (d) {
                          'Push' => Icons.north_east_rounded,
                          'Pull' => Icons.south_west_rounded,
                          _ => Icons.directions_run_rounded,
                        },
                      ),
                  ],
                  value: day,
                  onChanged: s.pickGymDay,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$done', style: t.x(68, weight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Text('of ${list.length}', style: t.x(28)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: Hurdles(n: list.length, cleared: done),
                ),
                const SizedBox(height: 12),
                for (final (i, ex) in list.indexed)
                  _ExerciseRow(store: s, ex: ex, index: i, onLogNext: () => _logNext(ex)),
                _Row(
                  leading: Icon(Icons.directions_walk, color: t.ink),
                  title: 'Treadmill',
                  sub: s.cardio.isEmpty
                      ? 'Cardio, optional · 20–30 min'
                      : '$cardioMin min · ${cardioKm.toStringAsFixed(2)} km today',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(fullscreenDialog: true, builder: (_) => TreadmillScreen(store: s)),
                  ),
                ),
                _AddExercise(store: s),
                const SizedBox(height: 24),
                const Tip(Icons.fitness_center_rounded, 'Keep the muscle, lose the fat'),
              ],
            ),
          ),
          if (_restEnd != null) Positioned(left: 0, right: 0, bottom: 8, child: _restBar(t)),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.store, required this.ex, required this.index, required this.onLogNext});
  final Store store;
  final String ex;
  final int index;
  final VoidCallback onLogNext;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final p = store.plan(ex);
    final logged = store.setsToday(ex);
    final done = store.exerciseDone(ex);
    final inProgress = logged.isNotEmpty && !done;
    return _Row(
      leading: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? t.ink : null,
          border: Border.all(
            color: done
                ? t.ink
                : inProgress
                ? t.accent
                : t.lane,
            width: inProgress ? 2.5 : 1.5,
          ),
        ),
        child: done ? Icon(Icons.check, size: 16, color: t.ground) : null,
      ),
      title: ex,
      titleColor: done ? t.ink2 : t.ink,
      bold: inProgress,
      sub: planText(p),
      // one circle per set: filled = done (reps inside), yellow ring = tap to log the next one
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < math.max(p.sets, logged.length); k++)
            _SetDot(
              label: k < logged.length ? '${logged[k].reps}' : '${k + 1}',
              state: k < logged.length
                  ? _Dot.done
                  : done
                  ? _Dot.skipped
                  : k == logged.length
                  ? _Dot.next
                  : _Dot.todo,
              onTap: !done && k >= logged.length ? onLogNext : null,
              semantics: k < logged.length ? 'Set ${k + 1} done' : 'Log set ${logged.length + 1} of $ex',
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseScreen(store: store, ex: ex, index: index),
        ),
      ),
    );
  }
}

enum _Dot { done, next, todo, skipped }

class _SetDot extends StatelessWidget {
  const _SetDot({required this.label, required this.state, required this.onTap, required this.semantics});
  final String label, semantics;
  final _Dot state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final fill = state == _Dot.done ? t.ink : null;
    final border = switch (state) {
      _Dot.done => t.ink,
      _Dot.next => t.accent,
      _ => t.lane,
    };
    return Semantics(
      button: onTap != null,
      label: semantics,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(color: border, width: state == _Dot.next ? 2.5 : 1.5),
              ),
              child: state == _Dot.skipped
                  ? Icon(Icons.remove_rounded, size: 16, color: t.ink2)
                  : Text(
                      label,
                      // small text: ink, not yellow (yellow on red is only legible large); the ring says "next"
                      style: t.x(
                        12,
                        color: state == _Dot.done
                            ? t.ground
                            : state == _Dot.next
                            ? t.ink
                            : t.ink2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.sub,
    required this.onTap,
    this.trailing,
    this.titleColor,
    this.bold = false,
  });
  final Widget leading;
  final String title, sub;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? titleColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.rule, width: .5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Align(alignment: Alignment.centerLeft, child: leading),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: t.body(weight: bold ? FontWeight.w600 : FontWeight.w400, color: titleColor),
                  ),
                  Text(sub, style: t.meta(bold ? t.ink : null)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Exercises as hurdles on a straight: cleared ones solid, the runner just past the last one.
/// Exercises (or sets) as hurdles on a straight. [pos] is how far along the runner is (0..n,
/// fractional while it runs); between hurdles it hops a parabola over the next one.
class HurdlesPainter extends CustomPainter {
  HurdlesPainter(this.n, this.pos, this.t, {this.wobble = 0, this.wobbleAt = -1});
  final int n;
  final double pos, wobble; // wobble: the just-cleared hurdle rocking (radians, decays)
  final int wobbleAt;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = h / 2;
    final lane = Paint()
      ..color = t.lane
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, 2), Offset(w, 2), lane);
    canvas.drawLine(Offset(0, h - 2), Offset(w, h - 2), lane);
    if (n == 0) return;
    final gap = n == 1 ? 0.0 : (w - 48) / (n - 1);
    double x(int i) => 24 + i * gap;
    double rest(int k) => k == 0 ? 10.0 : (x(k - 1) + (gap == 0 ? 20 : gap / 2)).clamp(0, w - 10).toDouble();
    final p = pos.clamp(0, n.toDouble()).toDouble();
    final k = p.floor().clamp(0, n), f = p - k;
    final rx = k >= n ? rest(n) : rest(k) + (rest(k + 1) - rest(k)) * f;
    final lift = k < n ? math.sin(f * math.pi) * (h * .55) : 0.0; // hop over hurdle k

    for (var i = 0; i < n; i++) {
      canvas.save();
      canvas.translate(x(i), h - 8);
      if (i == wobbleAt) canvas.rotate(wobble);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-2.5, -(h - 16), 5, h - 16), const Radius.circular(2.5)),
        Paint()..color = i < p.round() ? t.ink : t.faint,
      );
      canvas.restore();
    }
    canvas.drawLine(
      Offset(0, mid),
      Offset(rx, mid),
      Paint()
        ..color = t.ink
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final c = Offset(rx, mid - lift);
    canvas.drawCircle(c, 11.75, Paint()..color = t.ground);
    canvas.drawCircle(c, 10, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(HurdlesPainter o) =>
      o.n != n || o.pos != pos || o.t != t || o.wobble != wobble || o.wobbleAt != wobbleAt;
}

/// The hurdle rail, animated: when [cleared] goes up the runner hops the next hurdle on a spring,
/// the hurdle it clipped rocks and settles, with a haptic on each landing.
class Hurdles extends StatefulWidget {
  const Hurdles({super.key, required this.n, required this.cleared, this.height = 48});
  final int n, cleared;
  final double height;
  @override
  State<Hurdles> createState() => _HurdlesState();
}

class _HurdlesState extends State<Hurdles> with TickerProviderStateMixin {
  late final _pos = AnimationController.unbounded(vsync: this, value: widget.cleared.toDouble());
  late final _wob = AnimationController.unbounded(vsync: this, value: 0);
  int _wobbleAt = -1;

  @override
  void didUpdateWidget(Hurdles old) {
    super.didUpdateWidget(old);
    if (old.cleared == widget.cleared) return;
    if (reduceMotion(context)) {
      _pos.value = widget.cleared.toDouble();
      return;
    }
    final up = widget.cleared > old.cleared;
    _pos.animateWith(SpringSimulation(Springs.runner, _pos.value, widget.cleared.toDouble(), _pos.velocity)).then((_) {
      if (!mounted || !up) return;
      HapticFeedback.mediumImpact();
      _wobbleAt = widget.cleared - 1;
      _wob.animateWith(SpringSimulation(Springs.bouncy, 0, 0, 2.2)); // a rock, then still
    });
  }

  @override
  void dispose() {
    _pos.dispose();
    _wob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pos, _wob]),
        builder: (context, _) => CustomPaint(
          painter: HurdlesPainter(widget.n, _pos.value, t, wobble: _wob.value.clamp(-.5, .5), wobbleAt: _wobbleAt),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AddExercise extends StatefulWidget {
  const _AddExercise({required this.store});
  final Store store;
  @override
  State<_AddExercise> createState() => _AddExerciseState();
}

class _AddExerciseState extends State<_AddExercise> {
  final _c = TextEditingController();

  void _add() {
    widget.store.addExercise(_c.text);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return TextField(
      controller: _c,
      maxLength: 60,
      style: t.body(weight: FontWeight.w400),
      onSubmitted: (_) => _add(),
      decoration: InputDecoration(
        hintText: 'Add an exercise, e.g. Leg curl',
        hintStyle: t.sec(),
        counterText: '',
        prefixIcon: Icon(Icons.add, color: t.ink),
        suffixIcon: IconButton(
          onPressed: _add,
          tooltip: 'Add exercise',
          icon: Icon(Icons.check, color: t.ink),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.ink)),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
