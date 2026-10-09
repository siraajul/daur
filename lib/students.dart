import 'dart:async';

import 'package:flutter/material.dart';

import 'dau.dart';
import 'cloud.dart';
import 'coaching.dart';
import 'store.dart';
import 'targets.dart' show groundChip;
import 'theme.dart';
import 'today.dart' show MenuButton, thousands;
import 'visuals.dart';

/// Why a student needs the trainer now, most urgent first, in plain words. Empty = on track.
/// [d] is the student's summary, [at] when it was last published (they last opened Daur).
List<String> studentFlags(Map<String, dynamic> d, DateTime? at, DateTime now) {
  final out = <String>[];
  int n(String k) => (d[k] as num?)?.toInt() ?? 0;
  final lap = n('lap'), goal = n('goal');
  final idle = at == null
      ? 99
      : DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (idle >= 2) out.add(idle >= 99 ? 'Never opened Daur' : 'Not opened in $idle days');
  final sessions = (d['sessions'] as List? ?? const []).cast<List>();
  if (lap >= 4) {
    if (sessions.isEmpty) {
      out.add('No gym yet');
    } else {
      final last = DateTime.parse(sessions.first[0] as String);
      final days = DateTime(now.year, now.month, now.day).difference(last).inDays;
      if (days >= 4) out.add('No gym in $days days');
    }
  }
  final kg = (d['kgWeek'] as num?)?.toDouble();
  if (kg != null) {
    if (goal == 0 && kg >= 0) out.add('Weight not moving this week');
    if (goal == 2 && kg <= 0) out.add('Not gaining this week');
    if (goal == 1 && kg.abs() > .5) out.add(kg > 0 ? 'Weight creeping up' : 'Losing when keeping');
  }
  if (lap >= 7 && d['fullDays'] != null && n('fullDays') < 4) out.add('Logged ${n('fullDays')} of 7 days');
  if (d['day'] == dayKey(now)) {
    if (n('burnLeft') > 0) out.add('${thousands(n('burnLeft'))} kcal over today');
    if (goal == 2 && n('eatLeft') > 0 && now.hour >= 20) out.add('${thousands(n('eatLeft'))} kcal short today');
  }
  return out;
}

typedef Progress = ({String name, String? photo, Map<String, dynamic> data, DateTime? at});

