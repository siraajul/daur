import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'cloud.dart';
import 'plan.dart' show Meal;
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta;
import 'visuals.dart';

// A diet helper's page (a mother who cooks): what to cook today from the trainer's chart, did he
// eat, water, weight, and one-tap replies. Bangla by default, big text, nothing to learn.

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Digits in the page's language: ২ বেলা in Bangla, 2 in English.
String bnNum(Object v, bool bn) =>
    bn ? '$v'.split('').map((c) => int.tryParse(c) == null ? c : _bnDigits[int.parse(c)]).join() : '$v';

const _mealBn = {'m1': 'সকালের নাশতা', 'm2': 'দুপুরের খাবার', 'm3': 'বিকেলের নাস্তা', 'm4': 'রাতের খাবার'};

/// One-tap replies a mother sends most: (Bangla, English).
const _replies = [
  ('খুব ভালো', 'Well done'),
  ('সময়মতো খেয়ে নাও', 'Eat on time'),
  ('ভাত কম খাও', 'Less rice'),
  ('পানি খাও', 'Drink water'),
  ('একটু হাঁটো', 'Go for a walk'),
  ('তাড়াতাড়ি ঘুমাও', 'Sleep early'),
];

class MaPage extends StatefulWidget {
  const MaPage({super.key, required this.owner, required this.name, required this.store});
  final String owner, name;
  final Store store;
  @override
  State<MaPage> createState() => _MaPageState();
}

class _MaPageState extends State<MaPage> {
  final Map<String, int> _picked = {}; // swaps sent, shown at once while his phone catches up

