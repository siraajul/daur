import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'adaptive.dart';
import 'cloud.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, MenuButton, thousands;
import 'visuals.dart';
import 'water_walk.dart' show RingHero, Tiles, litres;

// Helpers follow someone's plan: a diet helper (a mother) and a trainer. The owner invites with a
// code per role; helpers see a live summary (cloud.dart coachSummary) and leave notes both ways.

const goalWords = ['losing', 'keeping', 'gaining'];

const roleNames = {'diet': 'Diet helper', 'trainer': 'Trainer', 'owner': 'You'};

String ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Coaches', sub: 'People who follow your plan'),
                const SizedBox(height: 16),
                if (!c.signedIn) ...[
                  const Tip(
                    Icons.family_restroom_rounded,
                    'Your mother, your trainer: they see your day, you get their notes',
                  ),
                  const SizedBox(height: 16),
                  GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle()),
                ] else ...[
                  for (final (role, icon, sees) in const [
                    ('diet', Icons.restaurant_rounded, 'Meals, kcal, water, weight'),
                    ('trainer', Icons.fitness_center_rounded, 'All that, plus gym and strength'),
                  ])
                    _InviteCard(
                      role: role,
                      icon: icon,
                      sees: sees,
                      code: s.inviteCodes[role],
                      busy: _busy,
                      onMake: () => _run(() => c.createInvite(role)),
                      onRevoke: () => c.revokeInvite(role),
                    ),
                  if (s.inviteCodes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Following you', style: t.meta()),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: c.helpers(),
                      builder: (context, snap) {
                        final rows = snap.data ?? const [];
                        if (rows.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text('No one yet · share a code', style: t.sec()),
                          );
                        }
                        return Column(
                          children: [
                            for (final h in rows)
                              _Person(
                                name: h['name'] as String? ?? '',
                                photo: h['photoUrl'] as String?,
                                sub: roleNames[h['role']] ?? '',
                                onRemove: () async {
                                  if (await confirmPop(
                                    context,
                                    'Remove ${h['name']}?',
                                    'They stop seeing your progress.',
                                    'Remove',
                                    destructive: true,
                                  )) {
                                    await c.removeHelper(h['uid'] as String);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text('Notes', style: t.meta()),
                    const SizedBox(height: 8),
                    NotesThread(owner: c.user!.uid, role: 'owner', store: s),
                  ],
                  const SizedBox(height: 28),
                  Text('Helping someone?', style: t.meta()),
                  for (final h in s.helping) _Helped(h: h, store: s),
                  _JoinRow(busy: _busy, onJoin: (code) => _run(() => c.joinAsHelper(code))),
                ],
                if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: t.body())],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(icon, color: t.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleNames[role]!, style: t.body()),
                Text(sees, style: t.meta()),
                if (code != null) ...[const SizedBox(height: 6), Text(code!, style: t.x(22, weight: FontWeight.w900))],
              ],
            ),
          ),
          if (code == null)
            FilledButton(
              onPressed: busy ? null : onMake,
              style: FilledButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
              child: const Text('Invite'),
            )
          else ...[
            IconButton(
              tooltip: 'Share the code',
              icon: Icon(Icons.ios_share_rounded, color: t.ink),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Follow my diet on Daur as my ${roleNames[role]!.toLowerCase()}: install Daur, choose "Helping someone?" and enter $code',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: Icon(Icons.copy_rounded, color: t.ink),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
              },
            ),
            MoreButton([MenuItem('Stop this code', onRevoke, destructive: true)]),
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
              hintText: 'THEIR CODE',
              hintStyle: t.x(20, color: t.faint),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: widget.busy ? null : () => widget.onJoin(_code.text),
          style: FilledButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.name, required this.sub, this.photo, this.onRemove});
  final String name, sub;
  final String? photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: t.meta()),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
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
  const NotesThread({super.key, required this.owner, required this.role, required this.store});
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
    final msg = await Cloud.instance.addNote(widget.owner, _text.text, widget.role);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                  hintText: widget.role == 'owner' ? 'Write to your helpers' : 'e.g. Less rice tonight',
                  hintStyle: t.sec(),
                  counterText: '',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              icon: Icon(Icons.send_rounded, color: t.accent),
              onPressed: _send,
            ),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Cloud.instance.notes(widget.owner),
          builder: (context, snap) {
            final notes = snap.data ?? const [];
            if (notes.isNotEmpty && widget.role == 'owner') {
              final newest = (notes.first['at'] as dynamic)?.toDate()?.toIso8601String() as String?;
              if (newest != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.store.seeNotes(newest));
            }
            return Column(
              children: [
                for (final n in notes)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                                '${n['name']} · ${roleNames[n['role']] ?? ''} · ${ago((n['at'] as dynamic)?.toDate() as DateTime?)}',
                                style: t.meta(),
                              ),
                              const SizedBox(height: 2),
                              Text(n['text'] as String? ?? '', style: t.body(weight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        if (n['fromUid'] == me || widget.role == 'owner')
                          IconButton(
                            tooltip: 'Delete note',
                            icon: Icon(Icons.close_rounded, size: 18, color: t.ink2),
                            onPressed: () => Cloud.instance.deleteNote(widget.owner, n['id'] as String),
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

/// What a helper sees: [owner]'s day, weight, (trainer) gym and strength, and the notes.
class HelperView extends StatelessWidget {
  const HelperView({super.key, required this.owner, required this.name, required this.role, required this.store});
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
            final d = p?.data ?? const <String, dynamic>{};
            int n(String k) => (d[k] as num?)?.toInt() ?? 0;
            final stale = p != null && d['day'] != dayKey(DateTime.now());
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageHeader(
                  p?.name ?? name,
                  sub: p == null
                      ? 'Waiting for their first update'
                      : 'Day ${n('lap')} of 84 · ${n('streak')}-day streak · ${ago(p.at)}',
                ),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                if (snap.hasError) Text('Couldn\'t load: ${snap.error}', style: t.sec()),
                if (p == null && snap.connectionState != ConnectionState.waiting)
                  const Tip(Icons.schedule_rounded, 'Shows up once they open Daur'),
                if (p != null) ...[
                  if (stale) Tip(Icons.history_rounded, 'From ${d['day']} · they haven\'t opened Daur today'),
                  const SizedBox(height: 16),
                  RingHero(
                    frac: n('kcal') / math.max(1, n('kcalGoal')),
                    big: thousands(n('kcal')),
                    small: 'of ${thousands(n('kcalGoal'))} kcal',
                    pill: n('burnLeft') > 0
                        ? '${thousands(n('burnLeft'))} kcal over'
                        : n('eatLeft') > 0
                        ? '${thousands(n('eatLeft'))} kcal still to eat'
                        : '${goalWords[n('goal')]} · ${n('protein')} g protein',
                    done: false,
                    label: '${n('kcal')} of ${n('kcalGoal')} kilocalories',
                  ),
                  const SizedBox(height: 20),
                  Tiles([
                    (Icons.water_drop_outlined, '${litres(n('water'))} L', 'of ${litres(n('waterGoal'))} L'),
                    (Icons.directions_walk_rounded, thousands(n('steps')), 'of ${thousands(n('stepTarget'))}'),
                    (
                      Icons.bedtime_outlined,
                      d['sleepMin'] == null ? '–' : '${(n('sleepMin') / 60).toStringAsFixed(1)} h',
                      'sleep',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Text('Meals', style: t.meta()),
                  for (final m in (d['meals'] as List? ?? const []).cast<Map>()) _MealRow(m: m),
                  for (final e in (d['extras'] as List? ?? const []).cast<Map>())
                    _MealRow(m: {'name': 'Extra', 'status': 'extra', 'food': e['name'], 'kcal': e['kcal']}),
                  const SizedBox(height: 24),
                  _Weight(d: d),
                  if (role == 'trainer') ...[const SizedBox(height: 24), _Gym(d: d)],
                ],
                const SizedBox(height: 24),
                Text('Notes', style: t.meta()),
                const SizedBox(height: 8),
                NotesThread(owner: owner, role: role, store: store),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    if (await confirmPop(
                      context,
                      'Stop helping $name?',
                      'You stop seeing their progress.',
                      'Stop',
                      destructive: true,
                    )) {
                      await Cloud.instance.leaveHelping(owner);
                      if (context.mounted) Navigator.maybePop(context);
                    }
                  },
                  child: Text('Stop helping', style: t.sec(t.ink)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.m});
  final Map m;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final status = m['status'] as String? ?? 'todo';
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m['name'] as String? ?? '', style: t.body()),
                Text(
                  status == 'done' || status == 'extra'
                      ? '${m['food']}'
                      : status == 'skipped'
                      ? 'Skipped'
                      : 'Planned: ${m['food']}',
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
              Text((m['time'] ?? m['window'] ?? '') as String, style: t.meta(t.ink)),
              if (status == 'done' || status == 'extra') Text('${m['kcal']} kcal', style: t.meta()),
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
    final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();
    final pts = [for (final w in (d['weights'] as List? ?? const [])) ((w as List)[1] as num).toDouble()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Weight', style: t.meta())),
            if (now != null && start != null)
              Text(
                '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg since day 1',
                style: t.meta(t.ink),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(now == null ? 'No weigh-in yet' : '${now.toStringAsFixed(1)} kg', style: t.x(28)),
        if (pts.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: CustomPaint(painter: _Line(pts, t), size: Size.infinite),
          ),
        ],
      ],
    );
  }
}

class _Gym extends StatelessWidget {
  const _Gym({required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final sessions = (d['sessions'] as List? ?? const []).cast<List>();
    final strength = (d['strength'] as List? ?? const []).cast<Map>();
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
            Expanded(child: Text('Gym', style: t.meta())),
            Text('${(d['gymThisWeek'] as num?)?.toInt() ?? 0} of 3–5 this week', style: t.meta(t.ink)),
          ],
        ),
        for (final x in sessions)
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.rule, width: .5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('${x[1] ?? 'Gym'} day', style: t.body(weight: FontWeight.w500)),
                ),
                Text('${x[0]} · ${x[2]} done', style: t.meta()),
              ],
            ),
          ),
        if (strength.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Strength since the first session', style: t.meta()),
          for (final x in strength)
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.rule, width: .5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(x['ex'] as String? ?? '', style: t.body(weight: FontWeight.w500)),
                  ),
                  Text(
                    '${amount(x['start'] as num, x['unit'] as String)} → ${amount(x['now'] as num, x['unit'] as String)}',
                    style: t.x(14),
                  ),
                ],
              ),
            ),
        ],
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
    final lo = pts.reduce(math.min), hi = pts.reduce(math.max), span = math.max(.5, hi - lo);
    final path = Path();
    for (final (i, v) in pts.indexed) {
      final p = Offset(size.width * i / (pts.length - 1), size.height * (1 - (v - lo) / span));
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
    final last = Offset(size.width, size.height * (1 - (pts.last - lo) / span));
    canvas.drawCircle(last, 6, Paint()..color = t.accent);
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
      if (Cloud.instance.signedIn && store.helping.length == 1) {
        final h = store.helping.first;
        return HelperView(owner: h['owner']!, name: h['name']!, role: h['role']!, store: store);
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
        final title = s.role == 'trainer'
            ? 'Students'
            : s.role == 'family'
            ? 'Family'
            : 'People';
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    if (!standalone) const MenuButton(),
                    Expanded(child: Text(standalone ? 'Daur' : title, style: t.title())),
                  ],
                ),
                Text(
                  standalone ? 'Helping with their plan' : 'Their day at a glance · a dot needs a look',
                  style: t.sec(),
                ),
                const SizedBox(height: 20),
                if (!c.signedIn) ...[
                  const Tip(Icons.vpn_key_outlined, 'Sign in, then enter the code they sent you'),
                  const SizedBox(height: 16),
                  GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle()),
                ] else ...[
                  if (s.helping.isEmpty)
                    const Tip(Icons.vpn_key_outlined, 'Ask for their code: in their Daur, Menu → Coaches → Invite'),
                  for (final h in s.helping) _Helped(h: h, store: s),
                  const SizedBox(height: 16),
                  Text('Add someone', style: t.meta()),
                  _JoinHome(store: s),
                ],
                if (standalone) ...[
                  const SizedBox(height: 32),
                  Cta(label: 'Start my own plan too', muted: true, onTap: () => s.setHelperOnly(false)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JoinHome extends StatefulWidget {
  const _JoinHome({required this.store});
  final Store store;
  @override
  State<_JoinHome> createState() => _JoinHomeState();
}

class _JoinHomeState extends State<_JoinHome> {
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
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: t.body())],
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
      stream: Cloud.instance.progress(h['owner']!),
      builder: (context, snap) {
        final d = snap.data?.data ?? const <String, dynamic>{};
        int n(String k) => (d[k] as num?)?.toInt() ?? 0;
        final today = d['day'] == dayKey(DateTime.now());
        final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();
        final status = snap.data == null
            ? 'Waiting for their first update'
            : [
                goalWords[n('goal')],
                today ? '${thousands(n('kcal'))}/${thousands(n('kcalGoal'))} kcal' : 'Not opened today',
                if (h['role'] == 'trainer') 'gym ${n('gymThisWeek')}/wk',
                if (now != null && start != null)
                  '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg',
              ].join(' · ');
        // needs a look: not opened today; over target (losing, keeping); short in the evening (gaining)
        final flag =
            snap.data != null &&
            (!today || n('burnLeft') > 0 || (n('goal') == 2 && n('eatLeft') > 0 && DateTime.now().hour >= 18));
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelperView(owner: h['owner']!, name: h['name']!, role: h['role']!, store: store),
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.rule, width: .5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: t.infield,
                  foregroundImage: snap.data?.photo == null ? null : NetworkImage(snap.data!.photo!),
                  child: Text((h['name'] ?? '?').isEmpty ? '?' : h['name']![0], style: t.body()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h['name'] ?? '', style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(status, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (flag)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
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
    if (me == null || store.inviteCodes.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: c.notes(me),
      builder: (context, snap) {
        final n = (snap.data ?? const []).where((n) => n['fromUid'] != me).firstOrNull;
        final at = (n?['at'] as dynamic)?.toDate()?.toIso8601String() as String?;
        if (n == null || at == null || at.compareTo(store.notesSeen) <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: t.infield,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoachesScreen(store: store))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: t.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${n['name']} · ${roleNames[n['role']] ?? ''}', style: t.meta()),
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
                      tooltip: 'Dismiss',
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
