import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity_anim.dart';
import 'cloud.dart';
import 'coaching.dart';
import 'dau.dart';
import 'store.dart';
import 'theme.dart';
import 'track.dart';
import 'today.dart' show Cta, thousands;
import 'visuals.dart';
import 'water_walk.dart' show litres;

/// Menu → Couple: two people see each other's day side by side. One shares a code, the other enters
/// it, and it links both ways (cloud.dart: a partner's join carries their own code back).
class CoupleScreen extends StatefulWidget {
  const CoupleScreen({super.key, required this.store});
  final Store store;
  @override
  State<CoupleScreen> createState() => _CoupleScreenState();
}

class _CoupleScreenState extends State<CoupleScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _invite() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await Cloud.instance.createInvite('partner');
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
        final partner = s.helping.where((h) => h['role'] == 'partner').firstOrNull;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Couple', sub: 'You see each other\'s day'),
                const SizedBox(height: 16),
                if (!c.signedIn) ...[
                  const Tip(Icons.favorite_outline_rounded, 'Meals, water, steps, gym and weight, side by side'),
                  const SizedBox(height: 16),
                  GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle()),
                ] else if (partner == null) ...[
                  SideBySide(me: s.coachSummary(), them: null, name: '', myPhoto: c.user?.photoURL),
                  const SizedBox(height: 20),
                  InviteCard(
                    role: 'partner',
                    icon: Icons.favorite_outline_rounded,
                    sees: 'Share it with your partner',
                    code: s.inviteCodes['partner'],
                    busy: _busy,
                    onMake: _invite,
                    onRevoke: () => c.revokeInvite('partner'),
                  ),
                  if (s.inviteCodes['partner'] != null)
                    const Tip(Icons.schedule_rounded, 'Linked once they enter it in their Daur'),
                  const SizedBox(height: 24),
                  Text('Got their code?', style: t.meta()),
                  JoinByCode(store: s),
                ] else ...[
                  _Together(store: s, partner: partner),
                  const SizedBox(height: 28),
                  Text('What ${partner['name']!.split(' ').first} sees', style: t.meta()),
                  for (final (what, label, sub) in const [
                    ('weight', 'My weight', 'kg and the change since day 1'),
                    ('meals', 'What I eat', 'the food itself; meals done and kcal still show'),
                  ])
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(label, style: t.body()),
                      subtitle: Text(sub, style: t.meta()),
                      value: !s.partnerHides.contains(what),
                      onChanged: (v) => s.setPartnerHide(what, !v),
                    ),
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

/// You and your partner today, one row per thing, each with a bar to their own target.
class _Together extends StatelessWidget {
  const _Together({required this.store, required this.partner});
  final Store store;
  final Map<String, String> partner;

  @override
  Widget build(BuildContext context) {
    final name = partner['name']!.split(' ').first;
    return StreamBuilder(
      stream: Cloud.instance.progress(partner['owner']!, partner: true),
      builder: (context, snap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SideBySide(
            me: store.coachSummary(),
            them: snap.data?.data,
            name: name,
            myPhoto: Cloud.instance.user?.photoURL,
            photo: snap.data?.photo,
            loading: snap.connectionState == ConnectionState.waiting,
            onStake: store.setStake,
            onNudge: (text) async {
              final msg = await Cloud.instance.addNote(partner['owner']!, text, 'partner');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? 'Sent to $name')));
              }
            },
          ),
          const SizedBox(height: 12),
          Cta(
            label: '$name\'s day',
            trailing: 'meals, gym, notes',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => helperPage(partner, store))),
          ),
        ],
      ),
    );
  }
}

/// The couple page (ideas from Duolingo's friend streak, Paired's shared calendar and Apple's
/// activity sharing): a streak you keep together, the week with a heart on days you both closed,
/// a team step goal, today as two runners on one track, head to head, and one-tap nudges. [them] is
/// null until they've published; before linking, [name] is empty and the partner slot is an invite.
class SideBySide extends StatelessWidget {
  const SideBySide({
    super.key,
    required this.me,
    required this.them,
    required this.name,
    this.myPhoto,
    this.photo,
    this.loading = false,
    this.onNudge,
    this.onStake,
  });
  final Map<String, dynamic> me;
  final Map<String, dynamic>? them;
  final String name;
  final String? myPhoto, photo;
  final bool loading;
  final ValueChanged<String>? onNudge;
  final ValueChanged<String?>? onStake; // set the race's stake (null where it can't be set)

