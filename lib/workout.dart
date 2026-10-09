import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gym.dart';
import 'motion.dart';
import 'live.dart';
import 'plan.dart';
import 'progress.dart' show ProgressScreen;
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, niceDate;
import 'track.dart';
import 'visuals.dart';

String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Log one exercise set by set: reps (or seconds) and weight steppers, last session, rest between sets.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.store, required this.ex, required this.index});
  final Store store;
  final String ex;
  final int index;
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late int reps = widget.store.plan(widget.ex).reps;
  late double kg = widget.store.plan(widget.ex).kg;

  Future<void> _log() async {
    final s = widget.store, ex = widget.ex, p = s.plan(ex);
    final stepUp = s.logSet(ex, reps, kg);
    final n = s.setsToday(ex).length;
    if (n >= p.sets) {
      // let the runner clear the last hurdle and land before leaving the screen
      HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      await Future.delayed(Duration(milliseconds: reduceMotion(context) ? 0 : 950));
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            stepUp ??
                (s.setsToday(ex).any((x) => x.reps < p.reps)
                    ? 'A few reps short · same plan next time'
                    : 'Lighter today · plan stays ${planText(p)}'),
          ),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RestScreen(
          ex: ex,
          nextSet: n + 1,
          sets: p.sets,
          next: p.timed ? '$reps s hold' : '$reps reps × ${kgText(kg)} kg',
        ),
      ),
    );
  }

  Future<void> _stop() async {
    final s = widget.store, ex = widget.ex, p = s.plan(ex);
    final n = s.setsToday(ex).length;
    final eased = s.endExercise(ex);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(eased ?? '$n of ${p.sets} sets · same plan next time'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store, ex = widget.ex, p = s.plan(ex);
        final logged = s.setsToday(ex);
        final all = s.exerciseDone(ex); // every set in, or stopped early
        final stopped = all && logged.length < p.sets;
        final last = s.lastSession(ex);
        String setText(SetLog x) => p.timed ? '${x.reps} s hold' : '${x.reps} reps × ${kgText(x.kg)} kg';

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      PageHeader(
                        ex,
                        sub:
                            '${s.splitDayOf(ex)} · ${widget.index + 1} of ${s.exercisesOn(s.splitDayOf(ex)).length} · plan ${planText(p)}',
                        actions: [
                          PopupMenuButton<String>(
                            tooltip: 'Move or remove',
                            icon: Icon(Icons.more_horiz, color: t.ink),
                            onSelected: (v) async {
                              if (v != 'remove') {
                                s.moveExercise(ex, v);
                                return;
                              }
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Remove $ex?'),
                                  content: const Text('Its history stays. Add it back any time.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                s.removeExercise(ex);
                                Navigator.pop(context);
                              }
                            },
                            itemBuilder: (_) => [
                              for (final d in Store.splitDays)
                                if (d != s.splitDayOf(ex)) PopupMenuItem(value: d, child: Text('Move to $d day')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove from the list')),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                all ? '${logged.length}' : '${logged.length + 1}',
                                style: t.x(68, weight: FontWeight.w900),
                              ),
                              const SizedBox(width: 10),
                              Text(all ? 'sets done' : 'of ${p.sets} sets', style: t.x(24)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Hurdles(n: p.sets, cleared: logged.length, height: 40),
                          const SizedBox(height: 12),
                          for (var i = 0; i < p.sets || i < logged.length; i++)
                            _line(
                              t,
                              '${i + 1}',
                              i < logged.length
                                  ? setText(logged[i])
                                  : !all && i == logged.length
                                  ? 'Now'
                                  : setText(SetLog(p.reps, p.kg)),
                              i < logged.length
                                  ? 'done'
                                  : all
                                  ? 'skipped'
                                  : i == logged.length
                                  ? ''
                                  : 'planned',
                              now: !all && i == logged.length,
                              done: i < logged.length,
                            ),
                          if (!all) ...[
                            const SizedBox(height: 8),
                            _Stepper(
                              label: p.timed ? 'Seconds' : 'Reps',
                              sub: 'planned ${p.reps}',
                              value: '$reps',
                              onMinus: () => setState(() => reps = (reps - (p.timed ? 5 : 1)).clamp(1, 600)),
                              onPlus: () => setState(() => reps += p.timed ? 5 : 1),
                            ),
                            if (!p.timed)
                              _Stepper(
                                label: 'Weight',
                                sub: '2.5 kg steps',
                                value: kgText(kg),
                                unit: 'kg',
                                onMinus: () => setState(() => kg = (kg - 2.5).clamp(0, 500)),
                                onPlus: () => setState(() => kg += 2.5),
                              ),
                          ],
                          const SizedBox(height: 12),
                          if (last != null)
                            Text(
                              'Last time, ${niceDate(DateTime.parse(last.$1))}: ${last.$2.length} × '
                              '${p.timed ? '${last.$2.last.reps} s' : '${last.$2.last.reps} at ${kgText(last.$2.last.kg)} kg'}.',
                              style: t.sec(),
                            ),
                          // since the first session ever (Progress → Strength has them all)
                          for (final r in s.strength.where((r) => r.ex == ex))
                            Text(
                              'Since you started: ${ProgressScreen.amount(r.start, r.unit)} → ${ProgressScreen.amount(r.now, r.unit)}',
                              style: t.sec(t.ink),
                            ),
                          if (logged.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => stopped ? s.toggleGym(ex) : s.undoSet(ex),
                                child: Text(stopped ? 'Undo stop' : 'Undo last set', style: t.sec(t.ink)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: all
                      ? Cta(label: 'Back to the session', muted: true, onTap: () => Navigator.pop(context))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Cta(
                              label: 'Log set ${logged.length + 1}',
                              trailing: p.timed ? '$reps s' : '$reps × ${kgText(kg)} kg',
                              onTap: _log,
                            ),
                            // no strength left for the rest: end here, honestly
                            if (logged.isNotEmpty)
                              TextButton.icon(
                                onPressed: _stop,
                                icon: Icon(Icons.stop_circle_outlined, color: t.ink),
                                label: Text('Stop at ${logged.length} of ${p.sets} sets', style: t.body()),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(Daur t, String n, String text, String right, {bool now = false, bool done = false}) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: t.rule, width: .5)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            n,
            style: t.x(
              22,
              color: now
                  ? t.accent
                  : done
                  ? t.ink2
                  : t.ink,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: t.body(weight: now ? FontWeight.w600 : FontWeight.w400, color: done ? t.ink2 : t.ink),
          ),
        ),
        Text(right, style: t.sec()),
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.sub,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.unit = '',
  });
  final String label, sub, value, unit;
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    Widget btn(IconData i, VoidCallback f) => IconButton.filledTonal(
      tooltip: '${i == Icons.add ? 'More' : 'Less'} ${label.toLowerCase()}',
      onPressed: () {
        f();
        HapticFeedback.selectionClick();
      },
      icon: Icon(i, color: t.ink),
      style: IconButton.styleFrom(backgroundColor: t.ink.withValues(alpha: .18), minimumSize: const Size(44, 44)),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: t.body()),
                Text(sub, style: t.meta()),
              ],
            ),
          ),
          btn(Icons.remove, onMinus),
          SizedBox(
            width: 96,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: t.x(26)),
                  if (unit.isNotEmpty) TextSpan(text: ' $unit', style: t.meta()),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          btn(Icons.add, onPlus),
        ],
      ),
    );
  }
}

