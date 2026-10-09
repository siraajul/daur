import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';

import 'adaptive.dart';
import 'badges.dart' show checkBadges;
import 'cloud.dart';
import 'firebase_options.dart';
import 'family.dart';
import 'fasting.dart' show FastingScreen;
import 'food.dart' show FoodScreen;
import 'food_db.dart';
import 'gym.dart';
import 'live.dart';
import 'onboarding.dart';
import 'plan.dart';
import 'progress.dart';
import 'coach.dart' show welcomeBack;
import 'meal_ai.dart';
import 'meal_sheet.dart' show showMealSheet;
import 'reminders.dart';
import 'reminders_screen.dart';
import 'steps.dart';
import 'splash.dart';
import 'spending.dart';
import 'store.dart';
import 'streak.dart' show RecapScreen;
import 'targets.dart';
import 'theme.dart';
import 'today.dart';
import 'visuals.dart';
import 'water_walk.dart';
import 'widget_sync.dart';
import 'your_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_bars);
  // Firebase talks to native code, so it starts after ensureInitialized and before runApp.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MealAi.activateAppCheck(); // guards the AI meal estimate (Firebase AI Logic)
  final store = await Store.load();
  runApp(DaurApp(store: store));
  WidgetSync.attach(store); // home-screen widget follows every change
  scheduleBackgroundRefresh(); // steps + widgets every ~30 min, app closed (Android)
  Reminders.bind(store);
  Reminders.attach(store); // local reminders reschedule on every change
  Live.watchFast(store); // the running fast, live on the lock screen and status bar
  Cloud.instance.attach(store); // Google sign-in + Firestore backup, when signed in
}

/// Light status-bar and nav-bar icons over the red track (set at start and on every frame below,
/// because iOS otherwise falls back to dark icons).
const _bars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark, // iOS
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

class DaurApp extends StatelessWidget {
  const DaurApp({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Daur',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    builder: (_, child) => AnnotatedRegion(
      value: _bars,
      child: SplashIntro(child: child!),
    ),
    home: ListenableBuilder(
      listenable: store,
      builder: (_, _) => store.onboarded ? Shell(store: store) : OnboardingScreen(store: store),
    ),
  );
}

