import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';
import 'food_db.dart' show editFood;
import 'food_search.dart';
import 'foods.dart';
import 'plan.dart';
import 'meal_ai.dart';
import 'store.dart';
import 'theme.dart';
import 'visuals.dart';
import 'today.dart' show Cta, thousands, junkStatus;

/// Opens the logging sheet for [meal], or for an extra between meals when [meal] is null.
/// Returns a short message for the undo snackbar, or null if nothing changed.
Future<String?> showMealSheet(BuildContext context, Store store, {Meal? meal, int n = 0}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MealSheet(store: store, meal: meal, n: n),
    );

enum _Mode { plan, other }

const _portions = [.5, 1.0, 1.5, 2.0];
String qtyText(double q) => q == .5
    ? '½'
    : q == 1.5
    ? '1½'
    : q == q.roundToDouble()
    ? '${q.toInt()}'
    : '$q';

class MealSheet extends StatefulWidget {
  const MealSheet({super.key, required this.store, this.meal, this.n = 0});
  final Store store;
  final Meal? meal;
  final int n;
  @override
  State<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<MealSheet> {
  Store get s => widget.store;
  Meal? get m => widget.meal;
  bool get isExtra => m == null;
  bool get logged => m != null && s.done.containsKey(m!.id);

  late _Mode mode = isExtra || s.ateOther(m!) ? _Mode.other : _Mode.plan;
  late int opt = m == null ? 0 : m!.options.indexOf(s.chosen(m!)); // the same option Today shows
  late double portion = m == null ? 1 : s.portionOf(m!);
  late final List<Eaten> plate = [...?s.other[m?.id]];
  final _search = TextEditingController();
  final _searchKey = GlobalKey();
  String? _cat; // category chip; ignored while typing (search looks everywhere)
  String get query => _search.text;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadAiLeft();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get selKcal => mode == _Mode.plan
      ? (s.optKcal(m!, m!.options[opt]) * portion).round()
      : plate.fold(0, (a, e) => a + e.totalKcal);
  int get selProtein => mode == _Mode.plan
      ? (s.optProtein(m!, m!.options[opt]) * portion).round()
      : plate.fold(0, (a, e) => a + e.totalProtein);

  /// Logging this selection makes a new junk meal (a keep-rare food where there wasn't one).
  bool get addsJunk => mode == _Mode.other && plate.any((e) => e.rare) && !(m != null && s.mealRare(m!));

  /// The day's totals if this selection is logged (replacing what this meal counted before).
  (int, int) get after {
    final prevK = logged ? s.mealKcal(m!) : 0, prevP = logged ? s.mealProtein(m!) : 0;
    return (s.kcal - prevK + selKcal, s.protein - prevP + selProtein);
  }

  void _add(Eaten e) {
    HapticFeedback.selectionClick();
    setState(() {
      final i = plate.indexWhere((p) => p.name == e.name);
      i < 0 ? plate.add(e) : plate[i] = plate[i].withQty(plate[i].qty + 1);
    });
  }

  bool _aiBusy = false;
  int? _aiLeft; // free AI estimates left today for the whole project (null while loading)

  Future<void> _loadAiLeft() async {
    final n = await MealAi.left(s);
    if (mounted) setState(() => _aiLeft = n);
  }

  Future<void> _estimate(String text) async {
    setState(() => _aiBusy = true);
    try {
      final items = await MealAi.estimate(text, s);
      if (!mounted) return;
      setState(() {
        for (final e in items) {
          final i = plate.indexWhere((p) => p.name == e.name);
          i < 0 ? plate.add(e) : plate[i] = plate[i].withQty(plate[i].qty + e.qty);
        }
        _search.clear();
      });
      HapticFeedback.mediumImpact();
      if (items.isEmpty) _say('Couldn\'t find food in that. Try "2 parathas and an egg".');
    } on AiQuotaGone {
      _say('Today\'s free AI estimates are used up. Back at ${MealAi.resetsAt()}.');
    } catch (e) {
      debugPrint('MealAi: $e');
      _say('AI estimate unavailable right now. Search the list instead.');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
      _loadAiLeft();
    }
  }

  void _say(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));

