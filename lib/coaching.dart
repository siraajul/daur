import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'activity_anim.dart';
import 'adaptive.dart';
import 'cloud.dart';
import 'diet_chart.dart';
import 'gym.dart' show dayIcon, planText;
import 'ma_page.dart';
import 'partner_day.dart';
import 'students.dart';
import 'plan.dart' show Meal;
import 'store.dart';
import 'theme.dart';
import 'l10n.dart';
import 'today.dart' show Cta, MenuButton, niceDate, thousands;
import 'visuals.dart';
import 'water_walk.dart' show RingHero, Tiles, litres;
import 'workout_editor.dart';

// Helpers follow someone's plan: a diet helper (a mother) and a trainer. The owner invites with a
// code per role; helpers see a live summary (cloud.dart coachSummary) and leave notes both ways.

const goalWords = ['losing', 'keeping', 'gaining'];

const roleNames = {
  'diet': 'Diet helper',
  'trainer': 'Trainer',
  'partner': 'Partner',
  'owner': 'You',
};

String ago(DateTime? t, [BuildContext? context]) {
  String say(String message, [Map<String, Object> args = const {}]) =>
      context == null
      ? trLanguage('en', message, args)
      : tr(context, message, args);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return say('just now');
  if (d.inMinutes < 60) return say('{count} min ago', {'count': d.inMinutes});
  if (d.inHours < 24) return say('{count} h ago', {'count': d.inHours});
  return say('{count} d ago', {'count': d.inDays});
}