/// Core on the navbar (Today · Gym · Progress); everything else in the drawer.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});
  final Store store;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  late int _meals = widget.store.legsDone; // to notice the lap closing
  StreamSubscription<Uri?>? _links;
  bool _drawerOpen = false;
  final _scaffold = GlobalKey<ScaffoldState>();
  int? _steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    menuOpener = openMenu;
    _refreshSteps();
    _startStepsTimer();
    // iOS widget buttons open the app with daur://water or daur://meal (Android runs them in the background)
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_widgetLink);
    _links = HomeWidget.widgetClicked.listen(_widgetLink);
    // notification taps that need a screen (Something else, Log weight, Water…)
    Reminders.route.addListener(_notificationRoute);
    widget.store.addListener(_watchLap);
    Reminders.handleLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWelcomeBack());
  }

  /// 2+ days away → a calm "welcome back, today is lap N" with a weigh-in.
  void _checkWelcomeBack() {
    final days = widget.store.markOpened();
    if (days >= 2 && mounted && widget.store.onboarded) welcomeBack(context, widget.store, days);
  }

  /// The 4th meal closes the lap: once the track's light-up has played, mint any medals earned
  /// (7 or 21 full laps in a row, the whole cut).
  late bool _perfect = widget.store.perfect(widget.store.today);
  void _watchLap() {
    final now = widget.store.legsDone;
    final perfect = widget.store.perfect(widget.store.today);
    // a day turning perfect (often the last glass or the steps) can mint a medal too
    if (perfect && !_perfect) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) checkBadges(context, widget.store);
      });
    }
    _perfect = perfect;
    if (now == 4 && _meals < 4) {
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) checkBadges(context, widget.store);
      });
    }
    _meals = now;
  }

  void _notificationRoute() {
    final r = Reminders.route.value;
    if (r == null || !mounted) return;
    Reminders.route.value = null;
    final s = widget.store;
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (r.startsWith('meal:')) {
      final m = meals.where((m) => m.id == r.substring(5)).firstOrNull;
      setState(() => _tab = 0);
      if (m != null) showMealSheet(context, s, meal: m, n: (meals.indexOf(m) + 1) * 100);
    } else if (r == 'weigh') {
      setState(() => _tab = 2);
      ProgressScreen.logWeight(context, s);
    } else if (r == 'water') {
      push(WaterScreen(store: s));
    } else if (r == 'walk') {
      push(WalkScreen(store: s, steps: _steps, onRefresh: _refreshSteps));
    } else if (r == 'fasting') {
      push(FastingScreen(store: s));
    } else if (r == 'recap') {
      push(RecapScreen(store: s));
    } else {
      setState(() => _tab = 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // a widget button may have changed data meanwhile; reload also rolls over to a new day
      widget.store.reload().then((_) => _checkWelcomeBack());
      _refreshSteps();
      _startStepsTimer();
    } else if (state == AppLifecycleState.paused) {
      _stepsTimer?.cancel();
    }
  }

  /// While Daur is open, steps tick up on their own every 2 minutes.
  Timer? _stepsTimer;
  void _startStepsTimer() {
    _stepsTimer?.cancel();
    _stepsTimer = Timer.periodic(const Duration(minutes: 2), (_) => _refreshSteps());
  }

  Future<void> _refreshSteps() async {
    final v = await Steps.today();
    WidgetSync.steps = v;
    if (v != null) widget.store.noteSteps(v); // kept per day: perfect days, the weekly recap
    WidgetSync.schedule(widget.store);
    Reminders.schedule(widget.store); // the evening-walk reminder depends on steps
    // iOS hides read access: 0 steps by 15:00 usually means Health sharing is off
    if (defaultTargetPlatform == TargetPlatform.iOS && v == 0 && DateTime.now().hour >= 15) {
      widget.store.showHintNow('steps-ios');
    }
    if (mounted) setState(() => _steps = v);
    // steps work: ask once to read them in the background too, for the 30-minute widget refresh
    if (v != null && !widget.store.seenHints.contains('bg-steps')) {
      widget.store.dismissHint('bg-steps');
      await Steps.allowBackground();
    }
    final sleep = await Steps.sleepLastNight(); // never asks; the Sleep row's Connect does
    if (sleep != null) widget.store.setSleep(sleep);
  }

  void _widgetLink(Uri? uri) {
    final s = widget.store;
    if (uri == null || !mounted) return;
    final snap = s.snapshot();
    switch (uri.host) {
      case 'water':
        s.setWater(s.water + 1);
        undoToast(context, 'Glass ${s.water} logged', () => s.restore(snap));
      case 'meal':
        final m = s.nextMeal;
        if (m == null) return;
        s.logMeal(m);
        undoToast(context, '${m.name} logged: ${s.chosen(m).name}', () => s.restore(snap));
    }
    setState(() => _tab = 0);
  }

  @override
  void dispose() {
    _stepsTimer?.cancel();
    _links?.cancel();
    Reminders.route.removeListener(_notificationRoute);
    widget.store.removeListener(_watchLap);
    menuOpener = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// What isn't on the bottom bar or Today, in groups. Android shows it as the drawer; iPhone,
  /// which has no drawers, as a More page opened from the profile button.
  List<List<(IconData, String, Widget Function())>> get _pages {
    final s = widget.store;
    return [
      [
        (Icons.restaurant_outlined, 'Food guide', () => FoodScreen(store: s)),
        (Icons.menu_book_outlined, 'Food database', () => FoodDbScreen(store: s)),
      ],
      [
        (Icons.flag_outlined, 'Your targets', () => TargetsScreen(store: s)),
        (Icons.hourglass_bottom_rounded, 'Fasting', () => FastingScreen(store: s)),
        (Icons.account_balance_wallet_outlined, 'Spending', () => SpendingScreen(store: s)),
        (Icons.groups_outlined, 'Family', () => FamilyScreen(store: s)),
        (Icons.shield_outlined, 'Your data', () => DataScreen(store: s)),
        (Icons.notifications_outlined, 'Reminders', () => RemindersScreen(store: s)),
      ],
    ];
  }

  /// The drawer on Android, the More page on iPhone (called from [MenuButton]).
  void openMenu() {
    if (!isIOS(context)) {
      _scaffold.currentState?.openDrawer();
      return;
    }
    if (widget.store.drawerDot) widget.store.dismissHint('drawer');
    Navigator.push(context, CupertinoPageRoute(builder: (_) => _MorePage(shell: this)));
  }

  Future<void> _addWidget(BuildContext context) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Hold the home screen → Edit → Add Widget → Daur'),
        ),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (cls, name, sub) in WidgetSync.catalog)
              ListTile(
                leading: const Icon(Icons.add_to_home_screen),
                title: Text(name),
                subtitle: Text(sub),
                onTap: () async {
                  Navigator.pop(ctx);
                  await WidgetSync.pin(cls);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final s = widget.store;
    final d = await pickDate(
      context,
      initial: DateTime.parse(s.startDay),
      first: DateTime.now().subtract(const Duration(days: laps * 2)),
      last: DateTime.now(),
      help: 'Day 1 of the 12-week plan',
    );
    if (d != null) s.setStartDay(d);
  }

  Widget _drawer(BuildContext context) {
    final t = Daur.of(context), s = widget.store;
    final pages = _pages.expand((g) => g).toList();
    return NavigationDrawer(
      backgroundColor: t.sheet,
      selectedIndex: null, // Today, Gym and Progress live on the bottom bar only
      onDestinationSelected: (i) {
        Navigator.pop(context); // close the drawer
        Navigator.push(context, MaterialPageRoute(builder: (_) => pages[i].$3()));
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daur', style: t.x(28, color: t.sheetRed)),
              const SizedBox(height: 4),
              Text('Day ${s.lap} of $laps · week ${s.cutWeek}', style: t.sec(t.sheetInk2)),
            ],
          ),
        ),
        const _AccountTile(),
        for (final (i, group) in _pages.indexed) ...[
          if (i > 0) const Divider(indent: 28, endIndent: 28),
          for (final (icon, label, _) in group) NavigationDrawerDestination(icon: Icon(icon), label: Text(label)),
        ],
        const Divider(indent: 28, endIndent: 28),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.widgets_outlined),
          title: const Text('Add home-screen widget'),
          subtitle: const Text('Meals, kcal, water, steps'),
          onTap: () {
            Navigator.pop(context);
            _addWidget(context);
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Plan start date'),
          subtitle: Text('${niceDate(DateTime.parse(s.startDay))} · today is day ${s.lap}'),
          onTap: () => _pickStart(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    // Back: close the drawer first, then return to Today, and only then leave the app.
    builder: (context, _) => PopScope(
      canPop: _tab == 0 && !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _drawerOpen ? _scaffold.currentState?.closeDrawer() : setState(() => _tab = 0);
      },
      child: Scaffold(
        key: _scaffold,
        onDrawerChanged: (open) {
          setState(() => _drawerOpen = open);
          if (open && widget.store.drawerDot) widget.store.dismissHint('drawer');
        },
        drawer: isIOS(context) ? null : _drawer(context),
        body: IndexedStack(
          index: _tab,
          children: [
            TodayScreen(store: widget.store, steps: _steps, onRefreshSteps: _refreshSteps),
            GymScreen(store: widget.store),
            ProgressScreen(store: widget.store),
          ],
        ),
        extendBody: isIOS(context), // pages run under the floating glass tab bar
        bottomNavigationBar: Tabs(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            (Icons.track_changes_outlined, Icons.track_changes, 'Today'),
            (Icons.fitness_center_outlined, Icons.fitness_center, 'Gym'),
            (Icons.show_chart_outlined, Icons.show_chart, 'Progress'),
          ],
        ),
      ),
    ),
  );
}

