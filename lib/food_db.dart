import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'food_search.dart';
import 'foods.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show thousands;
import 'visuals.dart';

/// Food database (drawer): browse by category tiles, then roomy food tiles with an icon, kcal and
/// a "share of the day" bar. Tap a food for its detail: add it to today, or edit it if it's yours.
class FoodDbScreen extends StatefulWidget {
  const FoodDbScreen({super.key, required this.store});
  final Store store;
  @override
  State<FoodDbScreen> createState() => _FoodDbScreenState();
}

enum _Sort { light, protein, az }

/// One row of the database, researched or yours.
class _Item {
  final String name, sub, cat;
  final int kcal, protein;
  final bool rare;
  final Eaten? mine; // non-null for your own foods
  const _Item(this.name, this.sub, this.cat, this.kcal, this.protein, this.rare, [this.mine]);
  static _Item of(Food f) => _Item(f.name, f.portion, f.cat, f.kcal, f.protein, f.rare);
  static _Item yours(Eaten e) => _Item(e.name, e.portion, e.cat, e.kcal, e.protein, e.rare, e);
}

class _FoodDbScreenState extends State<FoodDbScreen> {
  final _search = TextEditingController();
  String? _cat; // null = browse tiles, 'mine' = yours only, else a category key
  _Sort _sort = _Sort.light;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store;
        final q = _search.text.trim().toLowerCase();
        final browsing = q.isEmpty && _cat == null;
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          browsing ? 'Food database' : _title(q),
                          onBack: () =>
                              _cat != null && q.isEmpty ? setState(() => _cat = null) : Navigator.pop(context),
                          actions: [
                            IconButton.filledTonal(
                              onPressed: () => editFood(context, s),
                              icon: Icon(Icons.add, color: t.ink),
                              tooltip: 'Add your own food',
                              style: IconButton.styleFrom(backgroundColor: t.ink.withValues(alpha: .18)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Stat(Icons.restaurant_menu_rounded, '${foods.length + s.customFoods.length} foods'),
                            const SizedBox(width: 14),
                            Stat(Icons.local_fire_department_outlined, 'kcal per serving'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _searchBox(t),
                      ],
                    ),
                  ),
                ),
                if (browsing) ..._browse(t, s) else ..._list(t, s, q),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _title(String q) => q.isNotEmpty
      ? 'Results'
      : _cat == 'mine'
      ? 'Your foods'
      : foodCategories.where((c) => c.$1 == _cat).firstOrNull?.$2 ?? 'Foods';