/// A trainer's students as a dashboard: who needs them first (with why), filters by goal, each
/// row this week's gym, weight pace and when they were last in. Tap a student for their week.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.store, this.standalone = false});
  final Store store;
  final bool standalone; // the whole app (a trainer with no plan of their own), not a tab
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _subs = <String, StreamSubscription<Progress?>>{};
  final _data = <String, Progress?>{};
  String _filter = 'all';

  /// One live subscription per student; added and dropped as the list changes.
  void _sync() {
    final owners = {for (final h in widget.store.helping) h['owner']!};
    for (final o in _subs.keys.where((o) => !owners.contains(o)).toList()) {
      _subs.remove(o)?.cancel();
      _data.remove(o);
    }
    for (final o in owners.where((o) => !_subs.containsKey(o))) {
      _subs[o] = Cloud.instance.progress(o).listen((p) {
        if (mounted) setState(() => _data[o] = p);
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, c]),
      builder: (context, _) {
        final s = widget.store;
        if (c.signedIn) _sync();
        final now = DateTime.now();
        final rows = [
          for (final h in s.helping)
            (
              h: h,
              p: _data[h['owner']],
              flags: _data[h['owner']] == null
                  ? <String>[]
                  : studentFlags(_data[h['owner']]!.data, _data[h['owner']]!.at, now),
            ),
        ];
        final need = rows.where((r) => r.flags.isNotEmpty).length;
        // the Sunday digest reads this count (reminders.dart)
        WidgetsBinding.instance.addPostFrameCallback((_) => s.noteStudents(need, rows.length));
        bool keep(({Map<String, String> h, Progress? p, List<String> flags}) r) => switch (_filter) {
          'need' => r.flags.isNotEmpty,
          'lose' ||
          'keep' ||
          'gain' => ((r.p?.data['goal'] as num?)?.toInt() ?? 0) == ['lose', 'keep', 'gain'].indexOf(_filter),
          _ => true,
        };
        final shown = rows.where(keep).toList()
          ..sort((a, b) {
            final f = b.flags.length.compareTo(a.flags.length);
            return f != 0 ? f : (a.h['name'] ?? '').compareTo(b.h['name'] ?? '');
          });
        final needing = shown.where((r) => r.flags.isNotEmpty).toList(),
            fine = shown.where((r) => r.flags.isEmpty).toList();
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    if (!widget.standalone) const MenuButton(),
                    Expanded(child: Text('Students', style: t.title())),
                  ],
                ),
                Text(
                  rows.isEmpty
                      ? 'Add your first student with their code'
                      : need == 0
                      ? 'All ${rows.length} on track'
                      : '$need of ${rows.length} need you',
                  style: t.sec(),
                ),
                const SizedBox(height: 14),
                if (!c.signedIn) ...[
                  const Tip(Icons.vpn_key_outlined, 'Sign in, then enter the code each student sends you'),
                  const SizedBox(height: 16),
                  GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle()),
                ] else ...[
                  if (rows.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (k, label) in const [
                          ('all', 'All'),
                          ('need', 'Needs me'),
                          ('lose', 'Losing'),
                          ('keep', 'Keeping'),
                          ('gain', 'Gaining'),
                        ])
                          groundChip(context, label, _filter == k, () => setState(() => _filter = k)),
                      ],
                    ),
                  const SizedBox(height: 8),
                  for (final r in needing) _StudentRow(h: r.h, p: r.p, flags: r.flags, store: s),
                  if (needing.isNotEmpty && fine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 4),
                      child: Text('On track', style: t.meta()),
                    ),
                  for (final r in fine) _StudentRow(h: r.h, p: r.p, flags: r.flags, store: s),
                  if (shown.isEmpty && rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No one here', style: t.sec()),
                    ),
                  const SizedBox(height: 20),
                  Text('Add a student', style: t.meta()),
                  JoinByCode(store: s),
                  if (rows.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Center(child: Dau(mood: DauMood.waiting, size: 130)),
                    const Tip(Icons.forum_outlined, 'They make the code in their Daur: Menu → Coaches → Trainer'),
                  ],
                ],
                if (widget.standalone) ...[
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => s.setHelperOnly(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: t.lane),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('Start my own plan too', style: t.body()),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.h, required this.p, required this.flags, required this.store});
  final Map<String, String> h;
  final Progress? p;
  final List<String> flags;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final d = p?.data ?? const <String, dynamic>{};
    final kg = (d['kgWeek'] as num?)?.toDouble();
    final line = p == null
        ? 'Waiting for their first update'
        : [
            goalWords[(d['goal'] as num?)?.toInt() ?? 0],
            'gym ${(d['gymThisWeek'] as num?)?.toInt() ?? 0}/wk',
            if (kg != null) '${kg <= 0 ? '−' : '+'}${kg.abs().toStringAsFixed(1)} kg/wk',
            ago(p!.at),
          ].join(' · ');
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HelperView(owner: h['owner']!, name: h['name']!, role: h['role'] ?? 'trainer', store: store),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.rule, width: .5)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: t.infield,
                  foregroundImage: p?.photo == null ? null : NetworkImage(p!.photo!),
                  child: Text((h['name'] ?? '?').isEmpty ? '?' : h['name']![0], style: t.body()),
                ),
                if (flags.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.ground, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['name'] ?? '', style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(line, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (flags.isNotEmpty)
                    Text(
                      flags.length == 1 ? flags.first : '${flags.first} · +${flags.length - 1} more',
                      style: t.meta(t.accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.ink2),
          ],
        ),
      ),
    );
  }
}
