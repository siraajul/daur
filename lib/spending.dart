import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'theme.dart';
import 'visuals.dart';
import 'today.dart' show Cta, niceDate, thousands, undoToast;

/// What the diet and gym cost, by category. Taka, whole numbers.
const spendCats = <(String, String, IconData)>[
  ('food', 'Groceries', Icons.shopping_basket_outlined),
  ('out', 'Eating out', Icons.restaurant_outlined),
  ('gym', 'Gym', Icons.fitness_center_rounded),
  ('supp', 'Supplements', Icons.science_outlined),
  ('gear', 'Gear', Icons.directions_run_rounded),
  ('health', 'Health', Icons.medical_services_outlined),
  ('other', 'Other', Icons.more_horiz_rounded),
];
(String, String, IconData) spendCat(String id) => spendCats.firstWhere((c) => c.$1 == id, orElse: () => spendCats.last);
String taka(int n) => '৳${thousands(n)}';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Drawer → Spending: the month's total against a budget, where it went, and every entry.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key, required this.store});
  final Store store;
  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String get _key => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  bool get _thisMonth => _month.year == DateTime.now().year && _month.month == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store;
        final list = s.expensesIn(_key);
        final total = s.spentIn(_key);
        final cats = s.byCategory(_key).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = cats.isEmpty ? 1 : cats.first.value;
        final days = _thisMonth ? DateTime.now().day : DateUtils.getDaysInMonth(_month.year, _month.month);
        final budget = s.monthBudget;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const PageHeader('Spending'),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                            icon: Icon(Icons.chevron_left_rounded, color: t.ink),
                          ),
                          Expanded(
                            child: Text(
                              '${_months[_month.month - 1]} ${_month.year}',
                              textAlign: TextAlign.center,
                              style: t.sec(t.ink),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: _thisMonth
                                ? null
                                : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                            icon: Icon(Icons.chevron_right_rounded, color: _thisMonth ? t.faint : t.ink),
                          ),
                        ],
                      ),
                      Text(taka(total), style: t.x(56, weight: FontWeight.w900)),
                      Text(total == 0 ? 'Nothing logged yet' : '${taka(total ~/ days)} a day', style: t.sec()),
                      const SizedBox(height: 16),
                      // the budget, as a bar; tap to set or change it
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _editBudget(context, s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: budget == null
                              ? Row(
                                  children: [
                                    Icon(Icons.savings_outlined, color: t.ink),
                                    const SizedBox(width: 10),
                                    Text('Set a monthly budget', style: t.body()),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.savings_outlined, size: 18, color: t.ink),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            total <= budget
                                                ? '${taka(budget - total)} left of ${taka(budget)}'
                                                : '${taka(total - budget)} over ${taka(budget)}',
                                            style: t.body(),
                                          ),
                                        ),
                                        Icon(Icons.edit_outlined, size: 18, color: t.ink2),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (total / budget).clamp(0, 1).toDouble(),
                                        minHeight: 8,
                                        color: total > budget ? t.accent : t.ink,
                                        backgroundColor: t.lane.withValues(alpha: .35),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (cats.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        for (final c in cats)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(spendCat(c.key).$3, size: 20, color: t.ink),
                                const SizedBox(width: 10),
                                SizedBox(width: 96, child: Text(spendCat(c.key).$2, style: t.sec(t.ink))),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: c.value / top,
                                      minHeight: 10,
                                      color: t.ink,
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(taka(c.value), style: t.x(14)),
                              ],
                            ),
                          ),
                      ],
                      if (list.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        for (final e in list)
                          Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: t.rule, width: .5)),
                            ),
                            child: Row(
                              children: [
                                Icon(spendCat(e.cat).$3, size: 20, color: t.ink2),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.note.isEmpty ? spendCat(e.cat).$2 : e.note,
                                        style: t.body(weight: FontWeight.w400),
                                      ),
                                      Text(niceDate(DateTime.parse(e.day)), style: t.meta()),
                                    ],
                                  ),
                                ),
                                Text(taka(e.taka), style: t.x(15)),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: Icon(Icons.close_rounded, size: 20, color: t.ink2),
                                  onPressed: () {
                                    final snap = s.snapshot();
                                    s.removeExpense(e);
                                    undoToast(context, '${taka(e.taka)} deleted', () => s.restore(snap));
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Cta(label: 'Add an expense', onTap: () => addExpense(context, s)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editBudget(BuildContext context, Store s) async {
    final c = TextEditingController(text: s.monthBudget?.toString() ?? '');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '৳ ', hintText: 'e.g. 15000'),
        ),
        actions: [
          if (s.monthBudget != null) TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: const Text('Save')),
        ],
      ),
    );
    if (v != null) s.setBudget(v);
  }
}

/// The add sheet: amount, category, an optional note, today or yesterday.
Future<void> addExpense(BuildContext context, Store s) async {
  final amount = TextEditingController(), note = TextEditingController();
  var cat = 'food';
  var daysAgo = 0;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final t = Daur.of(ctx);
        final v = int.tryParse(amount.text) ?? 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add an expense', style: t.title(t.sheetInk)),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: t.x(36, color: t.sheetInk),
                decoration: InputDecoration(
                  prefixText: '৳ ',
                  prefixStyle: t.x(36, color: t.sheetInk2),
                  hintText: '0',
                  border: InputBorder.none,
                ),
                onChanged: (_) => set(() {}),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (id, name, icon) in spendCats)
                    _chip(t, name, cat == id, () => set(() => cat = id), icon: icon),
                ],
              ),
              TextField(
                controller: note,
                style: t.body(color: t.sheetInk),
                decoration: const InputDecoration(hintText: 'Note (optional), e.g. whey 2 lb'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (d, label) in const [(0, 'Today'), (1, 'Yesterday')])
                    _chip(t, label, daysAgo == d, () => set(() => daysAgo = d)),
                ],
              ),
              const SizedBox(height: 16),
              Cta(
                label: 'Save',
                trailing: v > 0 ? taka(v) : null,
                muted: v <= 0,
                onTap: v <= 0
                    ? null
                    : () {
                        final n = DateTime.now();
                        s.addExpense(
                          Expense(dayKey(DateTime(n.year, n.month, n.day - daysAgo)), v, cat, note.text.trim()),
                        );
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                      },
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// A chip on the light sheet: ink outline, runner yellow when picked.
Widget _chip(Daur t, String label, bool on, VoidCallback onTap, {IconData? icon}) => ChoiceChip(
  avatar: icon == null ? null : Icon(icon, size: 18, color: on ? t.onAccent : t.sheetInk),
  label: Text(
    label,
    style: TextStyle(color: on ? t.onAccent : t.sheetInk, fontWeight: FontWeight.w600),
  ),
  selected: on,
  showCheckmark: false,
  onSelected: (_) => onTap(),
  selectedColor: t.accent,
  backgroundColor: t.sheet,
  side: BorderSide(color: on ? t.accent : t.sheetInk2.withValues(alpha: .5), width: 1.5),
  shape: const StadiumBorder(),
);