  Widget _searchBox(Daur t) => TextField(
    controller: _search,
    onChanged: (_) => setState(() {}),
    style: t.body(weight: FontWeight.w400),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search in English or বাংলা',
      hintStyle: t.sec(),
      prefixIcon: Icon(Icons.search_rounded, color: t.ink2),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              icon: Icon(Icons.close_rounded, color: t.ink2),
              tooltip: 'Clear',
              onPressed: () => setState(_search.clear),
            ),
      filled: true,
      fillColor: t.infield,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
    ),
  );

  // ---- browse: category tiles ----

  List<Widget> _browse(Daur t, Store s) {
    final tiles = <(String, String, int, int, int)>[
      if (s.customFoods.isNotEmpty) ('mine', 'Yours', s.customFoods.length, 0, 0),
      for (final (k, label) in foodCategories) (k, label, foods.where((f) => f.cat == k).length, _min(k), _max(k)),
    ];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 148,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, i) {
            final (k, label, n, lo, hi) = tiles[i];
            return Material(
              color: t.infield,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _cat = k);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(categoryIcon(k), size: 34, color: t.ink),
                      const Spacer(),
                      Text(label, style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Stat(Icons.restaurant_menu_rounded, k == 'mine' ? '$n added' : '$n · $lo–$hi kcal', size: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  int _min(String k) => foods.where((f) => f.cat == k).map((f) => f.kcal).fold(1 << 30, (a, b) => b < a ? b : a);
  int _max(String k) => foods.where((f) => f.cat == k).map((f) => f.kcal).fold(0, (a, b) => b > a ? b : a);

  // ---- list: roomy food tiles ----

  List<Widget> _list(Daur t, Store s, String q) {
    bool hit(String name) => q.isEmpty || foodMatches(name, '', q);
    final items = <_Item>[
      for (final e in s.customFoods)
        if (hit(e.name) && (q.isNotEmpty || _cat == 'mine' || e.cat == _cat)) _Item.yours(e),
      // foods the AI estimated, under the category it picked (editable like your own)
      for (final e in s.aiFoods)
        if (!s.customFoods.any((c) => c.name == e.name) && hit(e.name) && (q.isNotEmpty || e.cat == _cat))
          _Item.yours(e),
      if (_cat != 'mine')
        for (final f in foods)
          if ((q.isNotEmpty && f.matches(q)) || (q.isEmpty && f.cat == _cat)) _Item.of(f),
    ];
    items.sort(switch (_sort) {
      _Sort.light => (a, b) => a.kcal.compareTo(b.kcal),
      _Sort.protein => (a, b) => b.protein.compareTo(a.protein),
      _Sort.az => (a, b) => a.name.compareTo(b.name),
    });

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Text('${items.length} foods', style: t.meta()),
              const Spacer(),
              SegmentedButton<_Sort>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Sort.light,
                    icon: Icon(Icons.local_fire_department_outlined),
                    tooltip: 'Lightest first',
                  ),
                  ButtonSegment(
                    value: _Sort.protein,
                    icon: Icon(Icons.fitness_center_rounded),
                    tooltip: 'Most protein first',
                  ),
                  ButtonSegment(value: _Sort.az, icon: Icon(Icons.sort_by_alpha_rounded), tooltip: 'A to Z'),
                ],
                selected: {_sort},
                onSelectionChanged: (v) => setState(() => _sort = v.first),
                style: SegmentedButton.styleFrom(
                  foregroundColor: t.ink,
                  selectedForegroundColor: t.onAccent,
                  selectedBackgroundColor: t.accent,
                  side: BorderSide(color: t.lane),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
      if (items.isEmpty)
        SliverToBoxAdapter(child: _empty(t, s, q))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _FoodTile(item: items[i], goal: s.kcalGoal, onTap: () => _detail(context, s, items[i])),
          ),
        ),
    ];
  }

  Widget _empty(Daur t, Store s, String q) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
    child: Column(
      children: [
        Icon(Icons.no_food_outlined, size: 56, color: t.ink2),
        const SizedBox(height: 12),
        Text(q.isEmpty ? 'Nothing here yet' : 'No "${_search.text.trim()}" yet', style: t.body()),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => editFood(context, s, name: _search.text.trim()),
          icon: Icon(Icons.add, color: t.onAccent),
          label: Text(
            'Add it with its kcal',
            style: TextStyle(color: t.onAccent, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    ),
  );

  Future<void> _detail(BuildContext context, Store s, _Item f) => showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final t = Daur.of(ctx);
      final share = f.kcal / s.kcalGoal;
      final ratio = f.kcal == 0 ? 0.0 : f.protein / f.kcal * 100;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconDisc(foodIcon(f.name, f.cat), size: 64, onSheet: true, rare: f.rare),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: t.body(color: t.sheetInk)),
                        if (f.sub.isNotEmpty) Text(f.sub, style: t.sec(t.sheetInk2)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _bigStat(t, Icons.local_fire_department_outlined, thousands(f.kcal), 'kcal'),
                  _bigStat(t, Icons.fitness_center_rounded, '${f.protein}', 'g protein'),
                  _bigStat(t, Icons.pie_chart_outline_rounded, '${(share * 100).round()}%', 'of your day'),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: share.clamp(0, 1).toDouble(),
                  minHeight: 10,
                  backgroundColor: t.sheetRule,
                  color: share > .4 ? t.sheetRed : t.sheetInk,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ratio >= 8) _chip(t, Icons.thumb_up_alt_outlined, 'High protein for the kcal'),
                  if (f.rare) _chip(t, Icons.local_fire_department_rounded, 'Junk food · counts to the junk rule'),
                  if (f.mine != null) _chip(t, Icons.edit_note_rounded, 'Your food'),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (f.mine != null) ...[
                    IconButton.outlined(
                      tooltip: 'Delete',
                      onPressed: () {
                        Navigator.pop(ctx);
                        s.removeCustomFood(f.name);
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: t.sheetInk),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.pop(ctx);
                        editFood(context, s, existing: f.mine);
                      },
                      icon: Icon(Icons.edit_outlined, color: t.sheetInk),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        s.addExtras([Eaten(f.name, f.kcal, f.protein, rare: f.rare, portion: f.sub, cat: f.cat)]);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('${f.name} added to today · ${f.kcal} kcal'),
                            ),
                          );
                      },
                      icon: Icon(Icons.add_rounded, color: t.onAccent),
                      label: Text(
                        'Add to today',
                        style: TextStyle(color: t.onAccent, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.accent,
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _bigStat(Daur t, IconData icon, String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: t.sheetInk2, size: 20),
        const SizedBox(height: 6),
        Text(value, style: t.x(24, color: t.sheetInk)),
        Text(label, style: t.meta(t.sheetInk2)),
      ],
    ),
  );

  Widget _chip(Daur t, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: t.sheetRule, borderRadius: BorderRadius.circular(99)),
    child: Stat(icon, text, color: t.sheetInk),
  );
}

