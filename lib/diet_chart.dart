import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cloud.dart';
import 'meal_ai.dart';
import 'plan.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, thousands;
import 'visuals.dart';

/// What changed between two charts, in words ("Lunch: Beef + rice added"), for the people who
/// follow it. Same four meals in the same order on both sides.
List<String> chartChanges(List<Meal> before, List<Meal> after) {
  final out = <String>[];
  for (var i = 0; i < after.length && i < before.length; i++) {
    final b = before[i], a = after[i];
    final bn = {for (final o in b.options) o.name: o}, an = {for (final o in a.options) o.name: o};
    for (final n in an.keys) {
      final was = bn[n];
      if (was == null) {
        out.add('${a.name}: $n added');
      } else if (was.kcal != an[n]!.kcal ||
          was.protein != an[n]!.protein ||
          was.items.join('|') != an[n]!.items.join('|')) {
        out.add('${a.name}: $n changed');
      }
    }
    for (final n in bn.keys) {
      if (!an.containsKey(n)) out.add('${a.name}: $n removed');
    }
    if (a.note != b.note) out.add('${a.name}: note changed');
  }
  return out;
}

/// The trainer writes someone's diet chart: each meal's options, with what's in them and how
/// much. A typical day (each meal's first option) is totalled against their target.
class DietChartEditor extends StatefulWidget {
  const DietChartEditor({
    super.key,
    required this.owner,
    required this.ownerName,
    required this.initial,
    required this.kcalGoal,
    required this.store,
  });
  final String owner, ownerName;
  final List<Meal> initial;
  final int kcalGoal;
  final Store store;
  @override
  State<DietChartEditor> createState() => _DietChartEditorState();
}

class _DietChartEditorState extends State<DietChartEditor> {
  late final List<Meal> _chart = [...widget.initial];
  bool _saving = false;

  List<String> get _changes => chartChanges(widget.initial, _chart);

  void _setOptions(int meal, List<MealOption> options) =>
      setState(() => _chart[meal] = _chart[meal].withOptions(options));

  Future<void> _edit(int meal, [int? index]) async {
    final m = _chart[meal];
    final edited = await showModalBottomSheet<MealOption?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OptionSheet(meal: m.name, initial: index == null ? null : m.options[index], store: widget.store),
    );
    if (edited == null) return;
    final opts = [...m.options];
    index == null ? opts.add(edited) : opts[index] = edited;
    _setOptions(meal, opts);
  }

  Future<void> _send() async {
    setState(() => _saving = true);
    final msg = await Cloud.instance.saveChart(widget.owner, _chart, _changes);
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
    final day = _chart.fold(0, (a, m) => a + (m.options.isEmpty ? 0 : m.options.first.kcal));
    final changes = _changes;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  PageHeader('Diet chart', sub: widget.ownerName),
                  const SizedBox(height: 12),
                  // a typical day (each meal's first option) against their target
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant_menu_rounded, color: t.ink),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Typical day', style: t.body())),
                        Text('${thousands(day)} of ${thousands(widget.kcalGoal)} kcal', style: t.x(15)),
                      ],
                    ),
                  ),
                  for (final (i, m) in _chart.indexed) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Icon(mealIcon(m.id), size: 20, color: t.ink),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${m.name} · ${m.window}', style: t.body())),
                        TextButton.icon(
                          onPressed: () => _edit(i),
                          icon: Icon(Icons.add_rounded, color: t.accent),
                          label: Text('Option', style: t.sec(t.accent)),
                        ),
                      ],
                    ),
                    for (final (j, o) in m.options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: t.infield,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _edit(i, j),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(o.name, style: t.body()),
                                        const SizedBox(height: 2),
                                        for (final item in o.items) Text('· $item', style: t.meta(t.ink)),
                                        const SizedBox(height: 4),
                                        Text('${o.kcal} kcal · ${o.protein} g protein', style: t.meta()),
                                      ],
                                    ),
                                  ),
                                  if (m.options.length > 1)
                                    IconButton(
                                      tooltip: 'Remove ${o.name}',
                                      icon: Icon(Icons.close_rounded, color: t.ink2),
                                      onPressed: () => _setOptions(i, [...m.options]..removeAt(j)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(
                label: changes.isEmpty ? 'No changes yet' : 'Send to ${widget.ownerName.split(' ').first}',
                trailing: changes.isEmpty ? null : '${changes.length} ${changes.length == 1 ? 'change' : 'changes'}',
                muted: changes.isEmpty,
                onTap: changes.isEmpty || _saving ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One option of a meal: its name, what's in it with amounts (one per line), kcal and protein.
/// The AI estimate fills kcal and protein from the lines.
class _OptionSheet extends StatefulWidget {
  const _OptionSheet({required this.meal, required this.initial, required this.store});
  final String meal;
  final MealOption? initial;
  final Store store;
  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _items = TextEditingController(text: widget.initial?.items.join('\n') ?? '');
  late final _kcal = TextEditingController(text: widget.initial?.kcal.toString() ?? '');
  late final _protein = TextEditingController(text: widget.initial?.protein.toString() ?? '');
  bool _estimating = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _items, _kcal, _protein]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _lines => [
    for (final l in _items.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  Future<void> _estimate() async {
    setState(() {
      _estimating = true;
      _error = null;
    });
    try {
      final foods = await MealAi.estimate(_lines.join(', '), widget.store);
      _kcal.text = '${foods.fold(0, (a, f) => a + f.totalKcal)}';
      _protein.text = '${foods.fold(0, (a, f) => a + f.totalProtein)}';
    } catch (e) {
      _error = e is AiQuotaGone ? 'The free AI is used up for today: type kcal and protein' : 'Couldn\'t estimate: $e';
    }
    if (mounted) setState(() => _estimating = false);
  }

  void _save() {
    final kcal = int.tryParse(_kcal.text.trim()), protein = int.tryParse(_protein.text.trim());
    if (_name.text.trim().isEmpty || _lines.isEmpty || kcal == null || protein == null) {
      setState(() => _error = 'Give it a name, what\'s in it, kcal and protein');
      return;
    }
    Navigator.pop(context, MealOption(_name.text.trim(), _lines, kcal, protein));
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    InputDecoration deco(String label, [String? hint]) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: t.sec(t.sheetInk2),
      hintStyle: t.sec(t.sheetInk2),
    );
    final style = t.body(color: t.sheetInk, weight: FontWeight.w500);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.meal, style: t.x(20, color: t.sheetRed)),
          const SizedBox(height: 8),
          TextField(controller: _name, style: style, decoration: deco('Name', 'e.g. Chicken + rice')),
          const SizedBox(height: 8),
          TextField(
            controller: _items,
            style: style,
            minLines: 3,
            maxLines: 8,
            decoration: deco('What\'s in it, one per line', '1 cup cooked rice\n180 g chicken\nSalad'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kcal,
                  style: style,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: deco('kcal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _protein,
                  style: style,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: deco('protein g'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _estimating || _lines.isEmpty ? null : _estimate,
                icon: _estimating
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                    : Icon(Icons.auto_awesome_rounded, color: t.sheetRed),
                label: Text('Estimate', style: t.sec(t.sheetRed)),
              ),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: t.sec(t.sheetRed))],
          const SizedBox(height: 12),
          Cta(label: 'Done', onDark: false, onTap: _save),
        ],
      ),
    );
  }
}
