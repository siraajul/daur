import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';
import 'cloud.dart';
import 'gym.dart' show dayIcon, kgText, planText;
import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta;
import 'visuals.dart';
import 'workout.dart' show NumberStepper;

/// A workout: each split day's exercises and their plans, in order.
typedef Workout = Map<String, List<(String, ExPlan)>>;

/// From [Store.workout]'s JSON shape (days of [name, sets, reps, kg, timed]).
Workout workoutFrom(Map w) => {
  for (final d in Store.splitDays)
    d: [
      for (final x in w[d] as List? ?? const [])
        (
          x[0] as String,
          ExPlan((x[1] as num).toInt(), (x[2] as num).toInt(), (x[3] as num).toDouble(), timed: x[4] == true),
        ),
    ],
};

Map<String, List<List<Object>>> workoutJson(Workout w) => {
  for (final e in w.entries)
    e.key: [
      for (final (n, p) in e.value) [n, p.sets, p.reps, p.kg, p.timed],
    ],
};

/// What changed between two workouts, in words ("Push: Dips added", "Legs: Leg press 4 × 10 · 130 kg").
List<String> workoutChanges(Workout before, Workout after) {
  bool same(ExPlan a, ExPlan b) => a.sets == b.sets && a.reps == b.reps && a.kg == b.kg && a.timed == b.timed;
  final out = <String>[];
  for (final d in Store.splitDays) {
    final b = {for (final (n, p) in before[d] ?? const <(String, ExPlan)>[]) n: p};
    final a = {for (final (n, p) in after[d] ?? const <(String, ExPlan)>[]) n: p};
    for (final n in a.keys) {
      if (!b.containsKey(n)) {
        out.add('$d: $n added');
      } else if (!same(b[n]!, a[n]!)) {
        out.add('$d: $n ${planText(a[n]!)}');
      }
    }
    for (final n in b.keys) {
      if (!a.containsKey(n)) out.add('$d: $n removed');
    }
  }
  return out;
}

