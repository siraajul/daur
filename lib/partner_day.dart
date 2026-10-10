import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity_anim.dart';
import 'cloud.dart';
import 'coaching.dart' show NotesThread, ago;
import 'store.dart';
import 'theme.dart';
import 'today.dart' show thousands;
import 'track.dart';
import 'visuals.dart';
import 'water_walk.dart' show litres;

/// A partner's day, live (helperPage for the 'partner' role), with notes and Unlink underneath.
class PartnerPage extends StatelessWidget {
  const PartnerPage({super.key, required this.owner, required this.name, required this.store});
  final String owner, name;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: Cloud.instance.progress(owner, partner: true),
          builder: (context, snap) {
            final p = snap.data;
            final first = (p?.name ?? name).split(' ').first;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (p == null)
                  PageHeader(
                    name,
                    sub: snap.connectionState == ConnectionState.waiting ? '' : 'Shows up once they open Daur',
                  )
                else
                  PartnerDay(
                    d: p.data,
                    name: p.name,
                    photo: p.photo,
                    at: p.at,
                    onNote: (text) => Cloud.instance.addNote(owner, text, 'partner'),
                  ),
                const SizedBox(height: 28),
                Text('Notes', style: t.meta()),
                const SizedBox(height: 8),
                NotesThread(owner: owner, role: 'partner', store: store),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    if (await confirmPop(
                      context,
                      'Unlink $first?',
                      'You both stop seeing each other\'s progress.',
                      'Unlink',
                      destructive: true,
                    )) {
                      await Cloud.instance.unlinkPartner(owner);
                      if (context.mounted) Navigator.maybePop(context);
                    }
                  },
                  child: Text('Unlink', style: t.sec(t.ink)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Their day the way Daur draws your own: their runner on today's track, the four meals as stops
/// along it (a heart on each one done sends "Loved your lunch"), their rings, weight and gym.
class PartnerDay extends StatefulWidget {
  const PartnerDay({super.key, required this.d, required this.name, this.photo, this.at, this.onNote});
  final Map<String, dynamic> d; // Store.partnerSummary's shape
  final String name;
  final String? photo;
  final DateTime? at;
  final Future<String?> Function(String text)? onNote;

  @override
  State<PartnerDay> createState() => _PartnerDayState();
}

class _PartnerDayState extends State<PartnerDay> {
  final _loved = <int>{}; // meals hearted on this visit

  int _n(String k) => (widget.d[k] as num?)?.toInt() ?? 0;

  Future<void> _love(int i, String meal) async {
    if (_loved.contains(i) || widget.onNote == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _loved.add(i));
    final msg = await widget.onNote!('Loved your ${meal.toLowerCase()}');
    if (msg != null && mounted) {
      setState(() => _loved.remove(i));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final d = widget.d;
    final first = widget.name.split(' ').first;
    final meals = (d['meals'] as List? ?? const []).cast<Map>();
    final extras = (d['extras'] as List? ?? const []).cast<Map>();
    final legs = meals.where((m) => const ['done', 'skipped'].contains(m['status'])).length;
    final hidden = (d['hidden'] as List? ?? const []).cast<String>();
    final today = d['day'] == dayKey(DateTime.now());
    final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // who, and their streak
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: t.infield,
                foregroundImage: widget.photo == null ? null : NetworkImage(widget.photo!),
                child: Text(first.isEmpty ? '?' : first[0], style: t.x(20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(first, style: t.title(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(today ? 'Day ${_n('lap')} · ${ago(widget.at)}' : 'Not opened Daur today', style: t.meta()),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
              decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(20)),
              child: FlameCount(count: _n('streak'), color: t.onAccent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Track(meters: today ? legs * 100 : 0, caption: '${thousands(_n('kcal'))} of ${thousands(_n('kcalGoal'))} kcal'),
        const SizedBox(height: 16),

        // the meals as stops along the lap
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              // one lane through the stops' centres (1/8, 3/8, 5/8, 7/8), yellow up to the last one logged
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth, n = math.max(1, math.min(4, meals.length));
                  final from = w / (2 * n), to = w - from, step = (to - from) / math.max(1, n - 1);
                  return Stack(
                    children: [
                      Positioned(
                        left: from,
                        width: to - from,
                        top: 25,
                        height: 3,
                        child: ColoredBox(color: t.lane),
                      ),
                      // the lane lights up stop to stop, in time with the stops landing
                      if (today && legs > 1)
                        Play(
                          delay: const Duration(milliseconds: 200),
                          duration: Duration(milliseconds: 160 * legs + 300),
                          builder: (context, v, _) => Positioned(
                            left: from,
                            width: step * (legs - 1) * v,
                            top: 25,
                            height: 3,
                            child: ColoredBox(color: t.accent),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // the stops land one after another, with a bounce
                  for (final (i, m) in meals.take(4).indexed)
                    Expanded(
                      child: Play(
                        delay: Duration(milliseconds: 160 * i),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        child: _stop(t, i, m, today),
                        builder: (context, v, child) => Opacity(
                          opacity: v.clamp(0, 1),
                          child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (extras.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in extras)
                Chip(
                  avatar: Icon(Icons.add_circle_outline_rounded, size: 16, color: t.ink),
                  label: Text('${e['name']} · ${e['kcal']} kcal', style: t.meta(t.ink)),
                  backgroundColor: t.infield,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: WaterTile(
                frac: _n('water') / math.max(1, _n('waterGoal')),
                value: '${litres(_n('water'))} L',
                label: 'of ${litres(_n('waterGoal'))} L',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StepsTile(
                steps: _n('steps'),
                frac: _n('steps') / math.max(1, _n('stepTarget')),
                label: 'of ${thousands(_n('stepTarget'))}',
                delay: const Duration(milliseconds: 150),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SleepTile(
                value: d['sleepMin'] == null ? '–' : '${(_n('sleepMin') / 60).toStringAsFixed(1)} h',
                label: 'sleep',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ActivityCard.weight(
                locked: hidden.contains('weight'),
                kg: now == null || start == null ? 0 : now - start,
                big: hidden.contains('weight')
                    ? 'Private'
                    : now == null || start == null
                    ? '–'
                    : '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg',
                small: hidden.contains('weight') ? 'weight kept private' : 'since day 1',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActivityCard.gym(
                big: '${_n('gymThisWeek')} of 3',
                small: 'gym this week',
                dots: (_n('gymThisWeek'), 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One meal on the lap: a disc with its icon (yellow when done), the name, what they ate when
  /// they share it, and a heart to cheer it.
  Widget _stop(Daur t, int i, Map m, bool today) {
    final status = today ? m['status'] as String? ?? 'todo' : 'todo';
    final done = status == 'done', next = status == 'next';
    final food = m['food'] as String?;
    final loved = _loved.contains(i);
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: done ? t.accent : t.infield,
            shape: BoxShape.circle,
            border: next ? Border.all(color: t.accent, width: 3) : null,
          ),
          child: Icon(
            status == 'skipped' ? Icons.remove_rounded : mealIcon('m${i + 1}'),
            color: done ? t.onAccent : (next ? t.accent : t.ink2),
          ),
        ),
        const SizedBox(height: 6),
        Text(m['name'] as String? ?? '', style: t.meta(t.ink), maxLines: 1),
        Text(
          done
              ? (food ?? '${m['kcal']} kcal')
              : status == 'skipped'
              ? 'skipped'
              : (m['window'] as String? ?? '').split('–').first,
          style: t.meta(),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (done && widget.onNote != null)
          LoveButton(loved: loved, onTap: () => _love(i, m['name'] as String? ?? 'meal')),
      ],
    );
  }
}
