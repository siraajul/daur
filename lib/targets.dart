import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'visuals.dart';
import 'today.dart' show thousands;
import 'water_walk.dart' show litres;

// Height is said in feet and inches in Bangladesh; the maths stays in cm. Stepping by an inch
// round-trips exactly (rounding error under half an inch).
int cmToInches(int cm) => (cm / 2.54).round();
int inchesToCm(int inches) => (inches * 2.54).round();
String feetInches(int cm) => "${cmToInches(cm) ~/ 12}′ ${cmToInches(cm) % 12}″";

/// A choice chip on the red ground: light outline, runner yellow when picked (the default chip
/// colours are meant for light surfaces and go dark-on-red here).
Widget groundChip(BuildContext context, String label, bool selected, VoidCallback onTap) {
  final t = Daur.of(context);
  return ChoiceChip(
    label: Text(
      label,
      style: TextStyle(color: selected ? t.onAccent : t.ink, fontWeight: FontWeight.w600),
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: t.accent,
    backgroundColor: Colors.transparent,
    checkmarkColor: t.onAccent,
    side: BorderSide(color: selected ? t.accent : t.lane, width: 1.5),
    shape: const StadiumBorder(),
  );
}

/// Sex, age, height, activity: what a personal plan is computed from (plan.dart, Profile).
class ProfileFields extends StatelessWidget {
  const ProfileFields({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  Profile _with({bool? male, int? age, int? heightCm, int? activity}) => Profile(
    male: male ?? value.male,
    age: (age ?? value.age).clamp(14, 90),
    heightCm: (heightCm ?? value.heightCm).clamp(120, 220),
    activity: activity ?? value.activity,
  );

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    void set(Profile p) {
      HapticFeedback.selectionClick();
      onChanged(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final m in const [true, false])
              groundChip(context, m ? 'Man' : 'Woman', value.male == m, () => set(_with(male: m))),
          ],
        ),
        _Step(
          label: 'Age',
          value: '${value.age}',
          onMinus: () => set(_with(age: value.age - 1)),
          onPlus: () => set(_with(age: value.age + 1)),
        ),
        _Step(
          label: 'Height',
          value: feetInches(value.heightCm),
          onMinus: () => set(_with(heightCm: inchesToCm(cmToInches(value.heightCm) - 1))),
          onPlus: () => set(_with(heightCm: inchesToCm(cmToInches(value.heightCm) + 1))),
        ),
        const SizedBox(height: 8),
        Text('Day to day', style: t.meta()),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final (i, name) in Profile.activityNames.indexed)
              groundChip(context, name, value.activity == i, () => set(_with(activity: i))),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.value, required this.onMinus, required this.onPlus});
  final String label, value;
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    Widget b(IconData i, VoidCallback f) => GestureDetector(
      onLongPress: () {
        for (var k = 0; k < 5; k++) {
          f();
        }
      },
      child: IconButton(
        tooltip: '${i == Icons.add ? 'More' : 'Less'} ${label.toLowerCase()}',
        onPressed: f,
        icon: Icon(i, color: t.ink),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.body(weight: FontWeight.w400)),
          ),
          b(Icons.remove, onMinus),
          SizedBox(
            width: 112,
            child: Text(value, textAlign: TextAlign.center, maxLines: 1, style: t.x(20)),
          ),
          b(Icons.add, onPlus),
        ],
      ),
    );
  }
}

/// Drawer → Your targets: what the day aims for, and the body details behind it.
class TargetsScreen extends StatefulWidget {
  const TargetsScreen({super.key, required this.store});
  final Store store;
  @override
  State<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends State<TargetsScreen> {
  late Profile? _p = widget.store.profile;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const PageHeader('Your targets'),
              const SizedBox(height: 16),

              for (final (icon, a, b) in [
                (Icons.local_fire_department_rounded, 'Calories', '${thousands(s.kcalGoal)} kcal'),
                (Icons.egg_alt_outlined, 'Protein', '${s.proteinText} g'),
                (Icons.water_drop_outlined, 'Water', '${litres(s.waterGoal)} L'),
                (Icons.directions_walk_rounded, 'Steps', '7k → 10k'),
                (Icons.fitness_center_rounded, 'Gym', '3–5 a week'),
                (Icons.bedtime_outlined, 'Sleep', '7–8 h'),
                for (final (name, range, _) in s.targets) (Icons.flag_outlined, name, '$range kg'),
              ])
                Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.rule, width: .5)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: t.ink2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a, style: t.body(weight: FontWeight.w400)),
                      ),
                      Text(b, style: t.x(17)),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              if (_p == null) ...[
                Text('The original plan', style: t.title()),
                const SizedBox(height: 8),
                Text('Written for a 109 kg start', style: t.sec()),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.onAccent,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    const p = Profile(male: true, age: 30, heightCm: 170);
                    setState(() => _p = p);
                    s.setProfile(p);
                  },
                  child: const Text('Personalise'),
                ),
              ] else ...[
                Text('About you', style: t.title()),
                const SizedBox(height: 4),
                Text('~0.5 kg a week · follows your trend, now ${s.planKg.toStringAsFixed(1)} kg', style: t.sec()),
                const SizedBox(height: 12),
                ProfileFields(
                  value: _p!,
                  onChanged: (p) {
                    setState(() => _p = p);
                    s.setProfile(p);
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    setState(() => _p = null);
                    s.setProfile(null);
                  },
                  child: Text('Use the original 1,800 kcal plan', style: t.sec(t.ink)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