/// A roomy food tile: icon disc, name and serving, a "share of the day" bar, kcal on the right.
class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.item, required this.goal, required this.onTap});
  final _Item item;
  final int goal; // the day's kcal, for the share-of-day bar
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final f = item;
    final share = (f.kcal / goal).clamp(0, 1).toDouble();
    return Material(
      color: t.infield.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              IconDisc(foodIcon(f.name, f.cat), size: 48, rare: f.rare),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(f.sub, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: share,
                              minHeight: 5,
                              backgroundColor: t.faint,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Stat(Icons.fitness_center_rounded, '${f.protein} g', size: 12),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(thousands(f.kcal), style: t.x(20)),
                  const SizedBox(height: 2),
                  Text('kcal', style: t.meta()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add or edit one of your foods. Shared by the database screen and the meal sheet.
/// Returns the saved food, or null if cancelled.
Future<Eaten?> editFood(BuildContext context, Store s, {Eaten? existing, String name = ''}) =>
    showModalBottomSheet<Eaten>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FoodForm(store: s, existing: existing, name: name),
    );

class _FoodForm extends StatefulWidget {
  const _FoodForm({required this.store, this.existing, this.name = ''});
  final Store store;
  final Eaten? existing;
  final String name;
  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.name);
  late final _portion = TextEditingController(text: widget.existing?.portion ?? '');
  late final _kcal = TextEditingController(text: widget.existing?.kcal.toString() ?? '');
  late final _protein = TextEditingController(
    text: widget.existing == null || widget.existing!.protein == 0 ? '' : widget.existing!.protein.toString(),
  );
  late String _cat = widget.existing?.cat ?? '';
  late bool _rare = widget.existing?.rare ?? false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _portion, _kcal, _protein]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final kcal = int.tryParse(_kcal.text.trim());
    if (name.isEmpty) return setState(() => _error = 'Give it a name');
    if (kcal == null || kcal <= 0 || kcal > 3000) return setState(() => _error = 'kcal per serving, 1–3000');
    final clash =
        foods.any((f) => f.name.toLowerCase() == name.toLowerCase()) ||
        widget.store.customFoods.any(
          (c) => c.name.toLowerCase() == name.toLowerCase() && c.name != widget.existing?.name,
        );
    if (clash) return setState(() => _error = 'A food called "$name" exists already');
    final e = Eaten(
      name,
      kcal,
      int.tryParse(_protein.text.trim()) ?? 0,
      rare: _rare,
      portion: _portion.text.trim(),
      cat: _cat,
    );
    widget.store.saveCustomFood(e, replacing: widget.existing?.name);
    HapticFeedback.mediumImpact();
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    InputDecoration dec(String label, {String? hint, String? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      labelStyle: t.sec(t.sheetInk2),
      hintStyle: t.sec(t.sheetInk2),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.sheetRule)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.sheetInk)),
    );
    final style = t.body(color: t.sheetInk, weight: FontWeight.w400);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add a food' : 'Edit food', style: t.title(t.sheetInk)),
            const SizedBox(height: 4),
            Text('Per serving, the way you usually eat it.', style: t.sec(t.sheetInk2)),
            TextField(
              controller: _name,
              autofocus: widget.existing == null && widget.name.isEmpty,
              style: style,
              textCapitalization: TextCapitalization.sentences,
              decoration: dec('Name', hint: 'e.g. Beef khichuri'),
            ),
            TextField(
              controller: _portion,
              style: style,
              decoration: dec('Serving', hint: 'e.g. 1 plate, 1 piece, 1 cup'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kcal,
                    style: style,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dec('kcal', suffix: 'kcal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _protein,
                    style: style,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dec('Protein (optional)', suffix: 'g'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Category', style: t.meta(t.sheetInk2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label) in foodCategories)
                  ChoiceChip(
                    label: Text(label),
                    selected: _cat == key,
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _cat = v ? key : ''),
                    selectedColor: t.accent,
                    backgroundColor: t.sheet,
                    side: BorderSide(color: t.sheetRule),
                    labelStyle: TextStyle(color: _cat == key ? t.onAccent : t.sheetInk, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _rare,
              onChanged: (v) => setState(() => _rare = v),
              title: Text('Junk food', style: t.body(color: t.sheetInk)),
              subtitle: Text(
                'Fried, fast food, sweets, sugary drinks: counts toward the junk rule',
                style: t.meta(t.sheetInk2),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: t.sec(t.sheetRed)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  widget.existing == null ? 'Add food' : 'Save',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
