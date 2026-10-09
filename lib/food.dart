import 'package:flutter/material.dart';

import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show junkStatus;
import 'visuals.dart';

/// The food guide and the 10 non-negotiables, word for word from the old app.
class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    Widget chip(String s, {bool sometimes = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: t.lane, width: 1.5)),
      ),
      child: Text(sometimes ? '$s · sometimes' : s, style: t.sec(sometimes ? t.ink2 : t.ink)),
    );
    Widget h(String s) => Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 10),
      child: Text(s, style: t.title()),
    );
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(s, style: t.meta()),
    );

    return _Page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const PageHeader('Food guide', sub: 'What goes on the plate'),
          h('Rice is not banned.'),
          for (final (n, what, sub) in const [
            ('1', 'cup at lunch', 'cooked rice'),
            ('½', 'cup at dinner', 'only if you want it, instead of roti'),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 44, child: Text(n, style: t.x(28))),
              title: Text(what, style: t.body()),
              subtitle: Text(sub, style: t.meta()),
            ),
          const Tip(Icons.block_rounded, 'No second serving'),
          label('Fish'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final f in fish) chip(f), for (final f in fishSometimes) chip(f, sometimes: true)],
          ),
          label('Vegetables'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final v in vegetables) chip(v)]),
          const SizedBox(height: 20),
          const Tip(Icons.soup_kitchen_outlined, 'Dal: ½ cup'),
          const Tip(Icons.opacity_rounded, 'Oil: measure it · the biggest hidden calories'),
          h('Junk food: keep it rare'),
          for (final e in keepRare.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    switch (e.key) {
                      'Fried' => Icons.local_fire_department_outlined,
                      'Fast food' => Icons.fastfood_outlined,
                      'Heavy Bengali' => Icons.rice_bowl_outlined,
                      'Drinks' => Icons.local_drink_outlined,
                      _ => Icons.cookie_outlined,
                    },
                    size: 20,
                    color: t.ink,
                  ),
                  const SizedBox(width: 8),
                  Text(e.key, style: t.meta()),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final f in e.value.split(', ')) chip(f[0].toUpperCase() + f.substring(1))],
            ),
          ],
          h('The junk-food rule'),
          Builder(
            builder: (_) {
              final (title, sub) = junkStatus(store);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body()),
                    Text('Week ${store.cutWeek} · $sub', style: t.meta()),
                  ],
                ),
              );
            },
          ),
          const Tip(Icons.calendar_month_outlined, 'Month 1: keep it to a minimum'),
          const Tip(Icons.lunch_dining_outlined, 'Then 1 a week: 1 burger, 2 pizza slices or a small biryani'),
          const Tip(Icons.do_not_disturb_on_outlined, 'Never a whole cheat day'),
        ],
      ),
    );
  }
}

/// The plan's 10 non-negotiables, opened from the drawer.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return _Page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const PageHeader('The 10 rules', sub: 'Twelve weeks of these, not one perfect day'),
          const SizedBox(height: 12),
          for (final (i, r) in rules.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 44,
                child: Text('${i + 1}', style: t.x(22, color: t.ink2)),
              ),
              title: Text(r, style: t.body()),
            ),
          const SizedBox(height: 8),
          const Tip(Icons.egg_alt_outlined, 'Enough protein, real food'),
          const Tip(Icons.no_food_outlined, 'Not as little as possible'),
          const Tip(Icons.bedtime_outlined, 'Short sleep = more hunger'),
        ],
      ),
    );
  }
}

/// A page opened from the drawer: own scaffold, back arrow top-left.
class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: child));
}