/// Rest between sets: the runner laps the track while the clock runs down. ±15 s; vibrates at zero.
class RestScreen extends StatefulWidget {
  const RestScreen({super.key, required this.ex, required this.nextSet, required this.sets, required this.next});
  final String ex, next;
  final int nextSet, sets;
  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  int total = restSeconds;
  late final DateTime _start = DateTime.now();
  late final Timer _timer;
  final _trackKey = GlobalKey();
  bool _buzzed = false;
  final _chalk = ChalkController();

  int get _elapsed => DateTime.now().difference(_start).inSeconds;
  int get _left => (total - _elapsed).clamp(0, 3600);

  void _tick() {
    if (_left == 0 && !_buzzed) {
      _buzzed = true;
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 350), HapticFeedback.vibrate);
      // GO: chalk kicks up off the start line
      final box = context.findRenderObject() as RenderBox?;
      final track = _trackKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && track != null) {
        final (sc, o) = TrackPainter.fit(track.size);
        _chalk.kick(o + TrackPainter.startLine * sc, count: 30, spread: 2.2, power: 1);
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _goLive();
    WidgetsBinding.instance.addPostFrameCallback((_) => Live.announce(context, 'The rest timer'));
  }

  /// Lock screen / status bar / Dynamic Island countdown, so the phone can go in a pocket.
  void _goLive() => Live.rest(
    end: _start.add(Duration(seconds: total)),
    exercise: widget.ex,
    next: widget.next,
  );

  @override
  void dispose() {
    _timer.cancel();
    Live.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final done = _left == 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: PageHeader('Rest', sub: widget.ex, close: true),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AspectRatio(
                key: _trackKey,
                aspectRatio: 402 / 250,
                child: Chalk(
                  controller: _chalk,
                  child: CustomPaint(
                    painter: TrackPainter(400 * (_elapsed / total).clamp(0, 1).toDouble(), t),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // the last three seconds drop in one by one, then GO lands
                          _left <= 3
                              ? CountdownDigit(
                                  left: _left,
                                  style: t.x(64, weight: FontWeight.w900),
                                  goStyle: t.x(64, weight: FontWeight.w900, color: t.accent),
                                )
                              : Odometer(
                                  text: clock(_left),
                                  style: t.x(56, weight: FontWeight.w900),
                                ),
                          const SizedBox(height: 8),
                          Text(done ? 'rest done' : 'of ${clock(total)} rest', style: t.meta()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Next · set ${widget.nextSet} of ${widget.sets}', style: t.meta()),
            const SizedBox(height: 6),
            Text(widget.next, style: t.x(24)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in const [-15, 15])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        total = (total + d).clamp(15, 600);
                        _buzzed = _left == 0 && _buzzed;
                        _goLive();
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.ink,
                        side: BorderSide(color: t.lane),
                        minimumSize: const Size(88, 44),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        d < 0 ? '−15 s' : '+15 s',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(label: 'Start set ${widget.nextSet}', onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Treadmill: live time against 25 min, speed and incline steppers, distance as laps of the track.
class TreadmillScreen extends StatefulWidget {
  const TreadmillScreen({super.key, required this.store});
  final Store store;
  @override
  State<TreadmillScreen> createState() => _TreadmillScreenState();
}

class _TreadmillScreenState extends State<TreadmillScreen> {
  final _watch = Stopwatch();
  Timer? _timer;
  Duration _lastTick = Duration.zero;
  double _meters = 0, _kcal = 0;

  Store get s => widget.store;

  /// ACSM walking equation (fine for treadmill walking and light jogging).
  /// VO2 (ml/kg/min) = 0.1·v + 1.8·v·grade + 3.5, v in m/min; kcal ≈ 5 per litre O2.
  double _kcalPerSecond() {
    final v = s.treadSpeed * 1000 / 60, grade = s.treadIncline / 100;
    return (0.1 * v + 1.8 * v * grade + 3.5) * s.bodyKg / 1000 * 5 / 60;
  }

  void _tick() {
    final now = _watch.elapsed, dt = (now - _lastTick).inMilliseconds / 1000;
    _lastTick = now;
    setState(() {
      _meters += s.treadSpeed / 3.6 * dt;
      _kcal += _kcalPerSecond() * dt;
    });
    if (now.inSeconds == cardioTargetMin * 60) HapticFeedback.vibrate();
    if (now.inSeconds % 15 == 0) _goLive(); // distance on the lock screen stays fresh
  }

  /// Elapsed clock ticks by itself from (now − elapsed); paused freezes it.
  void _goLive() => Live.treadmill(
    startedAt: DateTime.now().subtract(_watch.elapsed),
    paused: !_watch.isRunning,
    elapsedSeconds: _watch.elapsed.inSeconds,
    km: _meters / 1000,
    kcal: _kcal.round(),
  );

  void _toggle() {
    HapticFeedback.mediumImpact();
    if (_watch.isRunning) {
      _tick();
      _watch.stop();
      _timer?.cancel();
    } else {
      _watch.start();
      _lastTick = _watch.elapsed;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    _goLive();
    if (_watch.isRunning) Live.announce(context, 'The treadmill');
    setState(() {});
  }

  void _end() {
    if (_watch.isRunning) _tick();
    _watch.stop();
    _timer?.cancel();
    Live.end();
    if (_watch.elapsed.inSeconds >= 30) {
      s.addCardio(Cardio(_watch.elapsed.inSeconds, _meters / 1000, _kcal, s.treadSpeed, s.treadIncline));
      HapticFeedback.heavyImpact();
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    Live.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final secs = _watch.elapsed.inSeconds;
    final started = secs > 0 || _watch.isRunning;
    return PopScope(
      canPop: !started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end(); // back gesture while running: save and close
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: PageHeader(
                  'Treadmill',
                  sub: 'Cardio · optional, 20–30 min',
                  close: true,
                  onBack: started ? _end : () => Navigator.pop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AspectRatio(
                  aspectRatio: 402 / 250,
                  child: CustomPaint(
                    painter: TrackPainter(_meters % 400, t),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(clock(secs), style: t.x(52, weight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text('of ${clock(cardioTargetMin * 60)} · lap ${_meters ~/ 400 + 1}', style: t.meta()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _Stepper(
                      label: 'Speed',
                      sub: s.treadSpeed < 6.5 ? 'brisk walk' : 'jog',
                      value: s.treadSpeed.toStringAsFixed(1),
                      unit: 'km/h',
                      onMinus: () => setState(() => s.setTreadmill(speed: (s.treadSpeed - .1).clamp(1, 16))),
                      onPlus: () => setState(() => s.setTreadmill(speed: (s.treadSpeed + .1).clamp(1, 16))),
                    ),
                    _Stepper(
                      label: 'Incline',
                      sub: 'hills burn more',
                      value: s.treadIncline.toStringAsFixed(1).replaceFirst('.0', ''),
                      unit: '%',
                      onMinus: () => setState(() => s.setTreadmill(incline: (s.treadIncline - .5).clamp(0, 15))),
                      onPlus: () => setState(() => s.setTreadmill(incline: (s.treadIncline + .5).clamp(0, 15))),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.rule, width: .5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text((_meters / 1000).toStringAsFixed(2), style: t.x(28)),
                          Text(' km', style: t.meta()),
                          const Spacer(),
                          Text('≈ ${_kcal.round()} kcal · ${_meters ~/ 400} laps of 400 m', style: t.sec()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    if (started) ...[
                      IconButton.filledTonal(
                        onPressed: _toggle,
                        tooltip: _watch.isRunning ? 'Pause' : 'Start',
                        icon: Icon(_watch.isRunning ? Icons.pause : Icons.play_arrow, color: t.ink),
                        style: IconButton.styleFrom(
                          backgroundColor: t.ink.withValues(alpha: .18),
                          minimumSize: const Size(54, 54),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: started
                          ? Cta(label: 'End cardio', trailing: '${(secs / 60).round()} min', onTap: _end)
                          : Cta(
                              label: 'Start treadmill',
                              trailing: '${s.treadSpeed.toStringAsFixed(1)} km/h',
                              onTap: _toggle,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
