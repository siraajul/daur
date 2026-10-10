import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'activity_anim.dart';
import 'cloud.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart' show Cta, thousands;
import 'water_walk.dart' show litres;
import 'visuals.dart';

/// Menu → Friends: a board of up to 20 friends and this week's leaderboard. Points are the couple
/// race's (up to 300 a day for meals, water and steps, each against your own targets), so a small
/// eater and a big one race fairly. The week runs Saturday to Friday.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.store});
  final Store store;
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String _by = 'points'; // which leaderboard

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
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = Cloud.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, c]),
      builder: (context, _) {
        final s = widget.store, code = s.friendsId;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const PageHeader('Friends', sub: 'This week\'s leaderboard'),
                const SizedBox(height: 16),
                if (!c.signedIn) ...[
                  const Tip(Icons.emoji_events_outlined, 'Race your friends every week: meals, water, steps'),
                  const SizedBox(height: 16),
                  GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle()),
                ] else if (code == null) ...[
                  const Tip(Icons.emoji_events_outlined, 'Race your friends every week: meals, water, steps'),
                  const Tip(Icons.balance_rounded, 'Each against your own targets, so it\'s fair'),
                  const Tip(Icons.lock_outline_rounded, 'Only people with the code see the board'),
                  const SizedBox(height: 16),
                  Cta(label: 'Start a friends group', onTap: _busy ? null : () => _run(() => c.createBoard('friends'))),
                  const SizedBox(height: 24),
                  Text('Or join one', style: t.meta()),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          style: t.x(20),
                          decoration: InputDecoration(
                            hintText: 'CODE',
                            hintStyle: t.x(20, color: t.faint),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _busy ? null : () => _run(() => c.joinBoard('friends', _code.text)),
                        style: FilledButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                ] else ...[
                  _CodeCard(code: code),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (key, label, icon, _, _) in boards)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(icon, size: 18, color: key == _by ? t.onAccent : t.ink),
                              label: Text(label, style: t.sec(key == _by ? t.onAccent : t.ink)),
                              selected: key == _by,
                              showCheckmark: false,
                              selectedColor: t.accent,
                              backgroundColor: t.infield,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _by = key);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: c.board(code),
                    builder: (context, snap) {
                      if (snap.hasError) return Text('Couldn\'t load the board.', style: t.sec());
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
                      // a new category raises the podium again
                      return Leaderboard(
                        key: ValueKey(_by),
                        rows: snap.data!,
                        me: c.user?.uid,
                        today: s.today,
                        by: _by,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => c.leaveBoard('friends'),
                    child: Text('Leave this group', style: t.sec(t.ink)),
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

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Group code', style: t.meta()),
                Text(code, style: t.x(26, weight: FontWeight.w900)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Share the code',
            icon: Icon(Icons.ios_share_rounded, color: t.ink),
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Race me on Daur this week: install it, open Menu → Friends and enter $code'),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy_rounded, color: t.ink),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
          ),
        ],
      ),
    );
  }
}

/// What the leaderboard can rank by: (row field, chip, icon, how a value reads, what it counts).
const boards = <(String, String, IconData, String Function(int), String)>[
  (
    'points',
    'Overall',
    Icons.emoji_events_outlined,
    _plain,
    'Up to 300 a day: 100 each for meals, water and steps, against your own targets',
  ),
  ('steps', 'Steps', Icons.directions_walk_rounded, _plain, 'Steps walked this week'),
  ('lifted', 'Lifted', Icons.fitness_center_rounded, _kg, 'kg × reps over every set logged this week'),
  ('full', 'Consistency', Icons.event_available_rounded, _days, 'Days with all four meals logged this week'),
  ('water', 'Water', Icons.water_drop_outlined, _litres, 'Water drunk this week'),
];

String _plain(int n) => thousands(n);
String _kg(int n) => '${thousands(n)} kg';
String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
String _litres(int n) => '${litres(n)} L';

/// This week's ranking by one of [boards]: the top three on a podium that rises in, everyone else in
/// a list with a bar against the leader, their streak and today's meals. A longer streak breaks a tie.
class Leaderboard extends StatelessWidget {
  const Leaderboard({super.key, required this.rows, required this.me, required this.today, this.by = 'points'});
  final List<Map<String, dynamic>> rows; // board rows: name, photoUrl, week, streak, legs, day, and the counts
  final String? me;
  final String today;
  final String by; // a field of [boards]