  static int _n(Map d, String k) => (d[k] as num?)?.toInt() ?? 0;

  /// Meals logged or skipped today: 100 m of the lap each, like Today's track.
  static int legs(Map d) =>
      (d['meals'] as List? ?? const []).where((m) => const ['done', 'skipped'].contains((m as Map)['status'])).length;

  /// The last 7 days, day → (meals, steps, step target, water glasses).
  static Map<String, (int, int, int, int)> days(Map? d) => {
    for (final x in (d?['days'] as List? ?? const []).cast<List>())
      x[0] as String: (
        (x[1] as num).toInt(),
        (x[2] as num).toInt(),
        (x[3] as num).toInt(),
        x.length > 4 ? (x[4] as num).toInt() : 0,
      ),
  };

  static double _of(Map d, String k, String goal) => _n(d, k) / math.max(1, _n(d, goal));

  static double _lost(Map d) {
    final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();
    return now == null || start == null ? 0 : start - now;
  }

  static String _kg(Map d) {
    if ((d['hidden'] as List? ?? const []).contains('weight')) return 'Private';
    final now = (d['nowKg'] as num?)?.toDouble(), start = (d['startKg'] as num?)?.toDouble();
    if (now == null || start == null) return '–';
    return '${now <= start ? '−' : '+'}${(now - start).abs().toStringAsFixed(1)} kg';
  }

  /// (icon, label, value, bar 0..1 given the other person's map). Targets are each person's own;
  /// weight lost is measured against whoever has lost more.
  static final rows = <(IconData, String, String Function(Map), double Function(Map, Map))>[
    (Icons.restaurant_outlined, 'Food', (d) => thousands(_n(d, 'kcal')), (d, _) => _of(d, 'kcal', 'kcalGoal')),
    (Icons.water_drop_outlined, 'Water', (d) => '${litres(_n(d, 'water'))} L', (d, _) => _of(d, 'water', 'waterGoal')),
    (Icons.directions_walk_rounded, 'Steps', (d) => thousands(_n(d, 'steps')), (d, _) => _of(d, 'steps', 'stepTarget')),
    (Icons.fitness_center_rounded, 'Gym', (d) => '${_n(d, 'gymThisWeek')} of 3', (d, _) => _n(d, 'gymThisWeek') / 3),
    (
      Icons.monitor_weight_outlined,
      'Since day 1',
      _kg,
      (d, o) => math.max(0, _lost(d)) / math.max(.1, math.max(_lost(d), _lost(o))),
    ),
  ];