/// The trainer writes someone's workout: push / pull / legs, each exercise's sets, reps and kg.
/// It lands on their phone with Undo, and their plans step up from there as usual.
class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({super.key, required this.owner, required this.ownerName, required this.initial});
  final String owner, ownerName;
  final Workout initial;
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  late final Workout _w = {
    for (final d in Store.splitDays) d: [...?widget.initial[d]],
  };
  String _day = Store.splitDays.first;
  bool _saving = false;

  List<String> get _changes => workoutChanges(widget.initial, _w);

  Future<void> _edit([int? i]) async {
    final list = _w[_day]!;
    final name = i == null ? '' : list[i].$1;
    final r = await Navigator.push<(String, String, ExPlan)>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ExerciseEdit(
          day: _day,
          name: name,
          plan: i == null ? newExercisePlan : list[i].$2,
          taken: {
            for (final l in _w.values)
              for (final (n, _) in l)
                if (n != name) n.toLowerCase(),
          },
        ),
      ),
    );
    if (r == null) return;
    final (day, n, p) = r;
    setState(() {
      if (i != null) list.removeAt(i);
      i != null && day == _day ? list.insert(i, (n, p)) : _w[day]!.add((n, p));
    });
  }

  Future<void> _send() async {
    setState(() => _saving = true);
    final msg = await Cloud.instance.saveWorkout(widget.owner, workoutJson(_w), _changes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to ${widget.ownerName}')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final changes = _changes, list = _w[_day]!;
    final empty = _w.values.every((l) => l.isEmpty);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  PageHeader('Workout', sub: widget.ownerName),
                  const SizedBox(height: 12),
                  Segments<String>(
                    items: [for (final d in Store.splitDays) (d, '$d · ${_w[d]!.length}', dayIcon(d))],
                    value: _day,
                    onChanged: (d) => setState(() => _day = d),
                  ),
                  const SizedBox(height: 12),
                  for (final (i, (n, p)) in list.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: t.infield,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _edit(i),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n, style: t.body()),
                                      Text(planText(p), style: t.meta()),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove $n',
                                  icon: Icon(Icons.close_rounded, color: t.ink2),
                                  onPressed: () => setState(() => list.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nothing on $_day day yet.', style: t.sec()),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _edit,
                      icon: Icon(Icons.add_rounded, color: t.accent),
                      label: Text('Exercise on $_day day', style: t.sec(t.accent)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(
                label: changes.isEmpty ? 'No changes yet' : 'Send to ${widget.ownerName.split(' ').first}',
                trailing: changes.isEmpty ? null : '${changes.length} ${changes.length == 1 ? 'change' : 'changes'}',
                muted: changes.isEmpty || empty,
                onTap: changes.isEmpty || empty || _saving ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One exercise: its name, day, sets, and reps (or seconds for a hold) and kg.
class _ExerciseEdit extends StatefulWidget {
  const _ExerciseEdit({required this.day, required this.name, required this.plan, required this.taken});
  final String day, name;
  final ExPlan plan;
  final Set<String> taken; // other exercises' names, lower case
  @override
  State<_ExerciseEdit> createState() => _ExerciseEditState();
}

class _ExerciseEditState extends State<_ExerciseEdit> {
  late final _name = TextEditingController(text: widget.name);
  late String _day = widget.day;
  late int _sets = widget.plan.sets, _reps = widget.plan.reps;
  late double _kg = widget.plan.kg;
  late bool _timed = widget.plan.timed;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final n = _name.text.trim();
    if (n.isEmpty) return setState(() => _error = 'Give it a name');
    if (widget.taken.contains(n.toLowerCase())) return setState(() => _error = '$n is already in the workout');
    Navigator.pop(context, (_day, n, ExPlan(_sets, _reps, _timed ? 0.0 : _kg, timed: _timed)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  PageHeader(widget.name.isEmpty ? 'New exercise' : widget.name, close: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    autofocus: widget.name.isEmpty,
                    maxLength: 60,
                    style: t.body(weight: FontWeight.w400),
                    textCapitalization: TextCapitalization.sentences,
                    // a new hold (plank, wall sit) counts seconds, like the gym list does
                    onChanged: widget.name.isEmpty
                        ? (v) {
                            final p = planForNew(v);
                            if (p.timed != _timed) {
                              setState(() {
                                _timed = p.timed;
                                _reps = p.reps;
                              });
                            }
                          }
                        : null,
                    decoration: InputDecoration(
                      hintText: 'Name, e.g. Incline dumbbell press',
                      hintStyle: t.sec(),
                      counterText: '',
                      errorText: _error,
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.ink)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Segments<String>(
                    items: [for (final d in Store.splitDays) (d, d, dayIcon(d))],
                    value: _day,
                    onChanged: (d) => setState(() => _day = d),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('A hold, in seconds', style: t.body()),
                    subtitle: Text('plank, wall sit, dead hang', style: t.meta()),
                    value: _timed,
                    onChanged: (v) => setState(() {
                      _timed = v;
                      _reps = v ? 30 : 10;
                    }),
                  ),
                  NumberStepper(
                    label: 'Sets',
                    sub: 'rest $restSeconds s between',
                    value: '$_sets',
                    onMinus: () => setState(() => _sets = (_sets - 1).clamp(1, 10)),
                    onPlus: () => setState(() => _sets = (_sets + 1).clamp(1, 10)),
                  ),
                  NumberStepper(
                    label: _timed ? 'Seconds' : 'Reps',
                    sub: _timed ? '5 s steps' : 'each set',
                    value: '$_reps',
                    onMinus: () => setState(() => _reps = (_reps - (_timed ? 5 : 1)).clamp(1, 600)),
                    onPlus: () => setState(() => _reps = (_reps + (_timed ? 5 : 1)).clamp(1, 600)),
                  ),
                  if (!_timed)
                    NumberStepper(
                      label: 'Weight',
                      sub: _kg == 0 ? 'bodyweight' : '2.5 kg steps',
                      value: kgText(_kg),
                      unit: 'kg',
                      onMinus: () => setState(() => _kg = (_kg - 2.5).clamp(0, 500)),
                      onPlus: () => setState(() => _kg = (_kg + 2.5).clamp(0, 500)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(
                label: 'Done',
                trailing: planText(ExPlan(_sets, _reps, _timed ? 0 : _kg, timed: _timed)),
                onTap: _done,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
