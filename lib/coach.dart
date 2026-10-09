import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cloud.dart';
import 'food.dart' show FoodScreen;
import 'progress.dart' show ProgressScreen;
import 'reminders_screen.dart';
import 'store.dart';
import 'plan.dart' show meals;
import 'today.dart' show thousands;
import 'visuals.dart';
import 'theme.dart';
import 'widget_sync.dart';

/// Onboarding after onboarding (design/onboarding-research.md): the first-win tip, one contextual
/// hint a day, and the end-of-cut choice, as a single card at the top of Today.
class CoachCard extends StatelessWidget {
  const CoachCard({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    if (s.needsFinishChoice) return _finish(context);
    if (s.showFirstWin) {
      return _Card(
        icon: Icons.touch_app_outlined,
        title: 'Log your first meal',
        body: 'Tap Breakfast below.',
        visual: const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [_Pill(Icons.check_rounded, 'As planned'), _Pill(Icons.swap_horiz_rounded, 'Something else')],
        ),
        onClose: () => s.dismissHint('first-win'),
      );
    }
    // a stall is about now, so it skips the one-card-a-day queue (once per cut week)
    final stall = 'stall-${s.cutWeek}';
    if (s.stalled && !s.seenHints.contains(stall)) {
      return _Card(
        icon: Icons.trending_flat_rounded,
        title: 'Two weeks flat',
        body: '−${(s.twoWeekDrop ?? 0).toStringAsFixed(1)} kg in 2 weeks. Pick one for 2 weeks:',
        visual: const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(Icons.rice_bowl_outlined, '−150 kcal'),
            _Pill(Icons.directions_walk_rounded, '+2,000 steps'),
          ],
        ),
        primary: ('Got it', () => s.dismissHint(stall)),
      );
    }
    final h = s.coachCard();
    if (h == null) return const SizedBox.shrink();
    void done() => s.dismissHint(h);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return switch (h) {
      'reminders' => _Card(
        icon: Icons.notifications_outlined,
        title: 'A nudge at each meal?',
        body: 'Quiet once logged.',
        visual: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final m in meals) _Pill(mealIcon(m.id), m.window.split('–').first)],
        ),
        primary: (
          'Turn on reminders',
          () async {
            if (await RemindersScreen.turnOn(context, s)) done();
          },
        ),
        secondary: ('Not now', done),
      ),
      'backup' => _Card(
        icon: Icons.cloud_upload_outlined,
        title: 'Back up your data',
        body: 'Safe on a new phone. One account each.',
        primary: (
          'Sign in with Google',
          () async {
            if (await Cloud.instance.signInWithGoogle() == null && Cloud.instance.signedIn) done();
          },
        ),
        secondary: ('Not now', done),
      ),
      'widget' => _Card(
        icon: Icons.widgets_outlined,
        title: 'Day 1 done. Add the home-screen widget?',
        body: ios ? 'Hold the home screen → Edit → Add Widget → Daur' : 'Log water and meals in one tap.',
        primary: ios
            ? ('Got it', done)
            : (
                'Add widget',
                () async {
                  await WidgetSync.pin();
                  done();
                },
              ),
        secondary: ios ? null : ('Not now', done),
      ),
      'pace' => _pace(s, done),
      'junk-rule' => _Card(
        icon: Icons.fastfood_outlined,
        title: 'Now: 1 junk meal a week',
        body: 'One meal, never a cheat day.',
        visual: const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [_Pill(Icons.lunch_dining_outlined, '1 burger'), _Pill(Icons.local_pizza_outlined, '2 slices')],
        ),
        primary: (
          'Food guide',
          () {
            done();
            Navigator.push(context, MaterialPageRoute(builder: (_) => FoodScreen(store: s)));
          },
        ),
        secondary: ('Got it', done),
      ),
      'junk-first' => _Card(
        icon: Icons.fastfood_outlined,
        title: 'First junk meal',
        body: 'Fine once. Month 1: keep it rare.',
        primary: (
          'Junk rule',
          () {
            done();
            Navigator.push(context, MaterialPageRoute(builder: (_) => FoodScreen(store: s)));
          },
        ),
        secondary: ('Got it', done),
      ),
      'steps-ios' => _Card(
        icon: Icons.directions_walk_rounded,
        title: 'No steps from Apple Health',
        body: 'Health → Sharing → Apps → Daur → Steps',
        primary: ('Got it', done),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Lap 28: four weeks of change on the same gauge as Progress, against the goal's pace.
  Widget _pace(Store s, VoidCallback done) {
    final now = s.trendKg ?? s.latestKg ?? s.startKg;
    final d = now - s.startKg;
    return _Card(
      icon: Icons.flag_outlined,
      title: 'Four weeks in',
      body: '${d <= 0 ? '−' : '+'}${d.abs().toStringAsFixed(1)} kg so far',
      visual: PaceGauge(change: d / 4, goal: s.goal, kcal: s.kcalGoal),
      primary: ('Got it', done),
    );
  }

  Widget _finish(BuildContext context) {
    final s = store;
    final d = (s.latestKg ?? s.startKg) - s.startKg;
    return _Card(
      icon: Icons.military_tech_outlined,
      title: 'Day 84. The plan is done',
      body:
          '${d.abs() >= .1 ? '${d < 0 ? '−' : '+'}${d.abs().toStringAsFixed(1)} kg · ' : ''}maintenance is ~${thousands(s.bodyBurn)} kcal',
      primary: (
        'Another 12 weeks',
        () {
          HapticFeedback.heavyImpact();
          s.chooseFinish('again');
        },
      ),
      secondary: ('2 weeks at maintenance', () => s.chooseFinish('maintenance')),
      tertiary: ('Keep logging', () => s.chooseFinish('keep')),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    this.body,
    this.visual,
    this.primary,
    this.secondary,
    this.tertiary,
    this.onClose,
  });
  final IconData icon;
  final String title;
  final String? body; // one short line at most
  final Widget? visual;
  final (String, VoidCallback)? primary, secondary, tertiary;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.ink.withValues(alpha: .14), shape: BoxShape.circle),
                child: Icon(icon, color: t.ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body()),
                    if (body != null) Text(body!, style: t.sec()),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: t.ink2, size: 20),
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (visual != null) Padding(padding: const EdgeInsets.only(top: 12, right: 8), child: visual),
          if (primary != null || secondary != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (primary != null)
                  FilledButton(
                    onPressed: primary!.$2,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.onAccent,
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(primary!.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                for (final b in [secondary, tertiary])
                  if (b != null)
                    OutlinedButton(
                      onPressed: b.$2,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.ink,
                        side: BorderSide(color: t.lane),
                        minimumSize: const Size(0, 44),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(b.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// After 2+ days away: no guilt, no reset. Today is just the next lap.
Future<void> welcomeBack(BuildContext context, Store s, int daysAway) => showModalBottomSheet(
  context: context,
  builder: (ctx) {
    final t = Daur.of(ctx);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAY ${s.lap}', style: t.x(22, color: t.sheetRed)),
            Text('Welcome back', style: t.title(t.sheetInk)),
            const SizedBox(height: 6),
            Text('$daysAway days away · nothing to make up', style: t.sec(t.sheetInk2)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ProgressScreen.logWeight(context, s);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Weigh in', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Go to today', style: t.sec(t.sheetInk2)),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// A small icon + label pill inside a coach card.
class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: t.lane, width: 1.5)),
      ),
      child: Stat(icon, label, color: t.ink, size: 14),
    );
  }
}
