import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity_anim.dart';
import 'cloud.dart';
import 'store.dart';
import 'theme.dart';
import 'l10n.dart';
import 'today.dart' show Cta, thousands;
import 'visuals.dart';

/// Drawer → Family: who has closed today, everyone's streak. Join with a code, share yours.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.store});
  final Store store;
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

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
        final s = widget.store, code = s.familyId;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageHeader(tr(context, 'Family')),
                SizedBox(height: 16),

                if (!c.signedIn) ...[
                  Tip(
                    Icons.groups_outlined,
                    tr(
                      context,
                      'See who has closed today, and everyone\'s streak',
                    ),
                  ),
                  SizedBox(height: 16),
                  GoogleButton(
                    busy: c.busy,
                    onPressed: () => c.signInWithGoogle(),
                  ),
                ] else if (code == null) ...[
                  Tip(
                    Icons.groups_outlined,
                    tr(
                      context,
                      'See who has closed today, and everyone\'s streak',
                    ),
                  ),
                  Tip(
                    Icons.lock_outline_rounded,
                    tr(context, 'Only people with the code can see the board'),
                  ),
                  SizedBox(height: 16),
                  Cta(
                    label: tr(context, 'Start a family board'),
                    onTap: _busy ? null : () => _run(c.createFamily),
                  ),
                  SizedBox(height: 24),
                  Text(tr(context, 'Or join one'), style: t.meta()),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          style: t.x(20),
                          decoration: InputDecoration(
                            hintText: tr(context, 'CODE'),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => c.joinFamily(_code.text)),
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.onAccent,
                        ),
                        child: Text(tr(context, 'Join')),
                      ),
                    ],
                  ),
                ] else ...[
                  // the code to share, big and copyable
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(tr(context, 'Code copied')),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: t.infield,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(context, 'Family code · tap to copy'),
                                  style: t.meta(),
                                ),
                                Text(
                                  code,
                                  style: t.x(26, weight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.copy_rounded, color: t.ink),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: c.board(code),
                    builder: (context, snap) {
                      final rows = [...?snap.data];
                      int legs(Map r) =>
                          r['day'] == s.today ? (r['legs'] as int? ?? 0) : 0;
                      rows.sort((a, b) {
                        final l = legs(b).compareTo(legs(a));
                        return l != 0
                            ? l
                            : (b['streak'] as int? ?? 0).compareTo(
                                a['streak'] as int? ?? 0,
                              );
                      });
                      if (snap.hasError) {
                        return Text(
                          tr(context, 'Couldn\'t load the board.'),
                          style: t.sec(),
                        );
                      }
                      if (!snap.hasData) {
                        return Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      }
                      return Column(
                        children: [
                          for (final (i, r) in rows.indexed)
                            SlideIn(
                              i: i,
                              child: _Member(
                                row: r,
                                legs: legs(r),
                                me: r['uid'] == c.user?.uid,
                                week: raceWeekStart(s.today),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  TextButton(
                    onPressed: () => c.leaveFamily(),
                    child: Text(
                      tr(context, 'Leave this board'),
                      style: t.sec(t.ink),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(_error!, style: t.body()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Member extends StatelessWidget {
  const _Member({
    required this.row,
    required this.legs,
    required this.me,
    required this.week,
  });
  final Map<String, dynamic> row;
  final int legs;
  final bool me;
  final String week; // this race week: older rows' extra kcal don't count

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final name = row['name'] as String? ?? '';
    final photo = row['photoUrl'] as String?;
    final streak = row['streak'] as int? ?? 0;
    final extra = row['week'] == week ? (row['extra'] as num? ?? 0).toInt() : 0;
    return Container(
      constraints: BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.rule, width: .5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: t.infield,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(name.isEmpty ? '?' : name[0], style: t.body()),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me ? tr(context, "{name} (you)", {"name": name}) : name,
                  style: t.body(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // today's four meals as dots
                Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 12,
                        height: 12,
                        margin: EdgeInsets.only(right: 4, top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < legs
                              ? (legs == 4 ? t.accent : t.ink)
                              : null,
                          border: Border.all(
                            color: i < legs
                                ? (legs == 4 ? t.accent : t.ink)
                                : t.lane,
                            width: 1.5,
                          ),
                        ),
                      ),
                    if (row['perfect'] == true && legs == 4) ...[
                      SizedBox(width: 4),
                      Icon(Icons.star_rounded, size: 16, color: t.accent),
                    ],
                    // kcal over their own target this week
                    if (extra > 0) ...[
                      SizedBox(width: 8),
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: t.accent,
                      ),
                      Flexible(
                        child: Text(
                          tr(context, "+{amount} kcal this week", {
                            "amount": thousands(extra),
                          }),
                          style: t.meta(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_fire_department_rounded,
            color: streak > 0 ? t.accent : t.faint,
          ),
          SizedBox(width: 2),
          Text('$streak', style: t.x(20)),
        ],
      ),
    );
  }
}
