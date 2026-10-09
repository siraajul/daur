import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cloud.dart';
import 'plan.dart';
import 'steps.dart';
import 'store.dart';
import 'targets.dart';
import 'theme.dart';
import 'today.dart' show Cta, niceDate, thousands;
import 'track.dart';
import 'visuals.dart';
import 'water_walk.dart' show litres;

/// First run, four steps: what a lap is, where you start, about you (the targets), steps.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});
  final Store store;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  late DateTime _start = DateTime.parse(widget.store.startDay);
  late double _kg = widget.store.startKg;
  double? _todayKg; // only when day 1 is in the past
  Profile _profile = const Profile(male: true, age: 30, heightCm: 170);
  int? _steps;
  bool _connecting = false, _triedConnect = false;

  int get _lap {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(_start.year, _start.month, _start.day)).inDays +
        1;
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page == 3) {
      widget.store.setProfile(_profile);
      widget.store.finishOnboarding(start: _start, kg: _kg, todayKg: _isToday ? null : _todayKg);
      HapticFeedback.heavyImpact();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  bool get _isToday => DateUtils.isSameDay(_start, DateTime.now());

  /// Skip = start now with the original plan (day 1 today, 109.0 kg); Your targets changes it later.
  void _skip() {
    HapticFeedback.selectionClick();
    widget.store.finishOnboarding(start: _start, kg: _kg);
  }

  /// One ask only: Android locks an app out after repeated denials, so a cancel is respected.
  Future<void> _connect() async {
    setState(() => _connecting = true);
    widget.store.setHealthAsked();
    if (await Steps.available()) {
      _steps = await Steps.today(ask: true);
    } else if (Steps.supported) {
      await Steps.installHealthConnect();
    }
    if (mounted) {
      setState(() {
        _connecting = false;
        _triedConnect = true;
      });
    }
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: laps * 2)),
      lastDate: DateTime.now(),
      helpText: 'Day 1 of the 12-week plan',
    );
    if (d != null) setState(() => _start = d);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: i == _page ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _page ? t.accent : t.faint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (_page < 3)
                    TextButton(
                      onPressed: _skip,
                      child: Text('Skip', style: t.sec(t.ink)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [_lapPage(t), _startPage(t), _aboutPage(t), _stepsPage(t)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Cta(
                label: _page == 3 ? 'Start day $_lap' : 'Next',
                trailing: _page == 1 ? '${_kg.toStringAsFixed(1)} kg' : null,
                onTap: _lap < 1 ? null : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page0Track() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 100),
    duration: const Duration(milliseconds: 1200),
    curve: Curves.easeOutCubic,
    builder: (context, m, _) => AspectRatio(
      aspectRatio: 402 / 250,
      child: CustomPaint(painter: TrackPainter(m, Daur.of(context))),
    ),
  );

  Widget _lapPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      _page0Track(),
      const SizedBox(height: 32),
      Text('Log your 4 meals a day.', style: t.title()),
      const SizedBox(height: 24),
      // 4 legs = 1 lap, drawn: each meal and its 100 m
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final m in meals)
            Column(
              children: [
                IconDisc(mealIcon(m.id), size: 48),
                const SizedBox(height: 6),
                Text(m.name, style: t.meta()),
              ],
            ),
        ],
      ),
      const SizedBox(height: 20),
      const Tip(Icons.flag_outlined, '$laps days = your 12-week plan'),
      const Tip(Icons.swap_horiz_rounded, 'Ate something else? Log what you ate'),
    ],
  );

  Widget _startPage(Daur t) {
    final today = DateUtils.isSameDay(_start, DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text('Where you start', style: t.title()),
        const SizedBox(height: 8),
        Text('Started earlier? Pick your real day 1.', style: t.sec()),
        const SizedBox(height: 28),
        Text('Day 1', style: t.meta()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            groundChip(context, 'Today', today, () => setState(() => _start = DateTime.now())),
            groundChip(context, today ? 'Earlier…' : niceDate(_start), !today, _pickStart),
          ],
        ),
        const SizedBox(height: 8),
        Text('Today is day $_lap of $laps', style: t.sec()),
        const SizedBox(height: 28),
        Text(_isToday ? 'Starting weight' : 'Weight on day 1', style: t.meta()),
        const SizedBox(height: 8),
        Row(
          children: [
            _round(t, Icons.remove, () => setState(() => _kg = (_kg - .1).clamp(30, 300))),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _kg.toStringAsFixed(1),
                      style: t.x(52, weight: FontWeight.w900),
                    ),
                    TextSpan(text: ' kg', style: t.x(20)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _round(t, Icons.add, () => setState(() => _kg = (_kg + .1).clamp(30, 300))),
          ],
        ),
        const SizedBox(height: 8),
        Text('Morning, before breakfast · hold ± to go faster', style: t.meta(), textAlign: TextAlign.center),
        if (!_isToday) ...[
          const SizedBox(height: 24),
          // a past day 1 leaves no current weight: offer today's, optional
          if (_todayKg == null)
            OutlinedButton(
              onPressed: () => setState(() => _todayKg = _kg),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.ink,
                side: BorderSide(color: t.lane),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Add today\'s weight too'),
            )
          else ...[
            Text('Today\'s weight', style: t.meta()),
            const SizedBox(height: 8),
            Row(
              children: [
                _round(t, Icons.remove, () => setState(() => _todayKg = (_todayKg! - .1).clamp(30, 300))),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _todayKg!.toStringAsFixed(1),
                          style: t.x(40, weight: FontWeight.w900),
                        ),
                        TextSpan(text: ' kg', style: t.x(18)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _round(t, Icons.add, () => setState(() => _todayKg = (_todayKg! + .1).clamp(30, 300))),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _round(Daur t, IconData i, VoidCallback f) => GestureDetector(
    onLongPress: () {
      for (var k = 0; k < 10; k++) {
        f();
      }
      HapticFeedback.selectionClick();
    },
    child: IconButton.filledTonal(
      tooltip: i == Icons.add ? 'Increase' : 'Decrease',
      onPressed: () {
        f();
        HapticFeedback.selectionClick();
      },
      icon: Icon(i, color: t.ink),
      iconSize: 28,
      style: IconButton.styleFrom(backgroundColor: t.ink.withValues(alpha: .18), minimumSize: const Size(56, 56)),
    ),
  );

  Widget _chips() =>
      TargetChips(kcal: _profile.kcal(_kg), protein: _profile.protein(_kg), litres: litres(_profile.glasses(_kg)));

  Widget _aboutPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text('About you', style: t.title()),
      const SizedBox(height: 8),
      Text('Sets your targets · about 0.5 kg a week', style: t.sec()),
      const SizedBox(height: 20),
      ProfileFields(value: _profile, onChanged: (p) => setState(() => _profile = p)),
      const SizedBox(height: 24),
      Text('Your day', style: t.meta()),
      const SizedBox(height: 10),
      _chips(),
    ],
  );

  Widget _stepsPage(Daur t) {
    final connected = _steps != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text('Steps from your phone', style: t.title()),
        const SizedBox(height: 12),
        Steps.supported
            ? Tip(
                Icons.favorite_border_rounded,
                defaultTargetPlatform == TargetPlatform.iOS
                    ? 'From Apple Health · steps only, stays on your phone'
                    : 'From Health Connect · steps only, stays on your phone',
              )
            : const Tip(Icons.edit_outlined, 'Type steps on the Walk row'),
        const SizedBox(height: 28),
        if (Steps.supported) ...[
          if (connected)
            Row(
              children: [
                Icon(Icons.check_circle, color: t.accent),
                const SizedBox(width: 10),
                Expanded(child: Text('Connected · ${thousands(_steps!)} steps today', style: t.body())),
              ],
            )
          else if (!_triedConnect)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: t.onAccent),
                          )
                        : Icon(Icons.favorite_border, color: t.onAccent),
                    label: Text('Connect', style: t.body(color: t.onAccent)),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _triedConnect = true),
                  child: Text('Later', style: t.body(color: t.ink)),
                ),
              ],
            ),
          if (_triedConnect && !connected) ...[
            const SizedBox(height: 12),
            Text(
              defaultTargetPlatform == TargetPlatform.iOS
                  ? 'Later: Health → Sharing → Apps → Daur'
                  : 'Later: Settings → Health Connect → Daur',
              style: t.sec(),
            ),
          ],
        ],
        const SizedBox(height: 32),
        Text('Back up', style: t.meta()),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: Cloud.instance,
          builder: (context, _) {
            final c = Cloud.instance;
            if (c.user != null) {
              return Row(
                children: [
                  const GoogleG(size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Signed in · ${c.user!.email ?? ''}',
                      style: t.body(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.cloud_done_outlined, color: t.ink),
                ],
              );
            }
            return GoogleButton(busy: c.busy, onPressed: () => c.signInWithGoogle());
          },
        ),
        const SizedBox(height: 8),
        Text('Optional · back on a new phone', style: t.meta()),
        const SizedBox(height: 32),
        Text('Your targets', style: t.meta()),
        const SizedBox(height: 10),
        _chips(),
      ],
    );
  }
}