  Future<void> _change(BuildContext context, Meal m, int current, bool bn) async {
    final t = Daur.of(context);
    final i = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              bn ? '${_mealBn[m.id]} · কী রান্না করবেন?' : '${m.name} · what will you cook?',
              style: t.x(18, color: t.sheetRed),
            ),
            const SizedBox(height: 8),
            for (final (j, o) in m.options.indexed)
              Material(
                color: j == current ? t.sheetRule : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(ctx, j),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          j == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: t.sheetRed,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: t.body(color: t.sheetInk).copyWith(fontSize: 20)),
                              Text(o.items.join(' · '), style: t.sec(t.sheetInk2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (i == null || i == current) return;
    HapticFeedback.mediumImpact();
    setState(() => _picked[m.id] = i);
    final msg = await Cloud.instance.pickToCook(widget.owner, m.id, i);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg ?? (bn ? 'পাঠানো হয়েছে · ${m.options[i].name}' : 'Sent · ${m.options[i].name}'))),
    );
  }

  Future<void> _send(BuildContext context, String text, bool bn) async {
    HapticFeedback.lightImpact();
    final msg = await Cloud.instance.addNote(widget.owner, text, 'diet');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? (bn ? 'পাঠানো হয়েছে' : 'Sent'))));
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store, bn = s.helperLang == 'bn';
        String tr(String b, String e) => bn ? b : e;
        final first = widget.name.split(' ').first;
        return Scaffold(
          body: SafeArea(
            child: StreamBuilder(
              stream: Cloud.instance.progress(widget.owner),
              builder: (context, snap) {
                final p = snap.data;
                final d = p?.data ?? const <String, dynamic>{};
                final meals = (d['meals'] as List? ?? const []).cast<Map>();
                final chart = [for (final m in (d['chart'] as List? ?? const [])) Meal.from(m as Map)];
                final eaten = meals.where((m) => m['status'] == 'done').length;
                final today = d['day'] == dayKey(DateTime.now());
                final chartAt = d['chartAt'] as String? ?? '';
                final changes = (d['chartChanges'] as List? ?? const []).cast<String>();
                final newChart = chartAt.isNotEmpty && chartAt.compareTo(s.chartSeen[widget.owner] ?? '') > 0;
                final water = (d['water'] as num?)?.toInt() ?? 0, waterGoal = (d['waterGoal'] as num?)?.toInt() ?? 15;
                final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.maybePop(context),
                            icon: Icon(Icons.arrow_back, color: t.ink),
                          ),
                        Expanded(child: Text(first, style: t.title())),
                        // the language switch: one tap, says what it switches to
                        OutlinedButton(
                          onPressed: () => s.setHelperLang(bn ? 'en' : 'bn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.ink,
                            side: BorderSide(color: t.lane),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(bn ? 'English' : 'বাংলা'),
                        ),
                      ],
                    ),
                    if (p == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: snap.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator.adaptive())
                            : Tip(
                                Icons.schedule_rounded,
                                tr('$first Daur খুললেই এখানে দেখাবে', 'Shows up once $first opens Daur'),
                              ),
                      ),
                    if (p != null) ...[
                      if (!today)
                        Tip(
                          Icons.history_rounded,
                          tr('$first আজ এখনো Daur খোলেনি', '$first hasn\'t opened Daur today'),
                        ),
                      // a new chart from the trainer: what changed, until she says she's seen it
                      if (newChart)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(18)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  'নতুন ডায়েট চার্ট · ${d['chartBy'] ?? ''}',
                                  'New diet chart · ${d['chartBy'] ?? ''}',
                                ),
                                style: t.body(color: t.onAccent).copyWith(fontSize: 19),
                              ),
                              for (final c in changes.take(5)) Text('· $c', style: t.sec(t.onAccent)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => s.seeChart(widget.owner, chartAt),
                                  child: Text(tr('দেখেছি', 'Seen it'), style: t.body(color: t.onAccent)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // one plain sentence, then the four meals as big circles
                      Text(
                        tr(
                          '$first আজ ${bnNum(4, true)} বেলার ${bnNum(eaten, true)} বেলা খেয়েছে',
                          '$first has eaten $eaten of 4 meals today',
                        ),
                        style: t.x(24, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (final m in meals)
                            Expanded(
                              child: Column(
                                children: [
                                  Icon(
                                    m['status'] == 'done'
                                        ? Icons.check_circle_rounded
                                        : m['status'] == 'skipped'
                                        ? Icons.remove_circle_outline_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 44,
                                    color: m['status'] == 'next' ? t.accent : t.ink,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bn ? (_mealBn.values.elementAt(meals.indexOf(m))).split(' ').first : '${m['name']}',
                                    style: t.sec(t.ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(tr('আজ কী রান্না', 'What to cook today'), style: t.x(22)),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'ট্রেইনারের চার্ট থেকে · বদলাতে চাইলে চাপুন',
                          'From the trainer\'s chart · tap Change to swap',
                        ),
                        style: t.sec(),
                      ),
                      for (final (i, m) in meals.indexed)
                        if (i < chart.length)
                          _CookCard(
                            mealName: bn ? _mealBn[chart[i].id]! : chart[i].name,
                            window: m['window'] as String? ?? '',
                            meal: chart[i],
                            option: _picked[chart[i].id] ?? (m['option'] as num?)?.toInt() ?? 0,
                            status: m['status'] as String? ?? 'todo',
                            ate: m['food'] as String? ?? '',
                            time: m['time'] as String?,
                            bn: bn,
                            onChange: () => _change(
                              context,
                              chart[i],
                              _picked[chart[i].id] ?? (m['option'] as num?)?.toInt() ?? 0,
                              bn,
                            ),
                          ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _WholeChart(name: first, chart: chart, bn: bn),
                          ),
                        ),
                        icon: Icon(Icons.menu_book_rounded, color: t.ink),
                        label: Text(tr('পুরো চার্ট দেখুন', 'See the whole chart'), style: t.body()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: BorderSide(color: t.lane, width: 1.5),
                          shape: const StadiumBorder(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // water as glasses, weight in one sentence
                      Text(
                        tr(
                          'পানি · ${bnNum(waterGoal, true)} গ্লাসের ${bnNum(water, true)} গ্লাস',
                          'Water · $water of $waterGoal glasses',
                        ),
                        style: t.body().copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < waterGoal; i++)
                            Container(
                              width: 18,
                              height: 26,
                              decoration: BoxDecoration(
                                color: i < water ? t.ink : null,
                                border: Border.all(color: i < water ? t.ink : t.lane, width: 1.5),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                  bottom: Radius.circular(6),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (now != null && start != null) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              now <= start ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                              color: t.accent,
                              size: 36,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr(
                                  'শুরুর চেয়ে ${bnNum((now - start).abs().toStringAsFixed(1), true)} কেজি ${now <= start ? 'কম' : 'বেশি'}',
                                  '${(now - start).abs().toStringAsFixed(1)} kg ${now <= start ? 'less' : 'more'} than at the start',
                                ),
                                style: t.body().copyWith(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 28),
                    // replies without typing: one tap sends
                    Text(tr('$first-কে বলুন', 'Tell $first'), style: t.x(22)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (b, e) in _replies)
                          ActionChip(
                            label: Text(bn ? b : e, style: t.body(color: t.onAccent)),
                            backgroundColor: t.accent,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            onPressed: () => _send(context, bn ? b : e, bn),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          if (await confirmPop(
                            context,
                            tr('$first-কে আর দেখবেন না?', 'Stop helping $first?'),
                            tr('আর তার খাবার দেখতে পাবেন না।', 'You stop seeing their meals.'),
                            tr('বন্ধ করুন', 'Stop'),
                            destructive: true,
                          )) {
                            await Cloud.instance.leaveHelping(widget.owner);
                            if (context.mounted) Navigator.maybePop(context);
                          }
                        },
                        child: Text(tr('দেখা বন্ধ করুন', 'Stop helping'), style: t.sec()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One meal to cook: what's planned (with amounts) or what was eaten, and a big Change button.
class _CookCard extends StatelessWidget {
  const _CookCard({
    required this.mealName,
    required this.window,
    required this.meal,
    required this.option,
    required this.status,
    required this.ate,
    required this.time,
    required this.bn,
    required this.onChange,
  });
  final String mealName, window, status, ate;
  final String? time;
  final Meal meal;
  final int option;
  final bool bn;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final o = meal.options[option.clamp(0, meal.options.length - 1)];
    final eaten = status == 'done';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(mealName, style: t.body().copyWith(fontSize: 20))),
              Text(
                eaten ? (bn ? 'খেয়েছে ${bnNum(time ?? '', true)}' : 'Eaten ${time ?? ''}') : window,
                style: t.sec(t.ink),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (eaten)
            Text(ate, style: t.body(weight: FontWeight.w500))
          else ...[
            Text(o.name, style: t.x(18)),
            const SizedBox(height: 4),
            for (final item in o.items)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('· $item', style: t.body(weight: FontWeight.w500).copyWith(fontSize: 18)),
              ),
            if (meal.options.length > 1) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(bn ? 'বদলান' : 'Change', style: const TextStyle(fontSize: 17)),
                style: FilledButton.styleFrom(
                  backgroundColor: t.ink,
                  foregroundColor: t.ground,
                  minimumSize: const Size(140, 48),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The whole chart: every meal and its options with amounts, and Share (WhatsApp, print).
class _WholeChart extends StatelessWidget {
  const _WholeChart({required this.name, required this.chart, required this.bn});
  final String name;
  final List<Meal> chart;
  final bool bn;

  String get _text => [
    bn ? '$name-এর ডায়েট চার্ট' : '$name\'s diet chart',
    for (final m in chart) ...[
      '',
      '${bn ? _mealBn[m.id] : m.name} (${m.window})',
      for (final (i, o) in m.options.indexed) ...[
        '${i == 0
            ? ''
            : bn
            ? 'অথবা: '
            : 'or: '}${o.name}',
        for (final item in o.items) '  · $item',
      ],
    ],
  ].join('\n');

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
                  PageHeader(bn ? 'পুরো চার্ট' : 'Whole chart', sub: name),
                  for (final m in chart) ...[
                    const SizedBox(height: 20),
                    Text('${bn ? _mealBn[m.id] : m.name} · ${m.window}', style: t.x(18)),
                    for (final (i, o) in m.options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i == 0
                                  ? ''
                                  : bn
                                  ? 'অথবা · '
                                  : 'or · '}${o.name}',
                              style: t.body().copyWith(fontSize: 19),
                            ),
                            for (final item in o.items) Text('· $item', style: t.body(weight: FontWeight.w400)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(
                label: bn ? 'শেয়ার করুন · WhatsApp, প্রিন্ট' : 'Share · WhatsApp, print',
                onTap: () => SharePlus.instance.share(ShareParams(text: _text)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