/// Menu → Coaches: invite a diet helper or a trainer, see who follows, notes; or help someone.
class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key, required this.store});
  final Store store;
  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await f();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, c]),
      builder: (context, _) {
        final s = widget.store;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageHeader(
                  tr(context, 'Coaches'),
                  sub: tr(context, 'People who follow your plan'),
                ),
                SizedBox(height: 16),
                if (!c.signedIn) ...[
                  Tip(
                    Icons.family_restroom_rounded,
                    tr(
                      context,
                      'Your mother, your trainer: they see your day, you get their notes',
                    ),
                  ),
                  SizedBox(height: 16),
                  GoogleButton(
                    busy: c.busy,
                    onPressed: () => c.signInWithGoogle(),
                  ),
                ] else ...[
                  for (final (role, icon, sees) in [
                    (
                      'diet',
                      Icons.restaurant_rounded,
                      tr(context, 'Meals, kcal, water, weight'),
                    ),
                    (
                      'trainer',
                      Icons.fitness_center_rounded,
                      tr(context, 'All that, plus gym and strength'),
                    ),
                  ])
                    InviteCard(
                      role: role,
                      icon: icon,
                      sees: sees,
                      code: s.inviteCodes[role],
                      busy: _busy,
                      onMake: () => _run(() => c.createInvite(role)),
                      onRevoke: () => c.revokeInvite(role),
                    ),
                  if (s.inviteCodes.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(tr(context, 'Following you'), style: t.meta()),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: c.helpers(),
                      builder: (context, snap) {
                        final rows = snap.data ?? [];
                        if (rows.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              tr(context, 'No one yet · share a code'),
                              style: t.sec(),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final (i, h) in rows.indexed)
                              SlideIn(
                                i: i,
                                child: _Person(
                                  name: h['name'] as String? ?? '',
                                  photo: h['photoUrl'] as String?,
                                  sub: roleNames[h['role']] ?? '',
                                  onRemove: () async {
                                    if (await confirmPop(
                                      context,
                                      tr(context, "Remove {name}?", {
                                        "name": h['name'] ?? '',
                                      }),
                                      tr(
                                        context,
                                        'They stop seeing your progress.',
                                      ),
                                      tr(context, 'Remove'),
                                      destructive: true,
                                    )) {
                                      await c.removeHelper(h['uid'] as String);
                                    }
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Text(tr(context, 'Notes'), style: t.meta()),
                    SizedBox(height: 8),
                    NotesThread(owner: c.user!.uid, role: 'owner', store: s),
                  ],
                  SizedBox(height: 28),
                  Text(tr(context, 'Helping someone?'), style: t.meta()),
                  for (final (i, h) in s.helping.indexed)
                    SlideIn(
                      i: i,
                      child: _Helped(h: h, store: s),
                    ),
                  _JoinRow(
                    busy: _busy,
                    onJoin: (code) => _run(() => c.joinAsHelper(code)),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(tr(context, _error!), style: t.body()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class InviteCard extends StatelessWidget {
  const InviteCard({
    super.key,
    required this.role,
    required this.icon,
    required this.sees,
    required this.code,
    required this.busy,
    required this.onMake,
    required this.onRevoke,
  });
  final String role, sees;
  final IconData icon;
  final String? code;
  final bool busy;
  final VoidCallback onMake, onRevoke;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: t.infield,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: t.ink),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, roleNames[role]!), style: t.body()),
                Text(tr(context, sees), style: t.meta()),
                if (code != null) ...[
                  SizedBox(height: 6),
                  Text(code!, style: t.x(22, weight: FontWeight.w900)),
                ],
              ],
            ),
          ),
          if (code == null)
            FilledButton(
              onPressed: busy ? null : onMake,
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.onAccent,
              ),
              child: Text(tr(context, 'Invite')),
            )
          else ...[
            IconButton(
              tooltip: tr(context, 'Share the code'),
              icon: Icon(Icons.ios_share_rounded, color: t.ink),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: role == 'partner'
                      ? tr(
                          context,
                          "See my progress on Daur: install it, open Menu → Couple and enter {code}",
                          {"code": code!},
                        )
                      : tr(
                          context,
                          "Follow my plan on Daur as {role}: choose Helping someone? and enter {code}",
                          {
                            "role": tr(context, roleNames[role]!),
                            "code": code!,
                          },
                        ),
                ),
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Copy'),
              icon: Icon(Icons.copy_rounded, color: t.ink),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr(context, 'Code copied'))),
                );
              },
            ),
            MoreButton([
              MenuItem(
                tr(context, 'Stop this code'),
                onRevoke,
                destructive: true,
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _JoinRow extends StatefulWidget {
  const _JoinRow({required this.busy, required this.onJoin});
  final bool busy;
  final ValueChanged<String> onJoin;
  @override
  State<_JoinRow> createState() => _JoinRowState();
}

class _JoinRowState extends State<_JoinRow> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: t.x(20),
            decoration: InputDecoration(
              hintText: tr(context, 'THEIR CODE'),
              hintStyle: t.x(20, color: t.faint),
            ),
          ),
        ),
        SizedBox(width: 12),
        FilledButton(
          onPressed: widget.busy ? null : () => widget.onJoin(_code.text),
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.onAccent,
          ),
          child: Text(tr(context, 'Join')),
        ),
      ],
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.name,
    required this.sub,
    this.photo,
    this.onRemove,
  });
  final String name, sub;
  final String? photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: t.infield,
            foregroundImage: photo == null ? null : NetworkImage(photo!),
            child: Text(name.isEmpty ? '?' : name[0], style: t.body()),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: t.body(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(tr(context, sub), style: t.meta()),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: tr(context, 'Remove'),
              icon: Icon(Icons.close_rounded, color: t.ink2),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Notes on [owner]'s plan, newest first, with a box to write one. [role] is the writer's.
class NotesThread extends StatefulWidget {
  const NotesThread({
    super.key,
    required this.owner,
    required this.role,
    required this.store,
  });
  final String owner, role;
  final Store store;
  @override
  State<NotesThread> createState() => _NotesThreadState();
}

class _NotesThreadState extends State<NotesThread> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = await Cloud.instance.addNote(
      widget.owner,
      _text.text,
      widget.role,
    );
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, msg))));
    } else {
      _text.clear();
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final me = Cloud.instance.user?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                style: t.body(weight: FontWeight.w400),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  hintText: switch (widget.role) {
                    'owner' => tr(context, 'Write to your helpers'),
                    'trainer' => tr(context, 'e.g. Bench 50 kg next push day'),
                    'partner' => tr(context, 'e.g. Gym together at 7?'),
                    _ => tr(context, 'e.g. Less rice tonight'),
                  },
                  hintStyle: t.sec(),
                  counterText: '',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Send'),
              icon: Icon(Icons.send_rounded, color: t.accent),
              onPressed: _send,
            ),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Cloud.instance.notes(widget.owner),
          builder: (context, snap) {
            final notes = snap.data ?? [];
            if (notes.isNotEmpty && widget.role == 'owner') {
              final newest =
                  (notes.first['at'] as dynamic)?.toDate()?.toIso8601String()
                      as String?;
              if (newest != null) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => widget.store.seeNotes(newest),
                );
              }
            }
            return Column(
              children: [
                for (final n in notes)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.rule, width: .5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${n['name']} · ${tr(context, roleNames[n['role']] ?? '')} · ${ago((n['at'] as dynamic)?.toDate() as DateTime?, context)}',
                                style: t.meta(),
                              ),
                              SizedBox(height: 2),
                              Text(
                                n['text'] as String? ?? '',
                                style: t.body(weight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (n['fromUid'] == me || widget.role == 'owner')
                          IconButton(
                            tooltip: tr(context, 'Delete note'),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: t.ink2,
                            ),
                            onPressed: () => Cloud.instance.deleteNote(
                              widget.owner,
                              n['id'] as String,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The page for someone this person helps: a diet helper (a mother) gets Ma's page, simple and in
/// Bangla, with what to cook; a trainer gets the full view with the week, gym and the chart editor.
Widget helperPage(Map<String, String> h, Store store) => switch (h['role']) {
  'diet' => MaPage(owner: h['owner']!, name: h['name']!, store: store),
  'partner' => PartnerPage(owner: h['owner']!, name: h['name']!, store: store),
  _ => HelperView(
    owner: h['owner']!,
    name: h['name']!,
    role: h['role']!,
    store: store,
  ),
};

/// What a helper sees: [owner]'s day, weight, (trainer) gym and strength, and the notes.
class HelperView extends StatelessWidget {
  const HelperView({
    super.key,
    required this.owner,
    required this.name,
    required this.role,
    required this.store,
  });
  final String owner, name, role;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: Cloud.instance.progress(owner),
          builder: (context, snap) {
            final p = snap.data;
            final d = p?.data ?? <String, dynamic>{};
            int n(String k) => (d[k] as num?)?.toInt() ?? 0;
            final stale = p != null && d['day'] != dayKey(DateTime.now());
            return ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageHeader(
                  p?.name ?? name,
                  sub: p == null
                      ? tr(context, 'Waiting for their first update')
                      : tr(
                          context,
                          "Day {day} of 84 · {streak}-day streak · {updated}",
                          {
                            "day": n('lap'),
                            "streak": n('streak'),
                            "updated": ago(p.at, context),
                          },
                        ),
                ),
                if (snap.connectionState == ConnectionState.waiting)
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                if (snap.hasError)
                  Text(
                    tr(context, "Could not load: {error}", {
                      "error": snap.error.toString(),
                    }),
                    style: t.sec(),
                  ),
                if (p == null &&
                    snap.connectionState != ConnectionState.waiting)
                  Tip(
                    Icons.schedule_rounded,
                    tr(context, 'Shows up once they open Daur'),
                  ),
                if (p != null) ...[
                  if (stale)
                    Tip(
                      Icons.history_rounded,
                      tr(
                        context,
                        "From {date} · they have not opened Daur today",
                        {"date": d['day'] ?? ''},
                      ),
                    ),
                  SizedBox(height: 16),
                  RingHero(
                    frac: n('kcal') / math.max(1, n('kcalGoal')),
                    big: thousands(n('kcal')),
                    small: tr(context, "of {count} kcal", {
                      "count": thousands(n('kcalGoal')),
                    }),
                    pill: n('burnLeft') > 0
                        ? tr(context, "{count} kcal over", {
                            "count": thousands(n('burnLeft')),
                          })
                        : n('eatLeft') > 0
                        ? tr(context, "{count} kcal still to eat", {
                            "count": thousands(n('eatLeft')),
                          })
                        : tr(context, "{goal} · {count} g protein", {
                            "goal": tr(context, goalWords[n('goal')]),
                            "count": n('protein'),
                          }),
                    done: false,
                    label: tr(context, "{count} of {goal} kilocalories", {
                      "count": n('kcal'),
                      "goal": n('kcalGoal'),
                    }),
                  ),
                  SizedBox(height: 20),
                  Tiles([
                    (
                      Icons.water_drop_outlined,
                      '${litres(n('water'))} L',
                      tr(context, "of {count} L", {
                        "count": litres(n('waterGoal')),
                      }),
                    ),
                    (
                      Icons.directions_walk_rounded,
                      thousands(n('steps')),
                      tr(context, "of {count}", {
                        "count": thousands(n('stepTarget')),
                      }),
                    ),
                    (
                      Icons.bedtime_outlined,
                      d['sleepMin'] == null
                          ? '–'
                          : '${(n('sleepMin') / 60).toStringAsFixed(1)} h',
                      'sleep',
                    ),
                  ]),
                  SizedBox(height: 24),
                  Text(tr(context, 'Meals'), style: t.meta()),
                  for (final m in (d['meals'] as List? ?? []).cast<Map>())
                    MealRow(m: m),
                  for (final e in (d['extras'] as List? ?? []).cast<Map>())
                    MealRow(
                      m: {
                        'name': tr(context, 'Extra'),
                        'status': 'extra',
                        'food': e['name'],
                        'kcal': e['kcal'],
                      },
                    ),
                  SizedBox(height: 24),
                  _Weight(d: d),
                  if (role == 'trainer') ...[
                    SizedBox(height: 24),
                    _Gym(d: d, owner: owner, ownerName: p.name),
                    SizedBox(height: 24),
                    _ChartSection(
                      d: d,
                      owner: owner,
                      ownerName: p.name,
                      store: store,
                    ),
                  ],
                ],
                if (role == 'trainer') ...[
                  SizedBox(height: 24),
                  Text(tr(context, 'Quick feedback'), style: t.meta()),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final text in [
                        tr(context, 'Great week, keep going'),
                        tr(context, 'Missed sessions · back on it Monday'),
                        tr(context, 'Add 2.5 kg next time'),
                        tr(context, 'More protein, please'),
                        tr(context, 'Log every meal this week'),
                      ])
                        ActionChip(
                          label: Text(text, style: t.sec(t.onAccent)),
                          backgroundColor: t.accent,
                          side: BorderSide.none,
                          shape: StadiumBorder(),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final msg = await Cloud.instance.addNote(
                              owner,
                              text,
                              role,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg ?? tr(context, 'Sent')),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
                SizedBox(height: 24),
                Text(tr(context, 'Notes'), style: t.meta()),
                SizedBox(height: 8),
                NotesThread(owner: owner, role: role, store: store),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    if (await confirmPop(
                      context,
                      tr(context, "Stop helping {name}?", {"name": name}),
                      tr(context, 'You stop seeing their progress.'),
                      tr(context, 'Stop'),
                      destructive: true,
                    )) {
                      await Cloud.instance.leaveHelping(owner);
                      if (context.mounted) Navigator.maybePop(context);
                    }
                  },
                  child: Text(tr(context, 'Stop helping'), style: t.sec(t.ink)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MealRow extends StatelessWidget {
  const MealRow({super.key, required this.m});
  final Map m;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final status = m['status'] as String? ?? 'todo';
    return Container(
      constraints: BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          Icon(switch (status) {
            'done' => Icons.check_circle_rounded,
            'skipped' => Icons.remove_circle_outline_rounded,
            'fasting' => Icons.hourglass_bottom_rounded,
            'extra' => Icons.add_circle_outline_rounded,
            _ => Icons.radio_button_unchecked_rounded,
          }, color: status == 'next' ? t.accent : t.ink),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m['name'] as String? ?? '', style: t.body()),
                Text(
                  // a partner may not see the food itself (couple.dart privacy)
                  status == 'done' || status == 'extra'
                      ? '${m['food'] ?? tr(context, 'Done')}'
                      : status == 'skipped'
                      ? tr(context, 'Skipped')
                      : m['food'] == null
                      ? ''
                      : tr(context, "Planned: {food}", {
                          "food": m['food'] ?? '',
                        }),
                  style: t.meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (m['time'] ?? m['window'] ?? '') as String,
                style: t.meta(t.ink),
              ),
              if (status == 'done' || status == 'extra')
                Text('${m['kcal']} kcal', style: t.meta()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Weight extends StatelessWidget {
  const _Weight({required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final now = (d['nowKg'] as num?)?.toDouble(),
        start = (d['startKg'] as num?)?.toDouble();
    final pts = [
      for (final w in (d['weights'] as List? ?? []))
        ((w as List)[1] as num).toDouble(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Weight'), style: t.meta())),
            if (now != null && start != null)
              Text(
                '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg since day 1',
                style: t.meta(t.ink),
              ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          now == null
              ? tr(context, 'No weigh-in yet')
              : '${now.toStringAsFixed(1)} kg',
          style: t.x(28),
        ),
        if (pts.length > 1) ...[
          SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: CustomPaint(painter: _Line(pts, t), size: Size.infinite),
          ),
        ],
      ],
    );
  }
}

/// For the trainer: sessions, strength, and the workout this person follows, with Edit.
class _Gym extends StatelessWidget {
  const _Gym({required this.d, required this.owner, required this.ownerName});
  final Map<String, dynamic> d;
  final String owner, ownerName;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final sessions = (d['sessions'] as List? ?? []).cast<List>();
    final strength = (d['strength'] as List? ?? []).cast<Map>();
    // older phones don't send the workout yet: no editor until they update
    final workout = d['workout'] is Map
        ? workoutFrom(d['workout'] as Map)
        : null;
    final by = d['gymBy'] as String? ?? '';
    String amount(num v, String unit) => unit == 's'
        ? '${v.round()} s'
        : unit == 'reps'
        ? '${v.round()} reps'
        : '${v.toStringAsFixed(1)} kg';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Gym'), style: t.meta())),
            Text(
              tr(context, "{count} of 3–5 this week", {
                "count": (d['gymThisWeek'] as num?)?.toInt() ?? 0,
              }),
              style: t.meta(t.ink),
            ),
          ],
        ),
        for (final x in sessions)
          Container(
            constraints: BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.rule, width: .5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, "{day} day", {
                      "day": tr(context, (x[1] ?? 'Gym').toString()),
                    }),
                    style: t.body(weight: FontWeight.w500),
                  ),
                ),
                Text(
                  tr(context, "{date} · {count} done", {
                    "date": niceDate(DateTime.parse(x[0] as String)),
                    "count": x[2] ?? 0,
                  }),
                  style: t.meta(),
                ),
              ],
            ),
          ),
        if (strength.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            tr(context, 'Strength since the first session'),
            style: t.meta(),
          ),
          for (final x in strength)
            Container(
              constraints: BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.rule, width: .5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x['ex'] as String? ?? '',
                      style: t.body(weight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${amount(x['start'] as num, x['unit'] as String)} → ${amount(x['now'] as num, x['unit'] as String)}',
                    style: t.x(14),
                  ),
                ],
              ),
            ),
        ],
        if (workout != null) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(tr(context, 'Workout'), style: t.meta())),
              Text(
                by.isEmpty
                    ? tr(context, 'their own plan')
                    : tr(context, "by {name}", {"name": by}),
                style: t.meta(t.ink),
              ),
            ],
          ),
          for (final MapEntry(key: day, value: list) in workout.entries)
            Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.rule, width: .5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(dayIcon(day), size: 20, color: t.ink),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, "{day} day", {"day": tr(context, day)}),
                          style: t.body(weight: FontWeight.w500),
                        ),
                        if (list.isEmpty)
                          Text(tr(context, 'nothing yet'), style: t.meta()),
                        for (final (n, p) in list)
                          Text('$n · ${planText(p)}', style: t.meta()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8),
          Cta(
            label: tr(context, 'Edit workout'),
            trailing: tr(context, "{count} exercises", {
              "count": workout.values.fold<int>(0, (a, l) => a + l.length),
            }),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutEditor(
                  owner: owner,
                  ownerName: ownerName,
                  initial: workout,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// For the trainer: the diet chart this person follows, one line per meal, and Edit.
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.d,
    required this.owner,
    required this.ownerName,
    required this.store,
  });
  final Map<String, dynamic> d;
  final String owner, ownerName;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final chart = [
      for (final m in (d['chart'] as List? ?? [])) Meal.from(m as Map),
    ];
    if (chart.length != 4) return SizedBox.shrink();
    final by = d['chartBy'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Diet chart'), style: t.meta())),
            Text(
              by.isEmpty
                  ? tr(context, 'the starting plan')
                  : tr(context, "by {name}", {"name": by}),
              style: t.meta(t.ink),
            ),
          ],
        ),
        for (final m in chart)
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.rule, width: .5)),
            ),
            child: Row(
              children: [
                Icon(mealIcon(m.id), size: 20, color: t.ink),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: t.body(weight: FontWeight.w500)),
                      Text(
                        m.options.map((o) => o.name).join(' · '),
                        style: t.meta(),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 8),
        Cta(
          label: tr(context, 'Edit diet chart'),
          trailing: tr(context, "{count} kcal a day", {
            "count": (d['kcalGoal'] as num?)?.toInt() ?? 0,
          }),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DietChartEditor(
                owner: owner,
                ownerName: ownerName,
                initial: chart,
                kcalGoal: (d['kcalGoal'] as num?)?.toInt() ?? 1800,
                store: store,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends CustomPainter {
  _Line(this.pts, this.t);
  final List<double> pts;
  final Daur t;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = pts.reduce(math.min),
        hi = pts.reduce(math.max),
        span = math.max(.5, hi - lo);
    const r = 6.0; // room for the end dot
    final w = size.width - r, h = size.height - 2 * r;
    final path = Path();
    for (final (i, v) in pts.indexed) {
      final p = Offset(w * i / (pts.length - 1), r + h * (1 - (v - lo) / span));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = t.ink,
    );
    final last = Offset(w, r + h * (1 - (pts.last - lo) / span));
    canvas.drawCircle(last, r, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(_Line o) => o.pts != pts;
}

/// A phone that only helps someone (a mother, a trainer): straight to the one person it helps,
/// or the list when there are several.
class HelperHome extends StatelessWidget {
  const HelperHome({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, Cloud.instance]),
    builder: (context, _) {
      if (Cloud.instance.signedIn &&
          store.helping.length == 1 &&
          store.role != 'trainer') {
        return helperPage(store.helping.first, store);
      }
      return PeopleScreen(store: store, standalone: true);
    },
  );
}

/// The people this person helps (a trainer's students, a mother's children), each with their day at
/// a glance; joining one more with their code. A tab for those who track their own plan too.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key, required this.store, this.standalone = false});
  final Store store;
  final bool standalone; // the whole app (helper-only phone), not a tab

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, c]),
      builder: (context, _) {
        final s = store;
        if (s.role == 'trainer') {
          return StudentsScreen(store: s, standalone: standalone);
        }
        final title = s.role == 'trainer'
            ? tr(context, 'Students')
            : s.role == 'family'
            ? tr(context, 'Family')
            : tr(context, 'People');
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    if (!standalone) MenuButton(),
                    Expanded(
                      child: Text(
                        standalone ? 'Daur' : title,
                        style: t.title(),
                      ),
                    ),
                  ],
                ),
                Text(
                  standalone
                      ? tr(context, 'Helping with their plan')
                      : tr(
                          context,
                          'Their day at a glance · a dot needs a look',
                        ),
                  style: t.sec(),
                ),
                SizedBox(height: 20),
                if (!c.signedIn) ...[
                  Tip(
                    Icons.vpn_key_outlined,
                    tr(context, 'Sign in, then enter the code they sent you'),
                  ),
                  SizedBox(height: 16),
                  GoogleButton(
                    busy: c.busy,
                    onPressed: () => c.signInWithGoogle(),
                  ),
                ] else ...[
                  if (s.helping.isEmpty)
                    Tip(
                      Icons.vpn_key_outlined,
                      tr(
                        context,
                        'Ask for their code: in their Daur, Menu → Coaches → Invite',
                      ),
                    ),
                  for (final (i, h) in s.helping.indexed)
                    SlideIn(
                      i: i,
                      child: _Helped(h: h, store: s),
                    ),
                  SizedBox(height: 16),
                  Text(tr(context, 'Add someone'), style: t.meta()),
                  JoinByCode(store: s),
                ],
                if (standalone) ...[
                  SizedBox(height: 32),
                  Cta(
                    label: tr(context, 'Start my own plan too'),
                    muted: true,
                    onTap: () => s.setHelperOnly(false),
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

class JoinByCode extends StatefulWidget {
  const JoinByCode({super.key, required this.store});
  final Store store;
  @override
  State<JoinByCode> createState() => JoinByCodeState();
}

class JoinByCodeState extends State<JoinByCode> {
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JoinRow(
          busy: _busy,
          onJoin: (code) async {
            setState(() => _busy = true);
            final e = await Cloud.instance.joinAsHelper(code);
            if (mounted) {
              setState(() {
                _busy = false;
                _error = e;
              });
            }
          },
        ),
        if (_error != null) ...[
          SizedBox(height: 8),
          Text(tr(context, _error!), style: t.body()),
        ],
      ],
    );
  }
}