/// iPhone's More page: the drawer's contents as grouped rows in Daur's colours, chevrons on the right.
class _MorePage extends StatelessWidget {
  const _MorePage({required this.shell});
  final _ShellState shell;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context), s = shell.widget.store;
    Widget group(List<(IconData, String, String?, VoidCallback)> rows) => Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: t.infield, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (final (i, (icon, label, sub, onTap)) in rows.indexed)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: i == 0 ? null : Border(top: BorderSide(color: t.rule, width: .5)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: t.ink),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: t.body(weight: FontWeight.w500)),
                          if (sub != null) Text(sub, style: t.meta()),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_forward, size: 16, color: t.ink2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    void open(Widget Function() page) => Navigator.push(context, CupertinoPageRoute(builder: (_) => page()));
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              PageHeader('More', sub: 'Day ${s.lap} of $laps · week ${s.cutWeek}'),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: t.sheet, borderRadius: BorderRadius.circular(14)),
                child: const _AccountTile(),
              ),
              for (final g in shell._pages)
                group([for (final (icon, label, page) in g) (icon, label, null, () => open(page))]),
              group([
                (
                  Icons.widgets_outlined,
                  'Add home-screen widget',
                  'Meals, kcal, water, steps',
                  () => shell._addWidget(context),
                ),
                (
                  Icons.flag_outlined,
                  'Plan start date',
                  '${niceDate(DateTime.parse(s.startDay))} · today is day ${s.lap}',
                  () => shell._pickStart(context),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawer: Google account and backup status. Signed out it's a "Continue with Google" button.
class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return ListenableBuilder(
      listenable: Cloud.instance,
      builder: (context, _) {
        final c = Cloud.instance, u = c.user;
        if (u == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoogleButton(
                  busy: c.busy,
                  onPressed: () async {
                    final msg = await c.signInWithGoogle();
                    if (msg != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 16, color: t.sheetInk2),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c.error ?? 'Back up and sync your data', style: t.meta(t.sheetInk2))),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final synced = c.lastSync != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Material(
            color: t.sheetRule.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  u.photoURL != null
                      ? CircleAvatar(backgroundImage: NetworkImage(u.photoURL!))
                      : CircleAvatar(
                          backgroundColor: t.sheet,
                          child: Icon(Icons.person_outline, color: t.sheetInk),
                        ),
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: CircleAvatar(radius: 10, backgroundColor: Colors.white, child: GoogleG(size: 13)),
                  ),
                ],
              ),
              title: Text(u.displayName ?? u.email ?? 'Signed in', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Row(
                children: [
                  Icon(
                    c.error != null
                        ? Icons.cloud_off_outlined
                        : synced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                    size: 16,
                    color: c.error != null ? t.sheetRed : t.sheetInk2,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.error ?? (synced ? TimeOfDay.fromDateTime(c.lastSync!).format(context) : 'Syncing…'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.error != null ? t.sheetRed : null),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () => _signOut(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmPop(
      context,
      'Sign out?',
      'Your data stays here and in the cloud.',
      'Sign out',
      destructive: true,
    );
    if (ok) await Cloud.instance.signOut();
  }
}