  /// What counts: this race week's only (a row from last week is 0 until they open Daur).
  int value(Map r) => r['week'] == raceWeekStart(today) ? (r[by] as num? ?? 0).toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final ranked = [...rows]
      ..sort((a, b) {
        final p = value(b).compareTo(value(a));
        return p != 0 ? p : (b['streak'] as num? ?? 0).compareTo(a['streak'] as num? ?? 0);
      });
    final day = DateTime.parse(today).difference(DateTime.parse(raceWeekStart(today))).inDays + 1;
    final top = math.max(1, ranked.isEmpty ? 1 : value(ranked.first));
    final (_, _, _, format, counts) = boards.firstWhere((b) => b.$1 == by);
    final mine = ranked.indexWhere((r) => r['uid'] == me);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(day >= 7 ? 'Last day · resets tomorrow' : 'Day $day of 7 · resets Saturday', style: t.meta()),
            ),
            if (mine >= 0) Text('You\'re ${_ordinal(mine + 1)}', style: t.meta(t.ink)),
          ],
        ),
        const SizedBox(height: 8),
        _Podium(top3: ranked.take(3).toList(), value: value, format: format, me: me),
        const SizedBox(height: 8),
        for (final (i, r) in ranked.indexed.skip(3))
          SlideIn(
            i: i - 3,
            after: const Duration(milliseconds: 900),
            child: _RankRow(
              rank: i + 1,
              row: r,
              value: value(r),
              text: format(value(r)),
              top: top,
              me: r['uid'] == me,
              today: today,
            ),
          ),
        const SizedBox(height: 12),
        Text(counts, style: t.meta()),
      ],
    );
  }

  static String _ordinal(int n) =>
      '$n${n % 100 >= 11 && n % 100 <= 13 ? 'th' : switch (n % 10) {
              1 => 'st',
              2 => 'nd',
              3 => 'rd',
              _ => 'th',
            }}';
}

/// Second, first, third: the blocks rise from the floor one after another (third, second, then
/// first), the faces drop onto them, and the winner gets a crown that bounces in last.
class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.value, required this.format, required this.me});
  final List<Map<String, dynamic>> top3;
  final int Function(Map) value;
  final String Function(int) format;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    if (top3.isEmpty) return const SizedBox.shrink();
    // place → (index in top3, block height, when it rises)
    const places = [(1, 86.0, 250), (0, 118.0, 450), (2, 62.0, 50)];
    return SizedBox(
      height: 290,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, h, delay) in places)
            Expanded(
              child: i >= top3.length
                  ? const SizedBox.shrink()
                  : Play(
                      delay: Duration(milliseconds: delay),
                      duration: const Duration(milliseconds: 1300),
                      curve: Curves.linear,
                      builder: (context, v, _) {
                        final r = top3[i];
                        final rise = Curves.elasticOut.transform((v / .6).clamp(0, 1));
                        final drop = Curves.bounceOut.transform(((v - .3) / .5).clamp(0, 1));
                        final crown = Curves.elasticOut.transform(((v - .7) / .3).clamp(0, 1));
                        final name = (r['name'] as String? ?? '').split(' ').first;
                        final photo = r['photoUrl'] as String?;
                        final first = i == 0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (first)
                              Transform.scale(
                                scale: crown,
                                child: Icon(Icons.emoji_events_rounded, color: t.accent, size: 30),
                              ),
                            Opacity(
                              opacity: drop.clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, -40 * (1 - drop)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: first ? t.accent : t.ink, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: first ? 26 : 21,
                                    backgroundColor: t.infield,
                                    foregroundImage: photo == null ? null : NetworkImage(photo),
                                    child: Text(name.isEmpty ? '?' : name[0], style: t.body()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r['uid'] == me ? 'You' : name,
                              style: t.body(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              format((value(r) * rise.clamp(0, 1)).round()),
                              style: t.x(15, color: t.ink2),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: h * rise.clamp(0, 1.08),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: first ? t.accent : t.infield,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              ),
                              child: rise > .5
                                  ? Text('${i + 1}', style: t.x(28, color: first ? t.onAccent : t.ink))
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

/// Fourth place on: rank, face, name with a bar against the leader, streak, today's meals.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.row,
    required this.value,
    required this.text,
    required this.top,
    required this.me,
    required this.today,
  });
  final int rank, value, top;
  final String text;
  final Map<String, dynamic> row;
  final bool me;
  final String today;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final name = row['name'] as String? ?? '';
    final photo = row['photoUrl'] as String?;
    final streak = (row['streak'] as num? ?? 0).toInt();
    final legs = row['day'] == today ? (row['legs'] as num? ?? 0).toInt() : 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: me ? t.infield.withValues(alpha: .6) : null,
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              style: t.x(17, color: t.ink2),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 18,
            backgroundColor: t.infield,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(name.isEmpty ? '?' : name[0], style: t.meta(t.ink)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        me ? '$name (you)' : name,
                        style: t.body(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < legs ? t.ink : null,
                          border: Border.all(color: i < legs ? t.ink : t.lane),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Play(
                    delay: const Duration(milliseconds: 1000),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: (value / top * v).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      color: me ? t.accent : t.ink,
                      backgroundColor: t.infield,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(text, style: t.x(16)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 14, color: streak > 0 ? t.accent : t.faint),
                  Text('$streak', style: t.meta()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