  Widget _aiRow(Daur t, String text) {
    final saved = s.hasEstimate(text); // estimated before: reused, no AI
    return InkWell(
      onTap: _aiBusy || (_aiLeft == 0 && !saved) ? null : () => _estimate(text),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
              child: _aiBusy
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(t.onAccent),
                      ),
                    )
                  : Icon(saved ? Icons.bookmark_rounded : Icons.auto_awesome_rounded, color: t.onAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _aiBusy
                        ? 'Estimating…'
                        : saved
                        ? 'Use saved estimate for “$text”'
                        : 'Estimate “$text”',
                    style: t.body(color: t.sheetInk),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    saved
                        ? 'Saved earlier · no AI used'
                        : switch (_aiLeft) {
                            null => 'AI · check the numbers before logging',
                            0 => 'Free AI used up today · back at ${MealAi.resetsAt()}',
                            final n => 'AI · $n left today · check the numbers',
                          },
                    style: t.meta(t.sheetInk2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setQty(int i, double q) => setState(() => q <= 0 ? plate.removeAt(i) : plate[i] = plate[i].withQty(q));

  Future<void> _custom() async {
    final e = await editFood(context, s, name: query.trim());
    if (e == null) return;
    _add(e);
    setState(_search.clear);
  }

  void _log() {
    HapticFeedback.mediumImpact();
    if (isExtra) {
      s.addExtras(List.of(plate));
      Navigator.pop(context, 'Extra added · $selKcal kcal');
      return;
    }
    final wasLogged = logged;
    if (mode == _Mode.plan) {
      s.choose(m!, opt);
      s.logMeal(m!, portionX: portion);
    } else {
      s.logMeal(m!, instead: List.of(plate));
    }
    Navigator.pop(context, '${m!.name} ${wasLogged ? 'updated' : 'logged'} · $selKcal kcal');
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final (aK, aP) = after;
    final over = aK - s.kcalGoal;
    final canLog = mode == _Mode.plan || plate.isNotEmpty;
    final name = isExtra ? 'extra' : m!.name.toLowerCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        maxChildSize: .96,
        minChildSize: .5,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  // header
                  if (!isExtra) Text('Meal ${widget.n ~/ 100} of 4', style: t.sec(t.sheetRed)),
                  Text(isExtra ? 'Extra' : m!.name, style: t.title(t.sheetInk)),
                  Text(isExtra ? 'Between meals · counts to the day' : m!.window, style: t.sec(t.sheetInk2)),
                  const SizedBox(height: 16),
                  // impact before logging
                  Text.rich(
                    TextSpan(
                      style: t.sec(t.sheetInk2),
                      children: [
                        const TextSpan(text: 'Today after this: '),
                        TextSpan(
                          text: '${thousands(aK)} of ${thousands(s.kcalGoal)} kcal',
                          style: TextStyle(color: over > 0 ? t.sheetRed : t.sheetInk, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' · $aP g protein${over > 0 ? ' · over by ${thousands(over)}' : ''}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (aK / s.kcalGoal).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: t.sheetRule,
                      color: over > 0 ? t.sheetRed : t.sheetInk,
                    ),
                  ),
                  if (addsJunk) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.fastfood_outlined, size: 18, color: t.sheetRed),
                        const SizedBox(width: 8),
                        Expanded(child: Text(junkStatus(s, adding: 1).$1, style: t.sec(t.sheetRed))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!isExtra)
                    Segments<_Mode>(
                      onSheet: true,
                      items: const [
                        (_Mode.plan, 'Planned', Icons.check_circle_outline),
                        (_Mode.other, 'Something else', Icons.swap_horiz),
                      ],
                      value: mode,
                      onChanged: (v) => setState(() => mode = v),
                    ),
                  const SizedBox(height: 12),
                  ...(mode == _Mode.plan ? _planned(t) : _other(t)),
                ],
              ),
            ),
            // actions stay in the thumb zone
            Container(
              decoration: BoxDecoration(
                color: t.sheet,
                border: Border(top: BorderSide(color: t.sheetRule)),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mode == _Mode.other && plate.isNotEmpty) _plate(t),
                  Cta(
                    label: !canLog
                        ? 'Pick what you ate'
                        : isExtra
                        ? 'Add extra'
                        : logged
                        ? 'Update $name'
                        : 'Log $name',
                    trailing: canLog ? '$selKcal kcal' : null,
                    muted: !canLog,
                    onDark: false,
                    onTap: canLog ? _log : null,
                  ),
                  if (!isExtra && MediaQuery.viewInsetsOf(context).bottom == 0)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final msg = logged ? '${m!.name} cleared' : '${m!.name} skipped';
                        logged ? s.unlogMeal(m!) : s.skipMeal(m!);
                        Navigator.pop(context, msg);
                      },
                      child: Text(logged ? 'Clear $name' : 'Skip $name', style: t.sec(t.sheetInk2)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _planned(Daur t) => [
    for (final (i, o) in m!.options.indexed)
      InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => opt = i);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // the option's food icon; a check badge marks the chosen one
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconDisc(foodIcon(o.name), size: 40, onSheet: true),
                  if (i == opt)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        decoration: BoxDecoration(color: t.sheet, shape: BoxShape.circle),
                        child: Icon(Icons.check_circle, color: t.sheetRed, size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.name, style: t.body(color: t.sheetInk)),
                    if (i == opt) Text(o.items.join(' · '), style: t.sec(t.sheetInk2)),
                    // the menu is written for 1,800 kcal; a personal plan eats more or less of it
                    if (i == opt && (s.mealScale(m!) - 1).abs() >= .05)
                      Text('Your portion: ${(s.mealScale(m!) * 100).round()}% of this', style: t.meta(t.sheetRed)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(s.optKcal(m!, o) * (i == opt ? portion : 1)).round()} kcal', style: t.sec(t.sheetInk)),
                  Text(
                    '${(s.optProtein(m!, o) * (i == opt ? portion : 1)).round()} g protein',
                    style: t.meta(t.sheetInk2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 8),
    Text('How much?', style: t.meta(t.sheetInk2)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        for (final p in _portions)
          ChoiceChip(
            label: Text(p == 1 ? 'As planned' : '${qtyText(p)}×'),
            selected: portion == p,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => portion = p);
            },
            selectedColor: t.accent,
            labelStyle: TextStyle(color: portion == p ? t.onAccent : t.sheetInk, fontWeight: FontWeight.w600),
            backgroundColor: t.sheet,
            side: BorderSide(color: t.sheetRule),
          ),
      ],
    ),
    if (m!.note.isNotEmpty) ...[
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, size: 18, color: t.sheetRed),
          const SizedBox(width: 8),
          Expanded(child: Text(m!.note, style: t.sec(t.sheetInk2))),
        ],
      ),
    ],
  ];

  List<Widget> _other(Daur t) {
    final q = query.trim().toLowerCase();
    final mine = [
      ...s.customFoods,
      ...s.recentFoods
          .where((r) => !s.customFoods.any((c) => c.name == r))
          .map((r) => foods.where((f) => f.name == r).map(Eaten.of).firstOrNull)
          .whereType<Eaten>(),
    ];
    final list = foods.where((f) => q.isEmpty ? (_cat == null || f.cat == _cat) : f.matches(q)).map(Eaten.of).toList();
    // foods the AI estimated before are searchable too: no AI the second time
    list.addAll(
      s.aiFoods.where(
        (e) =>
            (q.isNotEmpty ? foodMatches(e.name, '', q) : _cat != null && e.cat == _cat) &&
            !list.any((f) => f.name == e.name),
      ),
    );
    final mineFiltered = _cat != null && q.isEmpty
        ? s.customFoods.where((e) => e.cat == _cat).toList()
        : mine.where((f) => q.isEmpty || foodMatches(f.name, '', q)).toList();

    Widget row(Eaten e, {String? portionText}) {
      final inPlate = plate.where((p) => p.name == e.name).firstOrNull;
      return InkWell(
        onTap: () => _add(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              IconDisc(foodIcon(e.name, e.cat), size: 40, onSheet: true, rare: e.rare),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: t.body(color: t.sheetInk, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 10,
                      children: [
                        Text(portionText ?? 'portion', style: t.meta(t.sheetInk2)),
                        Stat(Icons.local_fire_department_outlined, '${e.kcal}', color: t.sheetInk2, size: 12),
                        Stat(Icons.fitness_center_rounded, '${e.protein} g', color: t.sheetInk2, size: 12),
                      ],
                    ),
                  ],
                ),
              ),
              if (inPlate != null)
                Text('${qtyText(inPlate.qty)}×', style: t.body(color: t.sheetRed))
              else
                Icon(Icons.add_circle_outline, color: t.sheetInk2),
            ],
          ),
        ),
      );
    }

    String portionOf(Eaten e) =>
        e.portion.isNotEmpty ? e.portion : foods.where((f) => f.name == e.name).firstOrNull?.portion ?? 'your portion';

    return [
      TextField(
        key: _searchKey,
        controller: _search,
        // bring the search box to the top so results get the room above the keyboard
        onTap: () => Future.delayed(const Duration(milliseconds: 350), () {
          final c = _searchKey.currentContext;
          if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250));
        }),
        onChanged: (_) => setState(() {}),
        style: t.body(color: t.sheetInk, weight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: 'Search, e.g. biryani, beef, singara',
          hintStyle: t.sec(t.sheetInk2),
          prefixIcon: Icon(Icons.search, color: t.sheetInk2),
          filled: true,
          fillColor: t.sheetRule.withValues(alpha: .5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      // describe it instead of searching: AI splits it into items with kcal and protein
      if (query.trim().length >= 3 && !kIsWeb) _aiRow(t, query.trim()),
      if (q.isEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (key, label) in [(null, 'All'), ...foodCategories])
                if (key == null || foods.any((f) => f.cat == key))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: key == null
                          ? null
                          : Icon(categoryIcon(key), size: 18, color: _cat == key ? t.onAccent : t.sheetInk),
                      label: Text(label),
                      selected: _cat == key,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _cat = key);
                      },
                      selectedColor: t.accent,
                      labelStyle: TextStyle(color: _cat == key ? t.onAccent : t.sheetInk, fontWeight: FontWeight.w600),
                      backgroundColor: t.sheet,
                      side: BorderSide(color: t.sheetRule),
                      showCheckmark: false,
                    ),
                  ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (mineFiltered.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Yours and recent', style: t.meta(t.sheetInk2)),
        ),
        for (final e in mineFiltered) row(e, portionText: portionOf(e)),
        Divider(color: t.sheetRule),
      ],
      for (final e in list.where((e) => !mineFiltered.any((x) => x.name == e.name))) row(e, portionText: portionOf(e)),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.edit_note, color: t.sheetRed),
        title: Text(
          q.isEmpty ? 'Add a custom food' : 'Add “${query.trim()}” as a custom food',
          style: t.body(color: t.sheetRed),
        ),
        subtitle: Text('Name and kcal; it stays in "Yours" next time', style: t.meta(t.sheetInk2)),
        onTap: _custom,
      ),
    ];
  }
}

extension on _MealSheetState {
  /// What's on the plate, pinned above the button so the food list never jumps.
  Widget _plate(Daur t) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 168),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final (i, e) in plate.indexed)
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: e.name,
                        style: t.body(color: t.sheetInk),
                      ),
                      TextSpan(text: '  ${e.totalKcal} kcal', style: t.meta(t.sheetInk2)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => _setQty(i, e.qty - .5),
                icon: Icon(Icons.remove_circle_outline, color: t.sheetInk),
                tooltip: 'Less',
              ),
              SizedBox(
                width: 32,
                child: Text(
                  qtyText(e.qty),
                  textAlign: TextAlign.center,
                  style: t.x(17, color: t.sheetInk),
                ),
              ),
              IconButton(
                onPressed: () => _setQty(i, e.qty + .5),
                icon: Icon(Icons.add_circle_outline, color: t.sheetInk),
                tooltip: 'More',
              ),
            ],
          ),
      ],
    ),
  );
}