  static const nudges = ['Proud of you', 'Gym together tonight?', 'Drink some water', 'Walk after dinner?'];

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final them = this.them;
    final linked = name.isNotEmpty;
    final stale = them != null && them['day'] != me['day'];
    final mine = legs(me), theirs = them == null || stale ? 0 : legs(them);
    // a streak kept together: both had a full day on each of the last N days, so N is the shorter one
    final together = them == null ? 0 : math.min(_n(me, 'streak'), _n(them, 'streak'));
    final gap = (mine - theirs).abs();
    final meals = gap == 1 ? 'meal' : 'meals';
    final both = mine == 4 && theirs == 4;
    final line = !linked
        ? 'Run today\'s lap together'
        : them == null
        ? (loading ? '' : 'Their runner shows up once they open Daur')
        : stale
        ? '$name hasn\'t opened Daur today'
        : both
        ? 'You both closed today'
        : gap == 0
        ? 'Level · keep pace'
        : mine > theirs
        ? 'You\'re $gap $meals ahead · nudge $name'
        : '$name is $gap $meals ahead · catch up';
    final quick = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1200);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StreakCard(together: together, linked: linked, name: name, myPhoto: myPhoto, photo: photo),
        const SizedBox(height: 20),
        _Week(mine: days(me), theirs: days(them), linked: linked),
        if (linked && them != null) ...[
          const SizedBox(height: 24),
          _Race(me: me, them: them, name: name, onStake: onStake),
          const SizedBox(height: 24),
          _TeamSteps(mine: days(me), theirs: days(them)),
        ],
        const SizedBox(height: 24),
        Text('Today', style: t.meta()),
        // two runners on one track: yellow is you on the inside lane, cream is them outside
        // both closed today: confetti, also when the page opens on such a day
        Confetti(
          burst: both,
          onShow: true,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: quick,
            curve: Curves.easeOutCubic,
            builder: (context, k, _) => AspectRatio(
              aspectRatio: TrackPainter.w / TrackPainter.h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _TwoRunners(mine * 100 * k, linked ? theirs * 100 * k : null, t)),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$mine', style: t.x(52, color: t.accent)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('&', style: t.x(22, color: t.ink2)),
                        ),
                        Text(linked && them != null ? '$theirs' : '–', style: t.x(52)),
                      ],
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, .42),
                    child: Text('meals today', style: t.meta()),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (both) const Dau(mood: DauMood.cheer, size: 56),
            Flexible(
              child: Text(line, style: t.body(), textAlign: TextAlign.center),
            ),
          ],
        ),
        if (linked) ...[
          const SizedBox(height: 16),
          for (final (icon, label, value, frac) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(child: _Bar(value(me), frac(me, them ?? const {}), t.accent, toLeft: true)),
                  SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Icon(icon, size: 22, color: t.ink),
                        const SizedBox(height: 2),
                        Text(label, style: t.meta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(
                    child: them == null
                        ? Text('–', style: t.body())
                        : _Bar(value(them), frac(them, me), t.ink, toLeft: false),
                  ),
                ],
              ),
            ),
          if (onNudge != null) ...[
            const SizedBox(height: 16),
            Text('Nudge $name', style: t.meta()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in nudges)
                  ActionChip(
                    avatar: Icon(Icons.favorite_rounded, size: 16, color: t.onAccent),
                    label: Text(text, style: t.sec(t.onAccent)),
                    backgroundColor: t.accent,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onNudge!(text);
                    },
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// The streak you keep together, on a yellow card with both faces (the partner's slot is an empty
/// ring with a plus until you're linked).
class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.together,
    required this.linked,
    required this.name,
    required this.myPhoto,
    required this.photo,
  });
  final int together;
  final bool linked;
  final String name;
  final String? myPhoto, photo;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    Widget face(String label, String? photo, {bool empty = false}) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: empty ? t.accent : t.ground,
        foregroundImage: photo == null ? null : NetworkImage(photo),
        child: empty
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.onAccent.withValues(alpha: .5), width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add_rounded, color: t.onAccent),
              )
            : Text(label[0], style: t.body(color: t.ink)),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 54,
            child: Stack(
              children: [
                face('You', myPhoto),
                Positioned(left: 40, child: face(name.isEmpty ? '?' : name, photo, empty: !linked)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlameCount(count: together, color: t.onAccent, size: 30, textSize: 36),
                Text(
                  linked ? 'days together · both close the day to keep it' : 'Invite your partner to start a streak',
                  style: t.meta(t.onAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last 7 days: a heart where you both closed the day, else a dot each (yellow you, cream them).
class _Week extends StatelessWidget {
  const _Week({required this.mine, required this.theirs, required this.linked});
  final Map<String, (int, int, int, int)> mine, theirs;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final ds = mine.keys.toList();
    if (ds.isEmpty) return const SizedBox.shrink();
    Widget dot(bool full, Color c) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: full ? c : null,
        shape: BoxShape.circle,
        border: Border.all(color: full ? c : t.lane, width: 1.5),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, d) in ds.indexed)
          Builder(
            builder: (context) {
              final a = (mine[d]?.$1 ?? 0) >= 4, b = (theirs[d]?.$1 ?? 0) >= 4;
              final today = i == ds.length - 1;
              return Column(
                children: [
                  Text(
                    'MTWTFSS'[DateTime.parse(d).weekday - 1],
                    style: today ? t.meta(t.ink).copyWith(fontWeight: FontWeight.w800) : t.meta(),
                  ),
                  const SizedBox(height: 6),
                  // the days pop in left to right; each heart beats once as it lands
                  Play(
                    delay: Duration(milliseconds: 90 * i),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.linear,
                    builder: (context, v, child) =>
                        Transform.scale(scale: Curves.elasticOut.transform((v / .6).clamp(0, 1)), child: child),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: a && b ? t.accent : t.infield,
                        shape: BoxShape.circle,
                        border: today ? Border.all(color: t.ink, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: a && b
                          ? Play(
                              delay: Duration(milliseconds: 90 * i + 450),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.linear,
                              builder: (context, v, child) =>
                                  Transform.scale(scale: 1 + .35 * math.sin(math.pi * v), child: child),
                              child: Icon(Icons.favorite_rounded, size: 20, color: t.onAccent),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                dot(a, t.accent),
                                if (linked) ...[const SizedBox(width: 4), dot(b, t.ink)],
                              ],
                            ),
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

/// This week's race, Saturday to Friday: points for each of you, who leads, and the fun stake the
/// loser pays (either of you sets it; the newer one counts).
class _Race extends StatelessWidget {
  const _Race({required this.me, required this.them, required this.name, required this.onStake});
  final Map<String, dynamic> me, them;
  final String name;
  final ValueChanged<String?>? onStake;

  static const stakes = ['Makes tea', 'Cooks dinner', 'Gives a massage', 'Picks the movie', 'Does the dishes'];

  Future<void> _pick(BuildContext context, String? now) async {
    final t = Daur.of(context);
    final text = TextEditingController(text: stakes.contains(now) ? '' : now);
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.sheet,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The loser…', style: t.x(22, color: t.sheetInk)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final x in stakes)
                  ChoiceChip(label: Text(x), selected: x == now, onSelected: (_) => Navigator.pop(context, x)),
              ],
            ),
            TextField(
              controller: text,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Or your own, e.g. Buys fuchka'),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            if (now != null) TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('No stake')),
          ],
        ),
      ),
    );
    text.dispose();
    if (r != null) onStake!(r.isEmpty ? null : r);
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final today = me['day'] as String? ?? dayKey(DateTime.now());
    final from = raceWeekStart(today);
    final a = racePoints(me, from), b = racePoints(them, from);
    final day = DateTime.parse(today).difference(DateTime.parse(from)).inDays + 1;
    final top = math.max(1, math.max(a, b));
    // the newer stake counts: either of you can change it
    final mineNewer = (me['stakeAt'] as String? ?? '').compareTo(them['stakeAt'] as String? ?? '') >= 0;
    final stake = (mineNewer ? me['stake'] : them['stake']) as String?;
    Widget lane(String who, int pts, Color c, bool lead) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(who, style: t.body(), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Container(
              height: 26,
              decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.centerLeft,
              // the bars race out; the leader's trophy drops in when they've stopped
              child: Play(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.linear,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor:
                      math.max(.08, pts / top) * Curves.easeOutBack.transform((v / .7).clamp(0, 1)).clamp(.0, 1.1),
                  child: Container(
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(13)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 4),
                    child: lead && v > .7
                        ? Transform.scale(
                            scale: Curves.elasticOut.transform(((v - .7) / .3).clamp(0, 1)),
                            child: Icon(Icons.emoji_events_rounded, size: 18, color: t.onAccent),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              thousands(pts),
              style: t.x(15, color: c),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(color: t.infield.withValues(alpha: .5), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Race this week', style: t.body())),
              Text(day >= 7 ? 'last day' : 'day $day of 7 · ends Friday', style: t.meta()),
            ],
          ),
          lane('You', a, t.accent, a > b),
          lane(name, b, t.ink, b > a),
          const SizedBox(height: 8),
          Text(
            a == b
                ? 'Tied'
                : a > b
                ? 'You lead by ${thousands(a - b)}'
                : '$name leads by ${thousands(b - a)}',
            style: t.meta(t.ink),
          ),
          Text('Up to 300 a day: 100 each for meals, water and steps', style: t.meta()),
          InkWell(
            onTap: onStake == null ? null : () => _pick(context, stake),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.redeem_rounded, color: t.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stake == null
                          ? 'Add a fun stake for the loser'
                          : 'Loser ${stake[0].toLowerCase()}${stake.substring(1)}',
                      style: t.body(color: stake == null ? t.ink2 : t.ink),
                    ),
                  ),
                  if (onStake != null) Icon(Icons.edit_outlined, size: 18, color: t.ink2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One goal for two: both people's steps this week against both step targets added up.
class _TeamSteps extends StatelessWidget {
  const _TeamSteps({required this.mine, required this.theirs});
  final Map<String, (int, int, int, int)> mine, theirs;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    int sum(Map<String, (int, int, int, int)> m, int Function((int, int, int, int)) f) =>
        m.values.fold(0, (a, x) => a + f(x));
    final a = sum(mine, (x) => x.$2), b = sum(theirs, (x) => x.$2);
    final goal = math.max(1, sum(mine, (x) => x.$3) + sum(theirs, (x) => x.$3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Team goal · steps this week', style: t.meta())),
            Text('${(100 * (a + b) / goal).round()}%', style: t.meta(t.ink)),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: thousands(a + b), style: t.x(24)),
              TextSpan(text: '  of ${thousands(goal)}', style: t.sec()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // yours, then theirs, in one bar
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 14,
            // yours fills first, then theirs pours in after it
            child: Play(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.linear,
              builder: (context, v, _) => LayoutBuilder(
                builder: (context, c) {
                  final va = Curves.easeOutCubic.transform((v / .55).clamp(0, 1));
                  final vb = Curves.easeOutCubic.transform(((v - .4) / .6).clamp(0, 1));
                  final wa = c.maxWidth * math.min(1, a / goal);
                  return Stack(
                    children: [
                      Container(color: t.infield),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: wa * va,
                        child: Container(color: t.accent),
                      ),
                      Positioned(
                        left: wa,
                        top: 0,
                        bottom: 0,
                        width: c.maxWidth * math.max(0, math.min(1 - a / goal, b / goal)) * vb,
                        child: Container(color: t.ink),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One side of a head-to-head row: the value over a bar that grows away from the middle.
class _Bar extends StatelessWidget {
  const _Bar(this.value, this.frac, this.color, {required this.toLeft});
  final String value;
  final double frac;
  final Color color;
  final bool toLeft;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Column(
      crossAxisAlignment: toLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(value, style: t.x(17, color: color), maxLines: 1),
        const SizedBox(height: 6),
        Container(
          height: 10,
          decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(5)),
          alignment: toLeft ? Alignment.centerRight : Alignment.centerLeft,
          // grows out from the middle
          child: Play(
            delay: const Duration(milliseconds: 250),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                FractionallySizedBox(widthFactor: (frac.clamp(0, 1) * v).clamp(0, 1).toDouble(), child: child),
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Today's track with two runners: you (TrackPainter's own runner, yellow, inside) and your partner
/// (cream, on the outer lane). [theirs] null = not linked yet: the outer lane stays empty.
class _TwoRunners extends CustomPainter {
  _TwoRunners(this.mine, this.theirs, this.t);
  final double mine;
  final double? theirs;
  final Daur t;

  // the runner's lane pushed out one lane, about the infield's centre (201, 125)
  static final _outer = () {
    const sx = 1.09, sy = 1.156;
    final m = Float64List(16)
      ..[0] = sx
      ..[5] = sy
      ..[10] = 1
      ..[12] = 201 * (1 - sx)
      ..[13] = 125 * (1 - sy)
      ..[15] = 1;
    return TrackPainter.lane().transform(m).computeMetrics().first;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    TrackPainter(mine, t).paint(canvas, size);
    canvas.restore();
    final theirs = this.theirs;
    if (theirs == null) return;
    final (s, o) = TrackPainter.fit(size);
    canvas.translate(o.dx, o.dy);
    canvas.scale(s);
    final m = theirs.clamp(0, 400) / 400;
    if (m > 0) {
      canvas.drawPath(
        _outer.extractPath(0, _outer.length * m),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = t.ink.withValues(alpha: .55),
      );
    }
    final p = _outer.getTangentForOffset(_outer.length * m)!.position;
    canvas.drawCircle(p, 11.75, Paint()..color = t.ground);
    canvas.drawCircle(p, 10, Paint()..color = t.ink);
  }

  @override
  bool shouldRepaint(_TwoRunners old) => old.mine != mine || old.theirs != theirs || old.t != t;
}