/// One person you help, with their day at a glance (live): kcal against target, gym this week,
/// weight since day 1; a yellow dot when they need a look (over target, or not opened today).
class _Helped extends StatelessWidget {
  const _Helped({required this.h, required this.store});
  final Map<String, String> h;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return StreamBuilder(
      stream: Cloud.instance.progress(
        h['owner']!,
        partner: h['role'] == 'partner',
      ),
      builder: (context, snap) {
        final d = snap.data?.data ?? <String, dynamic>{};
        int n(String k) => (d[k] as num?)?.toInt() ?? 0;
        final today = d['day'] == dayKey(DateTime.now());
        final now = (d['nowKg'] as num?)?.toDouble(),
            start = (d['startKg'] as num?)?.toDouble();
        final status = snap.data == null
            ? tr(context, 'Waiting for their first update')
            : [
                tr(context, goalWords[n('goal')]),
                today
                    ? '${thousands(n('kcal'))}/${thousands(n('kcalGoal'))} kcal'
                    : tr(context, 'Not opened today'),
                if (h['role'] != 'diet')
                  tr(context, "gym {count}/wk", {"count": n('gymThisWeek')}),
                if (now != null && start != null)
                  '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg',
              ].join(' · ');
        // needs a look: not opened today; over target (losing, keeping); short in the evening (gaining)
        final flag =
            snap.data != null &&
            (!today ||
                n('burnLeft') > 0 ||
                (n('goal') == 2 &&
                    n('eatLeft') > 0 &&
                    DateTime.now().hour >= 18));
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => helperPage(h, store)),
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.rule, width: .5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: t.infield,
                  foregroundImage: snap.data?.photo == null
                      ? null
                      : NetworkImage(snap.data!.photo!),
                  child: Text(
                    (h['name'] ?? '?').isEmpty ? '?' : h['name']![0],
                    style: t.body(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        h['name'] ?? '',
                        style: t.body(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr(context, status),
                        style: t.meta(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (flag)
                  Container(
                    width: 10,
                    height: 10,
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                Icon(Icons.chevron_right_rounded, color: t.ink2),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// On Today: the newest note from a helper not yet seen, with a close button.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance, me = c.user?.uid;
    if (me == null || store.inviteCodes.isEmpty) return SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: c.notes(me),
      builder: (context, snap) {
        final n = (snap.data ?? [])
            .where((n) => n['fromUid'] != me)
            .firstOrNull;
        final at =
            (n?['at'] as dynamic)?.toDate()?.toIso8601String() as String?;
        if (n == null || at == null || at.compareTo(store.notesSeen) <= 0) {
          return SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(top: 12),
          child: Material(
            color: t.infield,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CoachesScreen(store: store)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: t.accent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${n['name']} · ${tr(context, roleNames[n['role']] ?? '')}',
                            style: t.meta(),
                          ),
                          Text(
                            n['text'] as String? ?? '',
                            style: t.body(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Dismiss'),
                      icon: Icon(Icons.close_rounded, color: t.ink2),
                      onPressed: () => store.seeNotes(at),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
