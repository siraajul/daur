import 'l10n.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';
import 'cloud.dart';
import 'plan.dart';
import 'steps.dart';
import 'store.dart';
import 'targets.dart';
import 'theme.dart';
import 'today.dart' show Cta, thousands;
import 'track.dart';
import 'visuals.dart';
import 'water_walk.dart' show litres;

/// The very first screens: make an account (Google), then say how Daur will be used. A trainer or
/// a family helper may also track their own fitness; without that they go straight to the people
/// they help. Returning users get their backup back at sign-in and skip the rest.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.store});
  final Store store;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _account = false; // past the sign-in step (signed in, or "not now")
  String _role = 'me';
  bool _own = true; // also tracks their own fitness
  String? _error;

  static const _roles = [
    ('me', Icons.person_rounded, 'Just me', 'My own diet and fitness'),
    (
      'trainer',
      Icons.sports_rounded,
      'I\'m a trainer',
      'Follow my students\' progress',
    ),
    (
      'family',
      Icons.family_restroom_rounded,
      'I help family',
      'Follow a family member\'s diet',
    ),
  ];

  Future<void> _signIn() async {
    final msg = await Cloud.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _error = msg;
      if (msg == null && Cloud.instance.signedIn) _account = true;
    });
  }

  void _go() {
    HapticFeedback.mediumImpact();
    final s = widget.store;
    s.setRole(_role);
    if (_role != 'me' && !_own) {
      s.setHelperOnly(true); // straight to the people they help
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: Cloud.instance,
      builder: (context, _) {
        final c = Cloud.instance;
        final signedIn = c.signedIn;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    children: [
                      Text(
                        tr(context, 'Daur'),
                        style: t.x(40, weight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(context, '12 weeks of meals, walks and the gym'),
                        style: t.sec(),
                      ),
                      const SizedBox(height: 24),
                      // the lap closes once there's an account; smaller then, to leave room for the choice
                      AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: _account || signedIn ? 110 : 160,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: _account || signedIn ? 400 : 100,
                          ),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, m, _) => Center(
                            child: AspectRatio(
                              aspectRatio: 402 / 250,
                              child: CustomPaint(painter: TrackPainter(m, t)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_account && !signedIn) ...[
                        Text(
                          tr(context, 'Make your account'),
                          style: t.title(),
                        ),
                        const SizedBox(height: 8),
                        Tip(
                          Icons.cloud_done_outlined,
                          tr(context, 'Optional cloud backup for a new phone'),
                        ),
                        Tip(
                          Icons.family_restroom_rounded,
                          tr(
                            context,
                            'Needed to follow, or be followed by, a trainer or family',
                          ),
                        ),
                        const SizedBox(height: 16),
                        GoogleButton(busy: c.busy, onPressed: _signIn),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() => _account = true),
                            child: Text(
                              tr(context, 'Not now · this phone only'),
                              style: t.sec(t.ink),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          tr(context, 'How will you use Daur?'),
                          style: t.title(),
                        ),
                        const SizedBox(height: 16),
                        for (final (r, icon, title, sub) in _roles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Semantics(
                              selected: _role == r,
                              inMutuallyExclusiveGroup: true,
                              child: Material(
                                color: _role == r ? t.accent : t.infield,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _role = r;
                                      _own = r != 'family'; // a mother usually just follows; a trainer trains too
                                      _error = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      14,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          icon,
                                          color: _role == r
                                              ? t.onAccent
                                              : t.ink,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tr(context, title),
                                                style: t.body(
                                                  color: _role == r
                                                      ? t.onAccent
                                                      : t.ink,
                                                ),
                                              ),
                                              Text(
                                                tr(context, sub),
                                                style: t.meta(
                                                  _role == r
                                                      ? t.onAccent
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_role != 'me')
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _own,
                            onChanged: (v) => setState(() => _own = v),
                            activeThumbColor: t.ground,
                            activeTrackColor: t.ink,
                            title: Text(
                              tr(context, 'Also track my own fitness'),
                              style: t.body(),
                            ),
                            subtitle: Text(
                              tr(
                                context,
                                _own
                                    ? tr(
                                        context,
                                        'Your own plan, plus a {tab} tab',
                                        {
                                          'tab': tr(
                                            context,
                                            _role == 'trainer'
                                                ? 'Students'
                                                : 'Family',
                                          ),
                                        },
                                      )
                                    : 'Only follow others',
                              ),
                              style: t.meta(),
                            ),
                          ),
                      ],
                      // following people needs an account: sign in right here (skipped earlier)
                      if ((_account || signedIn) &&
                          _role != 'me' &&
                          !signedIn) ...[
                        const SizedBox(height: 8),
                        Tip(
                          Icons.vpn_key_outlined,
                          tr(context, 'Following someone needs an account'),
                        ),
                        const SizedBox(height: 8),
                        GoogleButton(busy: c.busy, onPressed: _signIn),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(tr(context, _error!), style: t.body()),
                      ],
                    ],
                  ),
                ),
                if (_account || signedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _role != 'me' && !signedIn
                        ? Cta(
                            label: tr(context, 'Sign in to continue'),
                            muted: true,
                          )
                        : Cta(
                            label: tr(
                              context,
                              _role != 'me' && !_own
                                  ? 'Enter their code'
                                  : 'Set up my plan',
                            ),
                            onTap: _go,
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
  bool _confirmed = false, _loading = true;
  String? _backupError, _healthError;
  static const _draftKey = 'daur.onboarding.draft.v1';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map;
        _start = DateTime.parse(j['start'] as String);
        _kg = (j['kg'] as num).toDouble().clamp(30, 300);
        _todayKg = (j['todayKg'] as num?)?.toDouble();
        final p = Profile.from(j['profile'] as Map);
        _profile = p.copyWith(
          age: p.age.clamp(14, 90),
          heightCm: p.heightCm.clamp(120, 220),
          activity: p.activity.clamp(0, 2),
          goal: p.goal.clamp(0, 2),
        );
        final savedPage = j['page'] as int;
        _page =
            (j['version'] == 2 || savedPage < 3 || savedPage > 4
                    ? savedPage
                    : savedPage + 1)
                .clamp(0, 5);
      }
    } catch (_) {
      // A damaged draft must never prevent setup from opening.
    }
    final now = DateTime.now();
    final earliest = DateUtils.dateOnly(now)
        .subtract(const Duration(days: laps - 1));
    if (_start.isBefore(earliest) || _start.isAfter(now)) _start = now;
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(_page);
    });
  }

  Future<void> _saveDraft() async {
    if (_loading) return;
    final raw = jsonEncode({
      'start': _start.toIso8601String(),
      'kg': _kg,
      'todayKg': _todayKg,
      'profile': _profile.toJson(),
      'page': _page,
      'version': 2,
    });
    try {
      await (await SharedPreferences.getInstance()).setString(_draftKey, raw);
    } catch (_) {
      // Setup remains usable when device storage is unavailable.
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(() {
      fn();
      if (_page < 5) _confirmed = false;
    });
    _saveDraft();
  }

  Future<void> _editWeight({bool current = false}) async {
    var input = (current ? _todayKg ?? _kg : _kg).toStringAsFixed(1);
    String? error;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            tr(context, current ? 'Today’s weight' : 'Starting weight'),
          ),
          content: TextFormField(
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, 'Weight in kg'),
              helperText: tr(context, '30–300 kg'),
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel')),
            ),
            TextButton(
              onPressed: () {
                final kg = double.tryParse(input.replaceAll(',', '.'));
                if (kg == null || !kg.isFinite || kg < 30 || kg > 300) {
                  update(
                    () => error = tr(
                      context,
                      'Enter a weight between 30 and 300 kg',
                    ),
                  );
                } else {
                  Navigator.pop(context, kg);
                }
              },
              child: Text(tr(context, 'Save')),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (current) {
          _todayKg = value;
        } else {
          _kg = value;
        }
        _confirmed = false;
      });
    }
  }

  int get _lap {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day)
            .difference(DateTime.utc(_start.year, _start.month, _start.day))
            .inDays +
        1;
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page == 5) {
      if (!_confirmed) return;
      widget.store.setProfile(_profile);
      widget.store.finishOnboarding(
        start: _start,
        kg: _kg,
        todayKg: _isToday ? null : _todayKg,
      );
      SharedPreferences.getInstance().then((p) => p.remove(_draftKey));
      HapticFeedback.heavyImpact();
      return;
    }
    _pages.nextPage(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _isToday => DateUtils.isSameDay(_start, DateTime.now());

  /// One ask only: Android locks an app out after repeated denials, so a cancel is respected.
  Future<void> _connect() async {
    setState(() => _connecting = true);
    widget.store.setHealthAsked();
    try {
      if (await Steps.available()) {
        _steps = await Steps.today(ask: true);
      } else if (Steps.supported) {
        await Steps.installHealthConnect();
      }
    } catch (_) {
      _healthError = 'Could not connect. You can enter steps manually and try again from Walk.';
    }
    if (mounted) {
      setState(() {
        _connecting = false;
        _triedConnect = true;
      });
    }
  }

  Future<void> _pickStart() async {
    final d = await pickDate(
      context,
      initial: _start,
      first: DateTime.now().subtract(const Duration(days: laps - 1)),
      last: DateTime.now(),
      help: tr(context, 'Day 1 of the 12-week plan'),
    );
    if (d != null) {
      setState(() {
        _start = d;
        _confirmed = false;
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 6; i++)
                            AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              width: i == _page ? 28 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: i == _page ? t.accent : t.faint,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          tr(context, 'Step {step} of {total}', {
                            'step': _page + 1,
                            'total': 6,
                          }),
                          style: t.meta(),
                        ),
                      ),
                      if (_page > 0)
                        TextButton(
                          onPressed: () => _pages.previousPage(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                          ),
                          child: Text(tr(context, 'Back'), style: t.sec(t.ink)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _lapPage(t),
                      _startPage(t),
                      _goalPage(t),
                      _aboutPage(t),
                      _stepsPage(t),
                      _reviewPage(t),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Cta(
                    label: tr(
                      context,
                      _page == 5
                          ? 'Start my plan'
                          : _page == 4
                          ? 'Review my plan'
                          : 'Next',
                    ),
                    trailing: _page == 1
                        ? tr(context, '{weight} kg', {
                            'weight': _kg.toStringAsFixed(1),
                          })
                        : null,
                    onTap: _lap < 1 || (_page == 5 && !_confirmed)
                        ? null
                        : _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page0Track() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 100),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1200),
    curve: Curves.easeOutCubic,
    builder: (context, m, _) => AspectRatio(
      aspectRatio: 402 / 250,
      child: CustomPaint(painter: TrackPainter(m, Daur.of(context))),
    ),
  );

  Widget _lapPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _page0Track(),
        ),
      ),
      const SizedBox(height: 32),
      Text(tr(context, 'Log your 4 meals a day.'), style: t.title()),
      const SizedBox(height: 24),
      // 4 legs = 1 lap, drawn: each meal and its 100 m
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final m in meals)
            Expanded(
              child: Column(
                children: [
                  IconDisc(mealIcon(m.id), size: 48),
                  const SizedBox(height: 6),
                  Text(
                    tr(context, m.name),
                    style: t.meta(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Tip(
        Icons.flag_outlined,
        tr(context, '{days} days = your 12-week plan', {'days': laps}),
      ),
      Tip(
        Icons.info_outline,
        tr(
          context,
          'The track shows meal logging, not distance walked. Skipped meals are marked separately.',
        ),
      ),
      Tip(
        Icons.swap_horiz_rounded,
        tr(context, 'Ate something else? Log what you ate'),
      ),
    ],
  );

  Widget _startPage(Daur t) {
    final today = DateUtils.isSameDay(_start, DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(tr(context, 'Where you start'), style: t.title()),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Started earlier? Pick your real day 1.'),
          style: t.sec(),
        ),
        const SizedBox(height: 28),
        Text(tr(context, 'Day 1'), style: t.meta()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            groundChip(
              context,
              'Today',
              today,
              () => setState(() => _start = DateTime.now()),
            ),
            groundChip(
              context,
              today
                  ? tr(context, 'Earlier…')
                  : MaterialLocalizations.of(context).formatMediumDate(_start),
              !today,
              _pickStart,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Today is day {day} of {total}', {
            'day': _lap,
            'total': laps,
          }),
          style: t.sec(),
        ),
        const SizedBox(height: 28),
        Text(
          tr(context, _isToday ? 'Starting weight' : 'Weight on day 1'),
          style: t.meta(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _round(
              t,
              Icons.remove,
              () => setState(() => _kg = (_kg - .1).clamp(30, 300)),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _editWeight(),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _kg.toStringAsFixed(1),
                        style: t.x(52, weight: FontWeight.w900),
                      ),
                      TextSpan(text: tr(context, ' kg'), style: t.x(20)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _round(
              t,
              Icons.add,
              () => setState(() => _kg = (_kg + .1).clamp(30, 300)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Example weight · tap the number to enter yours'),
          style: t.meta(),
          textAlign: TextAlign.center,
        ),
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
              child: Text(tr(context, 'Add today\'s weight too')),
            )
          else ...[
            Text(tr(context, 'Today\'s weight'), style: t.meta()),
            const SizedBox(height: 8),
            Row(
              children: [
                _round(
                  t,
                  Icons.remove,
                  () => setState(
                    () => _todayKg = (_todayKg! - .1).clamp(30, 300),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _todayKg!.toStringAsFixed(1),
                          style: t.x(40, weight: FontWeight.w900),
                        ),
                        TextSpan(text: tr(context, ' kg'), style: t.x(18)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _round(
                  t,
                  Icons.add,
                  () => setState(
                    () => _todayKg = (_todayKg! + .1).clamp(30, 300),
                  ),
                ),
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
      style: IconButton.styleFrom(
        backgroundColor: t.ink.withValues(alpha: .18),
        minimumSize: const Size(56, 56),
      ),
    ),
  );

  Widget _chips() => TargetChips(
    kcal: _profile.kcal(_kg),
    protein: _profile.protein(_kg),
    litres: litres(_profile.glasses(_kg)),
  );

  Widget _goalPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text(tr(context, 'What is your goal?'), style: t.title()),
      const SizedBox(height: 12),
      Text(
        tr(
          context,
          'Choose the direction for your next 12 weeks. You can change this later in Your targets.',
        ),
        style: t.sec(),
      ),
      const SizedBox(height: 28),
      for (final (i, name) in Profile.goalNames.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            selected: _profile.goal == i,
            inMutuallyExclusiveGroup: true,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _profile.goal == i
                    ? t.accent
                    : Colors.transparent,
                foregroundColor: _profile.goal == i ? t.onAccent : t.ink,
                side: BorderSide(color: _profile.goal == i ? t.accent : t.lane),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onPressed: () =>
                  setState(() => _profile = _profile.copyWith(goal: i)),
              child: Text(
                tr(context, '$name weight'),
                style: t.body(color: _profile.goal == i ? t.onAccent : t.ink),
              ),
            ),
          ),
        ),
      const SizedBox(height: 24),
      Text(tr(context, _profile.paceText), style: t.body()),
      const SizedBox(height: 12),
      Text(
        tr(
          context,
          'Your body details on the next step help estimate a starting calorie target.',
        ),
        style: t.sec(),
      ),
    ],
  );

  Widget _aboutPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text(tr(context, 'Your body details'), style: t.title()),
      const SizedBox(height: 8),
      Text(
        tr(
          context,
          'These are example values. Check every detail before starting. {pace}.',
          {'pace': tr(context, _profile.paceText)},
        ),
        style: t.sec(),
      ),
      const SizedBox(height: 20),
      ProfileFields(
        showGoal: false,
        value: _profile,
        onChanged: (p) => setState(() {
          _profile = p;
          _confirmed = false;
        }),
      ),
      const SizedBox(height: 24),
      Text(tr(context, 'Your day'), style: t.meta()),
      const SizedBox(height: 10),
      _chips(),
    ],
  );

  Widget _stepsPage(Daur t) {
    final connected = _steps != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(tr(context, 'Steps from your phone'), style: t.title()),
        const SizedBox(height: 12),
        Steps.supported
            ? Tip(
                Icons.favorite_border_rounded,
                tr(
                  context,
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Read step totals from Apple Health. Connecting is optional.'
                      : 'Read step totals from Health Connect. Connecting is optional.',
                ),
              )
            : Tip(
                Icons.edit_outlined,
                tr(context, 'Type steps on the Walk row'),
              ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Recorded step totals may be included in cloud backups when signed in, and in summaries shared with people you authorise. You can connect later from Walk.',
          ),
          style: t.sec(),
        ),
        const SizedBox(height: 28),
        if (Steps.supported) ...[
          if (connected)
            Row(
              children: [
                Icon(Icons.check_circle, color: t.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, 'Connected · {steps} steps today', {
                      'steps': thousands(_steps!),
                    }),
                    style: t.body(),
                  ),
                ),
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
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(t.onAccent),
                            ),
                          )
                        : Icon(Icons.favorite_border, color: t.onAccent),
                    label: Text(
                      tr(context, 'Connect'),
                      style: t.body(color: t.onAccent),
                    ),
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
                  child: Text(
                    tr(context, 'Later'),
                    style: t.body(color: t.ink),
                  ),
                ),
              ],
            ),
          if (_triedConnect && !connected) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Later: Health → Sharing → Apps → Daur'
                    : 'Later: Settings → Health Connect → Daur',
              ),
              style: t.sec(),
            ),
          ],
        ],
        const SizedBox(height: 32),
        if (_healthError != null)
          Text(tr(context, _healthError!), style: t.body()),
        Text(tr(context, 'Back up'), style: t.meta()),
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
                      tr(context, 'Signed in · {email}', {
                        'email': c.user!.email ?? '',
                      }),
                      style: t.body(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.account_circle_outlined, color: t.ink),
                ],
              );
            }
            return GoogleButton(
              busy: c.busy,
              onPressed: () async {
                final error = await c.signInWithGoogle();
                if (mounted) setState(() => _backupError = error);
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Optional · sign-in enables backup; check its status in Your data.',
          ),
          style: t.meta(),
        ),
        if (_backupError != null)
          Text(tr(context, _backupError!), style: t.body()),
        const SizedBox(height: 32),
        Text(tr(context, 'Your targets'), style: t.meta()),
        const SizedBox(height: 10),
        _chips(),
      ],
    );
  }

  Widget _reviewPage(Daur t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text(tr(context, 'Review your plan'), style: t.title()),
      const SizedBox(height: 12),
      Text(
        tr(
          context,
          'Starting estimates, adjustable in Your targets. Use Back to correct any detail.',
        ),
        style: t.sec(),
      ),
      const SizedBox(height: 20),
      for (final row in [
        ('Goal', '${Profile.goalNames[_profile.goal]} weight'),
        (
          'Start',
          tr(context, '{date} · day {day} of {total}', {
            'date': MaterialLocalizations.of(context).formatMediumDate(_start),
            'day': _lap,
            'total': laps,
          }),
        ),
        (
          'Starting weight',
          tr(context, '{weight} kg', {'weight': _kg.toStringAsFixed(1)}),
        ),
        (
          'Body details',
          tr(context, '{sex} · {age} years · {height} cm', {
            'sex': tr(context, _profile.male ? 'Man' : 'Woman'),
            'age': _profile.age,
            'height': _profile.heightCm,
          }),
        ),
        ('Daily activity', Profile.activityNames[_profile.activity]),
        (
          'Calories per day',
          tr(context, '{calories} kcal', {
            'calories': thousands(_profile.kcal(_kg)),
          }),
        ),
        (
          'Protein per day',
          tr(context, '{low}–{high} g', {
            'low': _profile.protein(_kg).$1,
            'high': _profile.protein(_kg).$2,
          }),
        ),
        (
          'Water per day',
          tr(context, '{water} L', {'water': litres(_profile.glasses(_kg))}),
        ),
        ('Movement', 'Build towards 7,000–10,000 steps a day'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, row.$1), style: t.meta()),
              const SizedBox(height: 4),
              Text(tr(context, row.$2), style: t.body()),
            ],
          ),
        ),
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        activeColor: t.accent,
        checkColor: t.onAccent,
        onChanged: (v) => setState(() => _confirmed = v ?? false),
        title: Text(
          tr(
            context,
            'I have checked my weight, age, height, goal and activity.',
          ),
          style: t.body(),
        ),
      ),
    ],
  );
}
