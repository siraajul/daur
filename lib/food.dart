import 'package:flutter/material.dart';

import 'adaptive.dart';
import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show junkStatus;
import 'visuals.dart';

/// The food guide in three tabs: what goes on the plate, the 10 rules, and junk food.
class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key, required this.store});
  final Store store;
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  var _tab = 'Plate';

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const PageHeader('Food guide'),
            const SizedBox(height: 14),
            Segments<String>(
              items: const [
                ('Plate', 'Plate', Icons.rice_bowl_outlined),
                ('Rules', 'Rules', Icons.checklist_rounded),
                ('Junk', 'Junk', Icons.fastfood_outlined),
              ],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 24),
            ...switch (_tab) {
              'Plate' => _plate(t),
              'Rules' => _rules(t),
              _ => _junk(t),
            },
          ],
        ),
      ),
    );
  }

  Widget _chip(Daur t, String s, {bool sometimes = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: t.lane, width: 1.5)),
    ),
    child: Text(sometimes ? '$s · sometimes' : s, style: t.sec(sometimes ? t.ink2 : t.ink)),
  );

  Widget _label(Daur t, String s, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: t.ink),
        const SizedBox(width: 8),
        Text(s, style: t.meta()),
      ],
    ),
  );

  /// Big number tiles side by side: "1 cup at lunch", "½ cup at dinner".
  Widget _tiles(Daur t, List<(String, String, String)> items) => Row(
    children: [
      for (final (i, (n, what, sub)) in items.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n, style: t.x(32, weight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(what, style: t.body()),
                Text(sub, style: t.meta(), maxLines: 2),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  List<Widget> _plate(Daur t) => [
    _label(t, 'Rice is not banned', Icons.rice_bowl_outlined),
    _tiles(t, [('1', 'cup at lunch', 'cooked rice'), ('½', 'cup at dinner', 'or roti instead')]),
    const SizedBox(height: 8),
    _tiles(t, [('½', 'cup of dal', 'per meal'), ('1', 'serving', 'no second plate')]),
    const SizedBox(height: 4),
    const Tip(Icons.opacity_rounded, 'Measure the oil: the biggest hidden calories'),
    _label(t, 'Fish', Icons.set_meal_outlined),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final f in fish) _chip(t, f), for (final f in fishSometimes) _chip(t, f, sometimes: true)],
    ),
    _label(t, 'Vegetables', Icons.eco_outlined),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final v in vegetables) _chip(t, v)]),
  ];

  List<Widget> _rules(Daur t) => [
    for (final (i, r) in rules.indexed)
      Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.rule, width: .5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text('${i + 1}', style: t.x(20, color: t.ink2)),
            ),
            Expanded(child: Text(r, style: t.body())),
          ],
        ),
      ),
    const SizedBox(height: 16),
    const Tip(Icons.calendar_month_outlined, 'Twelve weeks of these, not one perfect day'),
    const Tip(Icons.egg_alt_outlined, 'Enough protein, real food'),
    const Tip(Icons.no_food_outlined, 'Not as little as possible'),
  ];

  List<Widget> _junk(Daur t) {
    final s = widget.store;
    final (title, sub) = junkStatus(s);
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: t.ink, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.body()),
                  Text('Week ${s.cutWeek} · $sub', style: t.meta()),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Tip(Icons.calendar_month_outlined, 'Month 1: keep it to a minimum'),
      const Tip(Icons.lunch_dining_outlined, 'Then 1 a week: a burger, 2 pizza slices or a small biryani'),
      const Tip(Icons.do_not_disturb_on_outlined, 'Never a whole cheat day'),
      for (final e in keepRare.entries) ...[
        _label(t, e.key, switch (e.key) {
          'Fried' => Icons.local_fire_department_outlined,
          'Fast food' => Icons.fastfood_outlined,
          'Heavy Bengali' => Icons.rice_bowl_outlined,
          'Drinks' => Icons.local_drink_outlined,
          _ => Icons.cookie_outlined,
        }),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final f in e.value.split(', ')) _chip(t, f[0].toUpperCase() + f.substring(1))],
        ),
      ],
    ];
  }
}
