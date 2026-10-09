import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_search.dart';
import 'foods.dart';
import 'plan.dart';

/// Local calendar day as yyyy-mm-dd. Local, not UTC: the old HTML app used
/// toISOString(), so in Dhaka (UTC+6) the day flipped at 06:00.
String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _date(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]); // UTC so day maths ignores DST
}

class SetLog {
  final int reps; // seconds for timed holds
  final double kg;
  const SetLog(this.reps, this.kg);
  List<num> toJson() => [reps, kg];
  static SetLog from(List<dynamic> j) => SetLog((j[0] as num).toInt(), (j[1] as num).toDouble());
}

/// Something eaten that isn't a planned option: a food from the list or a custom one, times qty.
class Eaten {
  final String name;
  final int kcal, protein; // per portion
  final bool rare;
  final double qty;
  final String portion, cat; // serving text and category (custom foods); '' = unknown
  const Eaten(this.name, this.kcal, this.protein, {this.rare = false, this.qty = 1, this.portion = '', this.cat = ''});
  Eaten withQty(double q) => Eaten(name, kcal, protein, rare: rare, qty: q, portion: portion, cat: cat);
  int get totalKcal => (kcal * qty).round();
  int get totalProtein => (protein * qty).round();
  Map<String, Object> toJson() => {
    'n': name,
    'k': kcal,
    'p': protein,
    'r': rare,
    'q': qty,
    if (portion.isNotEmpty) 'po': portion,
    if (cat.isNotEmpty) 'c': cat,
  };
  static Eaten from(Map j) => Eaten(
    j['n'] as String,
    (j['k'] as num).toInt(),
    (j['p'] as num).toInt(),
    rare: j['r'] as bool? ?? false,
    qty: (j['q'] as num?)?.toDouble() ?? 1,
    portion: j['po'] as String? ?? '',
    cat: j['c'] as String? ?? '',
  );
  static Eaten of(Food f) => Eaten(f.name, f.kcal, f.protein, rare: f.rare, portion: f.portion, cat: f.cat);
}

class Cardio {
  final int seconds;
  final double km, kcal, speed, incline;
  const Cardio(this.seconds, this.km, this.kcal, this.speed, this.incline);
  Map<String, num> toJson() => {'s': seconds, 'km': km, 'kcal': kcal, 'v': speed, 'i': incline};
  static Cardio from(Map<String, dynamic> j) => Cardio(
    (j['s'] as num).toInt(),
    (j['km'] as num).toDouble(),
    (j['kcal'] as num).toDouble(),
    (j['v'] as num).toDouble(),
    (j['i'] as num).toDouble(),
  );
}

/// Money spent on the diet and fitness, in taka.
class Expense {
  final String day, cat, note;
  final int taka;
  const Expense(this.day, this.taka, this.cat, [this.note = '']);
  Map<String, Object> toJson() => {'d': day, 't': taka, 'c': cat, if (note.isNotEmpty) 'n': note};
  static Expense from(Map j) =>
      Expense(j['d'] as String, (j['t'] as num).toInt(), j['c'] as String? ?? 'other', j['n'] as String? ?? '');
}

class Weigh {
  final String day;
  final double kg;
  const Weigh(this.day, this.kg);
}

/// All app state, saved as one JSON blob, backed up per Google account by cloud.dart.
class Store extends ChangeNotifier {
  Store._(this._p);
  final SharedPreferences _p;
  static const _key = 'daur';

  late String startDay, today;
  int savedAt = 0; // ms since epoch of the last change; the newer copy wins when syncing
  bool onboarded = false;
  // onboarding after onboarding: hints, check-ins and the end of the cut
  Set<String> seenHints = {}; // each contextual hint shows once
  String? hintDay, hintToday; // at most one coach card a day
  String? lastOpenDay; // for "welcome back" after 2+ days away
  bool remindersOn = false, healthAsked = false;
  Map<String, bool> reminderTypes = {}; // meals, water, weigh, walk, checkins (missing = on)
  String? pausedDay; // "pause for today"
  int cutRound = 1; // 2 after "another 12 weeks"
  String? maintenanceUntil; // 2 weeks at maintenance after the cut
  String? finishChoice; // 'again' | 'maintenance' | 'keep'
  double startKg = startWeightKg; // weight on day 1
  Map<String, String> done = {}; // meal id -> "HH:mm" eaten today
  Map<String, int> option = {}; // meal id -> chosen option (kept across days)
  int water = 0; // glasses today
  int? manualSteps; // used when no health store is available (web)
  Set<String> gymTicks = {};
  List<String> exercises = [...gymDefaults];
  List<Weigh> weights = [];
  Map<String, int> lapHistory = {}; // day -> meals eaten (0..4), drawn on Progress
  Map<String, ExPlan> plans = {}; // exercise -> current plan (missing = default)
  Map<String, Map<String, List<SetLog>>> setLog = {}; // exercise -> day -> sets
  Map<String, List<String>> routine = {}; // 'Push' / 'Pull' / 'Legs' → that day's exercises
  Map<String, String> routineLog = {}; // date → the split day trained (for what comes next)
  String? routinePickDate, routinePick; // a day chosen by hand for today
  Map<String, (String, SetLog)> strengthFirst = {}; // exercise -> (day, best set) of the first session
  List<Cardio> cardio = []; // today's treadmill sessions
  double treadSpeed = 5.8, treadIncline = 6;
  Map<String, double> portion = {}; // meal id -> ½, 1, 1½, 2 of the planned option (today)
  Map<String, List<Eaten>> other = {}; // meal id -> what was eaten instead of the plan (today)
  Set<String> skipped = {}; // meals skipped today
  List<Eaten> extras = []; // eaten between meals today
  List<Eaten> customFoods = []; // foods typed in by hand, offered again next time
  List<String> recentFoods = []; // names, most recent first (max 12)
  Map<String, int> waterHistory = {}; // day -> glasses
  Map<String, int> stepsHistory = {}; // day -> steps typed in by hand (web / no health store)
  Map<String, int> junkHistory = {}; // day -> junk meals (meals or extras with a keep-rare food)
  Map<String, int> kcalHistory = {}, proteinHistory = {}; // day -> eaten
  Map<String, int> gymHistory = {}; // day -> sets, ticks and cardio logged (0 = no session)
  Map<String, int> sleepHistory = {}; // day -> minutes slept the night before
  Profile? profile; // body details for a personal plan; null = the original plan in plan.dart
  String? ownerUid; // the Google account this data belongs to (set on first sync)
  bool signedIn = false; // not saved: cloud.dart keeps it current
  String? fastPlan; // '14:10' | '16:8' | '18:6' (hours fasting : eating); null = not fasting
  int eatStart = 13; // the eating window opens at this hour
  DateTime? fastFrom; // the fast running now, started by hand; null = none
  List<(DateTime, DateTime)> fasts = []; // finished fasts (start, end), oldest first, last 60
  List<Expense> expenses = [];
  int? monthBudget; // taka
  int freezes = 0; // streak freezes in hand (max 2), one earned per 7 full days in a row
  String? freezeEarnedOn; // the day the last one was earned (once per day)
  Set<String> frozenDays = {}; // missed days a freeze covered: the streak passes over them
  String? familyId; // the family board this person is on (cloud.dart)
  // coaching (cloud.dart): helpers (a mother for the diet, a trainer) follow this plan
  Map<String, String> inviteCodes = {}; // role ('diet' | 'trainer') -> the code this person made
  List<Map<String, String>> helping = []; // people this person helps: {owner, name, role}
  bool helperOnly = false; // this phone only helps someone; it has no plan of its own
  String? role; // how this person uses Daur: 'me' | 'trainer' | 'family'; null = not asked yet
  String notesSeen = ''; // ISO time of the newest note already shown on Today
  List<Meal>? chart; // the trainer's diet chart (null = the plan in plan.dart)
  String chartBy = ''; // who wrote it (shown with the chart)
  List<String> chartChanges = []; // what the last chart changed, in words ("Lunch: Beef + rice added")
  String chartAt = '', cookAt = ''; // ISO times of the last chart / cooking picks applied from the cloud
  String? aiDay; // the Pacific-time day aiUsed counts (Google's free quota resets then)
  Map<String, int> aiUsed = {}; // 'flash' / 'lite' → AI estimates made on this phone that day
  Map<String, List<Eaten>> aiMeals = {}; // normalised description → the estimate (reused, no AI)
  List<Eaten> aiFoods = []; // every food an estimate produced, searchable like the food list

  static Future<Store> load() async {
    final s = Store._(await SharedPreferences.getInstance());
    final raw = s._p.getString(_key);
    s._read(raw == null ? const {} : jsonDecode(raw) as Map<String, dynamic>);
    s.rollover();
    return s;
  }

  void _read(Map<String, dynamic> j) {
    final now = dayKey(DateTime.now());
    startDay = j['startDay'] as String? ?? now;
    savedAt = (j['savedAt'] as num?)?.toInt() ?? 0;
    onboarded = j['onboarded'] as bool? ?? false;
    seenHints = Set<String>.from(j['seenHints'] ?? []);
    hintDay = j['hintDay'] as String?;
    hintToday = j['hintToday'] as String?;
    lastOpenDay = j['lastOpenDay'] as String?;
    remindersOn = j['remindersOn'] as bool? ?? false;
    reminderTypes = Map<String, bool>.from(j['reminderTypes'] ?? {});
    pausedDay = j['pausedDay'] as String?;
    healthAsked = j['healthAsked'] as bool? ?? false;
    cutRound = j['cutRound'] as int? ?? 1;
    maintenanceUntil = j['maintenanceUntil'] as String?;
    finishChoice = j['finishChoice'] as String?;
    startKg = (j['startKg'] as num?)?.toDouble() ?? startWeightKg;
    today = j['today'] as String? ?? now;
    done = Map<String, String>.from(j['done'] ?? {});
    option = Map<String, int>.from(j['option'] ?? {});
    water = j['water'] as int? ?? 0;
    manualSteps = j['manualSteps'] as int?;
    gymTicks = Set<String>.from(j['gymTicks'] ?? []);
    exercises = List<String>.from(j['exercises'] ?? gymDefaults);
    weights = [for (final w in (j['weights'] as List? ?? [])) Weigh(w['d'] as String, (w['v'] as num).toDouble())];
    lapHistory = Map<String, int>.from(j['lapHistory'] ?? {});
    plans = {
      for (final e in (j['plans'] as Map? ?? {}).entries)
        e.key as String: ExPlan(
          e.value[0] as int,
          e.value[1] as int,
          (e.value[2] as num).toDouble(),
          timed: e.value[3] as bool,
        ),
    };
    setLog = {
      for (final e in (j['setLog'] as Map? ?? {}).entries)
        e.key as String: {
          for (final d in (e.value as Map).entries)
            d.key as String: [for (final x in d.value as List) SetLog.from(x as List)],
        },
    };
    cardio = [for (final c in (j['cardio'] as List? ?? [])) Cardio.from(Map<String, dynamic>.from(c as Map))];
    routine = {
      for (final e in (j['routine'] as Map? ?? {}).entries) e.key as String: List<String>.from(e.value as List),
    };
    if (routine.isEmpty) _splitFromExercises(); // older data: sort the one list into push / pull / legs
    routineLog = Map<String, String>.from(j['routineLog'] ?? {});
    routinePickDate = j['routinePickDate'] as String?;
    routinePick = j['routinePick'] as String?;
    strengthFirst = {
      for (final e in (j['strengthFirst'] as Map? ?? {}).entries)
        e.key as String: ((e.value as Map)['d'] as String, SetLog.from((e.value as Map)['s'] as List)),
    };
    treadSpeed = (j['treadSpeed'] as num?)?.toDouble() ?? 5.8;
    treadIncline = (j['treadIncline'] as num?)?.toDouble() ?? 6;
    List<Eaten> eaten(Object? l) => [for (final x in (l as List? ?? [])) Eaten.from(x as Map)];
    portion = {for (final e in (j['portion'] as Map? ?? {}).entries) e.key as String: (e.value as num).toDouble()};
    other = {for (final e in (j['other'] as Map? ?? {}).entries) e.key as String: eaten(e.value)};
    skipped = Set<String>.from(j['skipped'] ?? []);
    extras = eaten(j['extras']);
    customFoods = eaten(j['customFoods']);
    recentFoods = List<String>.from(j['recentFoods'] ?? []);
    waterHistory = Map<String, int>.from(j['waterHistory'] ?? {});
    stepsHistory = Map<String, int>.from(j['stepsHistory'] ?? {});
    junkHistory = Map<String, int>.from(j['junkHistory'] ?? {});
    kcalHistory = Map<String, int>.from(j['kcalHistory'] ?? {});
    proteinHistory = Map<String, int>.from(j['proteinHistory'] ?? {});
    gymHistory = Map<String, int>.from(j['gymHistory'] ?? {});
    sleepHistory = Map<String, int>.from(j['sleepHistory'] ?? {});
    profile = j['profile'] == null ? null : Profile.from(j['profile'] as Map);
    ownerUid = j['ownerUid'] as String?;
    fastPlan = j['fastPlan'] as String?;
    eatStart = j['eatStart'] as int? ?? 13;
    fastFrom = DateTime.tryParse(j['fastFrom'] as String? ?? '');
    fasts = [
      for (final f in (j['fasts'] as List? ?? const []))
        (DateTime.parse((f as List)[0] as String), DateTime.parse(f[1] as String)),
    ];
    expenses = [for (final x in (j['expenses'] as List? ?? [])) Expense.from(x as Map)];
    monthBudget = j['monthBudget'] as int?;
    freezes = j['freezes'] as int? ?? 0;
    freezeEarnedOn = j['freezeEarnedOn'] as String?;
    frozenDays = Set<String>.from(j['frozenDays'] ?? []);
    familyId = j['familyId'] as String?;
    inviteCodes = Map<String, String>.from(j['inviteCodes'] ?? {});
    helping = [for (final h in (j['helping'] as List? ?? const [])) Map<String, String>.from(h as Map)];
    helperOnly = j['helperOnly'] as bool? ?? false;
    role = j['role'] as String?;
    notesSeen = j['notesSeen'] as String? ?? '';
    chart = j['chart'] == null ? null : [for (final m in j['chart'] as List) Meal.from(m as Map)];
    chartBy = j['chartBy'] as String? ?? '';
    chartChanges = [for (final x in (j['chartChanges'] as List? ?? const [])) x as String];
    chartAt = j['chartAt'] as String? ?? '';
    cookAt = j['cookAt'] as String? ?? '';
    useChart(chart);
    aiDay = j['aiDay'] as String?;
    aiUsed = Map<String, int>.from(j['aiUsed'] ?? {});
    // re-filed under today's key rules, so estimates saved by an older version still match
    aiMeals = {for (final e in (j['aiMeals'] as Map? ?? {}).entries) canonicalKey(e.key as String): eaten(e.value)};
    aiFoods = eaten(j['aiFoods']);
    // meals logged before defaults changed keep the option they were logged with
    for (final m in meals) {
      if (done.containsKey(m.id)) option.putIfAbsent(m.id, () => 0);
    }
  }

  Map<String, Object?> _toJson() => {
    'startDay': startDay,
    'savedAt': savedAt,
    'onboarded': onboarded,
    'seenHints': seenHints.toList(),
    'hintDay': hintDay,
    'hintToday': hintToday,
    'lastOpenDay': lastOpenDay,
    'remindersOn': remindersOn,
    'reminderTypes': reminderTypes,
    'pausedDay': pausedDay,
    'healthAsked': healthAsked,
    'cutRound': cutRound,
    'maintenanceUntil': maintenanceUntil,
    'finishChoice': finishChoice,
    'startKg': startKg,
    'today': today,
    'done': done,
    'option': option,
    'water': water,
    'manualSteps': manualSteps,
    'gymTicks': gymTicks.toList(),
    'exercises': exercises,
    'weights': [
      for (final w in weights) {'d': w.day, 'v': w.kg},
    ],
    'lapHistory': lapHistory,
    'plans': {
      for (final e in plans.entries) e.key: [e.value.sets, e.value.reps, e.value.kg, e.value.timed],
    },
    'setLog': {
      for (final e in setLog.entries)
        e.key: {
          for (final d in e.value.entries) d.key: [for (final x in d.value) x.toJson()],
        },
    },
    'cardio': [for (final c in cardio) c.toJson()],
    'routine': routine,
    'routineLog': routineLog,
    'routinePickDate': routinePickDate,
    'routinePick': routinePick,
    'strengthFirst': {
      for (final e in strengthFirst.entries) e.key: {'d': e.value.$1, 's': e.value.$2.toJson()},
    },
    'treadSpeed': treadSpeed,
    'treadIncline': treadIncline,
    'portion': portion,
    'skipped': skipped.toList(),
    'other': {
      for (final e in other.entries) e.key: [for (final x in e.value) x.toJson()],
    },
    'extras': [for (final x in extras) x.toJson()],
    'customFoods': [for (final x in customFoods) x.toJson()],
    'recentFoods': recentFoods,
    'waterHistory': waterHistory,
    'stepsHistory': stepsHistory,
    'junkHistory': junkHistory,
    'kcalHistory': kcalHistory,
    'proteinHistory': proteinHistory,
    'gymHistory': gymHistory,
    'sleepHistory': sleepHistory,
    'profile': profile?.toJson(),
    'ownerUid': ownerUid,
    'fastPlan': fastPlan,
    'eatStart': eatStart,
    'fastFrom': fastFrom?.toIso8601String(),
    'fasts': [
      for (final (a, b) in fasts) [a.toIso8601String(), b.toIso8601String()],
    ],
    'expenses': [for (final x in expenses) x.toJson()],
    'monthBudget': monthBudget,
    'freezes': freezes,
    'freezeEarnedOn': freezeEarnedOn,
    'frozenDays': frozenDays.toList(),
    'familyId': familyId,
    'inviteCodes': inviteCodes,
    'helping': helping,
    'helperOnly': helperOnly,
    'role': role,
    'notesSeen': notesSeen,
    if (chart != null) 'chart': [for (final m in chart!) m.toJson()],
    'chartBy': chartBy,
    'chartChanges': chartChanges,
    'chartAt': chartAt,
    'cookAt': cookAt,
    'aiDay': aiDay,
    'aiUsed': aiUsed,
    'aiMeals': {
      for (final e in aiMeals.entries) e.key: [for (final x in e.value) x.toJson()],
    },
    'aiFoods': [for (final x in aiFoods) x.toJson()],
  };

  Future<void> _write = Future.value();

  /// Completes when the last change is on disk (background widget taps await this before exiting).
  Future<void> get saved => _write;

  /// Re-read from disk: a widget button may have changed data while the app was in the background.
  Future<void> reload() async {
    await _p.reload();
    final raw = _p.getString(_key);
    if (raw != null) _read(jsonDecode(raw) as Map<String, dynamic>);
    rollover();
    notifyListeners();
  }

  void _save() {
    // today's line in every history, always in sync with today
    void put(Map<String, int> h, int v) => v == 0 ? h.remove(today) : h[today] = v;
    put(junkHistory, rareToday);
    put(lapHistory, legsDone);
    put(kcalHistory, kcal);
    put(proteinHistory, protein);
    put(gymHistory, setsDoneToday + gymTicks.length + cardio.length);
    if (legsDone == 4 && streak % 7 == 0 && freezeEarnedOn != today && freezes < 2) {
      freezes++;
      freezeEarnedOn = today;
    }
    savedAt = DateTime.now().millisecondsSinceEpoch;
    _write = _p.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  /// Whole-state snapshot for undo: take one before a change, restore it to undo exactly.
  String snapshot() => jsonEncode(_toJson());

  /// Replace everything with a copy from the cloud, keeping its own savedAt (no echo back as "newer").
  void adoptCloud(String json) {
    _read(jsonDecode(json) as Map<String, dynamic>);
    rollover();
    _write = _p.setString(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  void restore(String snap) {
    _read(jsonDecode(snap) as Map<String, dynamic>);
    _save();
  }

  /// New local day: clear today's ticks. Called on launch and whenever the app resumes,
  /// so a phone left open overnight still resets.
  void rollover() {
    final now = dayKey(DateTime.now());
    if (now == today) return;
    today = now;
    done = {};
    water = 0;
    manualSteps = null;
    gymTicks = {};
    cardio = [];
    portion = {};
    other = {};
    skipped = {};
    extras = [];
    _useFreezes();
    _save();
  }

  bool _full(String d) => (lapHistory[d] ?? 0) >= 4;

  /// New day: if the days just missed sit right after a streak and there are enough freezes to
  /// cover them all, they're frozen and the streak carries on. Otherwise the streak ends honestly.
  void _useFreezes() {
    if (freezes == 0) return;
    final t = _date(today);
    final gap = <String>[];
    for (var i = 1; i <= 7; i++) {
      final d = dayKey(t.subtract(Duration(days: i)));
      if (d.compareTo(startDay) < 0) return;
      if (_full(d) || frozenDays.contains(d)) {
        if (gap.isNotEmpty && gap.length <= freezes) {
          frozenDays.addAll(gap);
          freezes -= gap.length;
        }
        return;
      }
      gap.add(d);
    }
  }

  /// Move day 1 of the cut (e.g. if the plan started before the app). Past laps keep their history.
  void setStartDay(DateTime d) {
    startDay = dayKey(d);
    _save();
  }

  /// Day of the cut, 1-based ("Lap 23 of 84").
  int get lap => _date(today).difference(_date(startDay)).inDays + 1;

  MealOption chosen(Meal m) => m.options[(option[m.id] ?? defaultOption[m.id] ?? 0).clamp(0, m.options.length - 1)];
  int get mealsDone => meals.where((m) => done.containsKey(m.id)).length;

  /// Legs of today's lap run: meals logged or deliberately skipped. Honest logging is the habit.
  int get legsDone => meals.where((m) => done.containsKey(m.id) || skipped.contains(m.id) || fasted(m)).length;

  // ---- targets: the original plan, or computed from [profile] ----

  /// Weight the targets follow: the 7-day trend once there is one, else day 1.
  double get planKg => trendKg ?? startKg;
  int get baseKcal => profile?.kcal(planKg) ?? kcalTarget;
  (int, int) get proteinRange => profile?.protein(planKg) ?? (130, 150);
  String get proteinText => '${proteinRange.$1}–${proteinRange.$2}';
  int get waterGoal => profile?.glasses(startKg) ?? waterGlasses;
  List<(String, String, int)> get targets => profile?.targets(startKg) ?? milestones;

  /// Planned portions scale with the calorie target (the menu is written for 1,800).
  double get planScale => baseKcal / kcalTarget;

  /// Portion scale for one meal: the target's scale, and when fasting, the meals inside the
  /// window grow to carry the day (a skipped breakfast's calories and protein move to lunch on).
  double mealScale(Meal m) => planScale * (fasted(m) ? 1 : fastBoost);
  int optKcal(Meal m, MealOption o) => (o.kcal * mealScale(m)).round();
  int optProtein(Meal m, MealOption o) => (o.protein * mealScale(m)).round();

  // ---- intermittent fasting ----

  int get fastHours => fastPlan == null ? 0 : int.parse(fastPlan!.split(':').first);
  int get eatEnd => eatStart + 24 - fastHours; // exclusive hour; ≤ 24

  /// Outside today's eating window (by the hour the meal's window opens).
  bool fasted(Meal m) {
    if (fastPlan == null) return false;
    final h = int.parse(m.window.substring(0, 2));
    return h < eatStart || h >= eatEnd;
  }

  /// How much bigger the in-window meals get so the planned day stays the same size.
  double get fastBoost {
    if (fastPlan == null) return 1;
    final all = meals.fold(0, (a, m) => a + chosen(m).kcal);
    final inside = meals.where((m) => !fasted(m)).fold(0, (a, m) => a + chosen(m).kcal);
    return inside == 0 ? 1 : all / inside;
  }

  /// The usual window for a plan: it closes at 21:00, after dinner.
  static int defaultStart(String plan) => 21 - (24 - int.parse(plan.split(':').first));

  void setFast(String? plan, {int? start}) {
    fastPlan = plan;
    if (plan != null) eatStart = (start ?? defaultStart(plan)).clamp(5, 24 - (24 - int.parse(plan.split(':').first)));
    _save();
  }

  /// The fast's goal in hours: the plan's, or 16 if the plan was turned off mid-fast.
  int get fastGoal => fastPlan == null ? 16 : fastHours;

  void startFast([DateTime? at]) {
    fastFrom = at ?? DateTime.now();
    _save();
  }

  /// Ends the running fast and keeps it (if it lasted at least 30 minutes). Returns its length.
  Duration? endFast([DateTime? at]) {
    final from = fastFrom;
    if (from == null) return null;
    final to = at ?? DateTime.now();
    if (to.difference(from).inMinutes >= 30) {
      fasts = [...fasts, (from, to)];
      if (fasts.length > 60) fasts = fasts.sublist(fasts.length - 60);
    }
    fastFrom = null;
    _save();
    return to.difference(from);
  }

  /// The longest fast that ended on [day], in minutes (0 = none).
  int fastMinOn(String day) => fasts
      .where((f) => dayKey(f.$2) == day)
      .fold(0, (a, f) => f.$2.difference(f.$1).inMinutes > a ? f.$2.difference(f.$1).inMinutes : a);

  /// Days in a row with a fast that reached the goal; today counts once it's done, else from yesterday.
  int get fastStreak {
    var d = DateTime.now();
    if (fastMinOn(dayKey(d)) < fastGoal * 60) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (fastMinOn(dayKey(d)) >= fastGoal * 60) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---- calorie balance: eaten against burned ----

  /// What the body burns in a day before exercise: maintenance for this weight and the day job
  /// (the plan's target is this minus the deficit). Without a profile, the plan's 1,800 + 500.
  int get bodyBurn => (profile?.tdee(bodyKg) ?? (baseKcal + 500)).round();

  /// Today's steps: from the health store when there is one, typed in otherwise.
  int get stepsToday => stepsHistory[today] ?? manualSteps ?? 0;

  /// Exercise burned today, above resting (the day job's walking is already in [bodyBurn]):
  /// steps beyond 3,000 at ≈0.5 kcal per kg per km, treadmill as measured, gym sets at ≈3 min each
  /// of strength work (5 MET).
  ({int walk, int treadmill, int gym}) get moved => (
    walk: ((stepsToday - 3000).clamp(0, 100000) / 1350 * .5 * bodyKg).round(),
    treadmill: cardio.fold(0.0, (a, c) => a + c.kcal).round(),
    gym: (setsDoneToday * 3 / 60 * (5 - 1) * bodyKg).round(),
  );
  int get movedKcal => moved.walk + moved.treadmill + moved.gym;

  /// 0 lose, 1 keep, 2 gain (the original plan, without a profile, is a loss plan).
  int get goal => profile?.goal ?? 0;
  bool get gaining => goal == 2;

  /// Still to burn today to stay on plan: eaten over the target, less what's already been moved.
  /// Not for a gain: going over is the point.
  int get burnLeft => gaining ? 0 : (kcal - kcalGoal - movedKcal).clamp(0, 1 << 30);

  /// Gain: still to eat today to reach the target, plus whatever exercise burned on top.
  int get eatLeft => gaining ? (kcalGoal + movedKcal - kcal).clamp(0, 1 << 30) : 0;

  /// Minutes of an activity of [met] that burn [kcal] above resting, at this body weight.
  int minutesFor(int kcal, double met) => (kcal / ((met - 1) * bodyKg / 60)).ceil();

  // ---- spending ----

  /// Expenses in a month ('yyyy-mm'), newest first.
  List<Expense> expensesIn(String month) =>
      expenses.where((e) => e.day.startsWith(month)).toList()..sort((a, b) => b.day.compareTo(a.day));
  int spentIn(String month) => expensesIn(month).fold(0, (a, e) => a + e.taka);
  Map<String, int> byCategory(String month) {
    final out = <String, int>{};
    for (final e in expensesIn(month)) {
      out[e.cat] = (out[e.cat] ?? 0) + e.taka;
    }
    return out;
  }

  void addExpense(Expense e) {
    expenses.add(e);
    _save();
  }

  void removeExpense(Expense e) {
    expenses.remove(e);
    _save();
  }

  void setBudget(int? taka) {
    monthBudget = taka == null || taka <= 0 ? null : taka;
    _save();
  }

  void setProfile(Profile? p) {
    profile = p;
    _save();
  }

  double portionOf(Meal m) => portion[m.id] ?? 1;
  bool ateOther(Meal m) => other[m.id]?.isNotEmpty ?? false;
  bool mealRare(Meal m) => other[m.id]?.any((e) => e.rare) ?? false;

  /// What this meal counts for: the swapped-in foods, or the planned option × portion.
  int mealKcal(Meal m) =>
      ateOther(m) ? other[m.id]!.fold(0, (a, e) => a + e.totalKcal) : (optKcal(m, chosen(m)) * portionOf(m)).round();
  int mealProtein(Meal m) => ateOther(m)
      ? other[m.id]!.fold(0, (a, e) => a + e.totalProtein)
      : (optProtein(m, chosen(m)) * portionOf(m)).round();
  String mealLabel(Meal m) {
    if (skipped.contains(m.id)) return 'Skipped';
    if (ateOther(m)) return other[m.id]!.map((e) => e.qty == 1 ? e.name : '${_q(e.qty)} × ${e.name}').join(', ');
    final p = portionOf(m);
    return p == 1 ? chosen(m).name : '${chosen(m).name} · ${_q(p)}×';
  }

  static String _q(double q) => q == .5
      ? '½'
      : q == 1.5
      ? '1½'
      : q == q.roundToDouble()
      ? '${q.toInt()}'
      : '$q';

  Iterable<Meal> get _eatenMeals => meals.where((m) => done.containsKey(m.id));
  int get kcal => _eatenMeals.fold(0, (a, m) => a + mealKcal(m)) + extras.fold(0, (a, e) => a + e.totalKcal);
  int get protein => _eatenMeals.fold(0, (a, m) => a + mealProtein(m)) + extras.fold(0, (a, e) => a + e.totalProtein);

  /// Laps fully run (all 4 legs logged or skipped) in a row, ending today if today's lap is done.
  int get streak {
    final t = _date(today);
    var n = legsDone == 4 ? 1 : 0;
    for (var i = 1; i < 400; i++) {
      final d = dayKey(DateTime(t.year, t.month, t.day - i));
      if (frozenDays.contains(d)) continue; // a freeze kept it alive; it doesn't add a day
      if ((lapHistory[d] ?? 0) < 4) break;
      n++;
    }
    return n;
  }

  /// Longest run of full days ever (history plus today).
  int get bestStreak {
    final full = {
      ...lapHistory.entries.where((e) => e.value >= 4).map((e) => e.key),
      ...frozenDays,
      if (legsDone == 4) today,
    };
    var best = 0;
    for (final d in full) {
      final p = _date(d).subtract(const Duration(days: 1));
      if (full.contains(dayKey(p))) continue; // not the start of a run
      var n = 0;
      while (full.contains(dayKey(_date(d).add(Duration(days: n))))) {
        n++;
      }
      if (n > best) best = n;
    }
    return best;
  }

  int get rareToday => meals.where(mealRare).length + extras.where((e) => e.rare).length;

  // ---- junk-food rule: month 1 keep to a minimum (0), then at most 1 controlled meal a week ----

  /// Week of the cut, 1-based (days 1–7 are week 1).
  int get cutWeek => (lap - 1) ~/ 7 + 1;
  int get junkAllowance => lap <= 30 ? 0 : 1;

  /// Days of the current cut week so far, oldest first.
  List<String> get weekDaysSoFar => lastDays(lap - (cutWeek - 1) * 7);
  int get junkThisWeek => weekDaysSoFar.fold(0, (a, d) => a + (d == today ? rareToday : junkHistory[d] ?? 0));

  /// First day of the next cut week.
  DateTime get weekResets {
    final t = _date(today);
    return DateTime(t.year, t.month, t.day + 7 - (lap - 1) % 7);
  }

  Meal? get nextMeal =>
      meals.where((m) => !done.containsKey(m.id) && !skipped.contains(m.id) && !fasted(m)).firstOrNull;

  void choose(Meal m, int i) {
    option[m.id] = i;
    _save();
  }

  void toggleMeal(Meal m) => done.containsKey(m.id) ? unlogMeal(m) : logMeal(m);

  /// Log a meal: the planned option at [portionX], or [instead] (foods eaten instead of the plan).
  void logMeal(Meal m, {double portionX = 1, List<Eaten>? instead}) {
    final t = DateTime.now();
    done[m.id] = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    skipped.remove(m.id);
    portionX == 1 ? portion.remove(m.id) : portion[m.id] = portionX;
    instead == null || instead.isEmpty ? other.remove(m.id) : other[m.id] = instead;
    option.putIfAbsent(m.id, () => m.options.indexOf(chosen(m))); // keeps the option it was logged as
    _noteRecent(instead ?? const []);
    _save();
  }

  void unlogMeal(Meal m) {
    done.remove(m.id);
    skipped.remove(m.id);
    other.remove(m.id);
    portion.remove(m.id);
    _save();
  }

  void skipMeal(Meal m) {
    unlogMeal(m);
    skipped.add(m.id);
    _save();
  }

  void _noteRecent(List<Eaten> items) {
    for (final e in items) {
      recentFoods
        ..remove(e.name)
        ..insert(0, e.name);
    }
    if (recentFoods.length > 12) recentFoods = recentFoods.sublist(0, 12);
  }

  void addExtras(List<Eaten> items) {
    extras.addAll(items);
    _noteRecent(items);
    _save();
  }

  void addExtra(Eaten e) {
    extras.add(e);
    _save();
  }

  void removeExtra(int i) {
    extras.removeAt(i);
    _save();
  }

  void rememberCustom(Eaten e) => saveCustomFood(e);

  /// Add or edit one of your own foods (database screen and meal sheet). [replacing] = old name when renamed.
  void saveCustomFood(Eaten e, {String? replacing}) {
    final i = customFoods.indexWhere((c) => c.name == (replacing ?? e.name));
    customFoods.removeWhere((c) => c.name == e.name || c.name == replacing);
    customFoods.insert(i < 0 ? 0 : i.clamp(0, customFoods.length), e.withQty(1));
    _save();
  }

  void removeCustomFood(String name) {
    customFoods.removeWhere((c) => c.name == name);
    aiFoods.removeWhere((c) => c.name == name);
    recentFoods.remove(name);
    _save();
  }

  void setWater(int glasses) {
    water = glasses.clamp(0, waterGoal);
    waterHistory[today] = water;
    _save();
  }

  void setManualSteps(int? v) {
    manualSteps = v;
    v == null ? stepsHistory.remove(today) : stepsHistory[today] = v;
    _save();
  }

  /// The last [n] local days as keys, oldest first, ending today.
  List<String> lastDays(int n) {
    final t = _date(today);
    return [for (var i = n - 1; i >= 0; i--) dayKey(t.subtract(Duration(days: i)))];
  }

  /// Step target on a given day of the cut (7k → 8k → 10k build-up).
  int stepTargetOn(String day) => stepTargetForDay(_date(day).difference(_date(startDay)).inDays + 1);

  void toggleGym(String ex) {
    if (!gymTicks.remove(ex)) {
      gymTicks.add(ex);
    } else {
      final before = _planBefore.remove(ex); // un-ending an exercise also takes back its deload
      if (before != null) plans[ex] = before;
    }
    _save();
  }

  // ---- push / pull / legs ----

  static const splitDays = ['Push', 'Pull', 'Legs'];

  /// Core work rides along on leg day; everything else goes where its body area says.
  static String dayFor(String ex) => switch (areaOf(ex)) {
    'Pull' => 'Pull',
    'Legs' || 'Core' => 'Legs',
    _ => 'Push',
  };

  void _splitFromExercises() {
    routine = {for (final d in splitDays) d: []};
    for (final ex in exercises) {
      routine[dayFor(ex)]!.add(ex);
    }
  }

  /// Today's split day: picked by hand, else what was trained today, else the one after the last
  /// trained day (Push → Pull → Legs → Push).
  String get gymDay {
    if (routinePickDate == today && routinePick != null) return routinePick!;
    final trained = routineLog[today];
    if (trained != null) return trained;
    final past = routineLog.keys.where((d) => d.compareTo(today) < 0).toList()..sort();
    if (past.isEmpty) return splitDays.first;
    return splitDays[(splitDays.indexOf(routineLog[past.last]!) + 1) % splitDays.length];
  }

  List<String> exercisesOn(String day) => [
    for (final e in routine[day] ?? const <String>[])
      if (exercises.contains(e)) e,
  ];
  List<String> get dayExercises => exercisesOn(gymDay);
  String splitDayOf(String ex) => splitDays.firstWhere((d) => routine[d]?.contains(ex) ?? false, orElse: () => gymDay);

  void pickGymDay(String day) {
    routinePickDate = today;
    routinePick = day;
    _save();
  }

  void moveExercise(String ex, String day) {
    for (final l in routine.values) {
      l.remove(ex);
    }
    (routine[day] ??= []).add(ex);
    _save();
  }

  void addExercise(String name, {String? day}) {
    final n = name.trim();
    if (n.isEmpty || exercises.contains(n)) return;
    exercises.add(n);
    (routine[day ?? gymDay] ??= []).add(n);
    _save();
  }

  void removeExercise(String ex) {
    exercises.remove(ex);
    gymTicks.remove(ex);
    for (final l in routine.values) {
      l.remove(ex);
    }
    _save();
  }

  /// Clears today's ticks and logged sets (history of earlier days stays).
  void clearGymTicks() {
    gymTicks = {};
    for (final days in setLog.values) {
      days.remove(today);
    }
    _save();
  }

  ExPlan plan(String ex) => plans[ex] ?? gymPlans[ex] ?? planForNew(ex);
  List<SetLog> setsToday(String ex) => setLog[ex]?[today] ?? const [];

  /// Done = ticked by hand, or every planned set logged.
  bool exerciseDone(String ex) => gymTicks.contains(ex) || setsToday(ex).length >= plan(ex).sets;
  int get setsDoneToday => exercises.fold(0, (a, e) => a + setsToday(e).length.clamp(0, plan(e).sets));
  int get setsPlannedToday => exercises.fold(0, (a, e) => a + plan(e).sets);
  int setsDoneOn(List<String> exs) => exs.fold(0, (a, e) => a + setsToday(e).length.clamp(0, plan(e).sets));
  int setsPlannedOn(List<String> exs) => exs.fold(0, (a, e) => a + plan(e).sets);

  /// The most recent earlier day this exercise was logged: (day, sets).
  (String, List<SetLog>)? lastSession(String ex) {
    final days = (setLog[ex]?.keys ?? const <String>[]).where((d) => d != today).toList()..sort();
    return days.isEmpty ? null : (days.last, setLog[ex]![days.last]!);
  }

  final _planBefore = <String, ExPlan>{}; // so undoing the last set also undoes its step up

  /// Logs a set. When the last planned set is in, sets the next session's plan and says how.
  String? logSet(String ex, int reps, double kg) {
    final days = setLog.putIfAbsent(ex, () => {});
    final p = plan(ex);
    routineLog[today] = splitDayOf(ex); // what was trained today sets what comes next
    final sets = days[today] = [...days[today] ?? const <SetLog>[], SetLog(reps, kg)];
    // keep the last 10 sessions per exercise
    // first session ever, kept for good: "since you started" survives the history trim below
    if (strengthFirst[ex] == null || strengthFirst[ex]!.$1 == today) {
      strengthFirst[ex] = (today, _best(sets, p.timed));
    }
    // keep the last 60 sessions per exercise (about 6 months at 2–3 a week)
    if (days.length > 60) days.remove((days.keys.toList()..sort()).first);
    String? msg;
    final next = sets.length == p.sets ? progress(p, sets) : null;
    if (sets.length == p.sets && next == null) msg = _deloadIfShortTwice(ex, p, sets);
    if (next != null) {
      _planBefore[ex] = p;
      plans[ex] = next;
      final kgS = next.kg == next.kg.roundToDouble() ? '${next.kg.toInt()}' : '${next.kg}';
      msg = p.timed
          ? 'All sets hit. Next time: ${next.reps} s'
          : next.kg == 0
          ? 'All sets hit. Next time: ${next.reps} reps'
          : 'All sets hit. Next time: $kgS kg';
    }
    _save();
    return msg;
  }

  /// Progressive overload: every set at plan reps and weight → a step up (+2.5 kg, +1 kg under
  /// 20 kg, +1 rep bodyweight, +5 s holds). Missed reps or lighter → the same plan. Never lowers.
  static ExPlan? progress(ExPlan p, List<SetLog> sets) {
    if (sets.length < p.sets || sets.any((x) => x.reps < p.reps)) return null;
    if (p.timed) return p.copyWith(reps: p.reps + 5);
    final kg = sets.map((x) => x.kg).reduce(math.min);
    if (kg < p.kg) return null;
    if (kg == 0) return p.copyWith(reps: p.reps + 1);
    return p.copyWith(kg: kg + (kg >= 20 ? 2.5 : 1));
  }

  /// Strength gone after 1–2 sets: stop the exercise here. It counts as done today, the plan
  /// holds, and a second short session in a row eases the weight (see [deload]).
  String? endExercise(String ex) {
    final p = plan(ex);
    gymTicks.add(ex);
    final msg = _deloadIfShortTwice(ex, p, setsToday(ex));
    _save();
    return msg;
  }

  /// Short = fewer sets than planned, or reps missed, at the planned weight or more.
  static bool isShort(ExPlan p, List<SetLog> sets) =>
      sets.isNotEmpty && (sets.length < p.sets || sets.any((x) => x.reps < p.reps)) && sets.every((x) => x.kg >= p.kg);

  /// Two short sessions in a row: 10% lighter (nearest 2.5 kg), or 5 s shorter holds, so all the
  /// sets come back. Bodyweight stays: there's nothing to take off.
  static ExPlan? deload(ExPlan p) => p.timed
      ? (p.reps > 15 ? p.copyWith(reps: p.reps - 5) : null)
      : p.kg <= 0
      ? null
      : p.copyWith(kg: math.max(2.5, (p.kg * .9 / 2.5).round() * 2.5));

  String? _deloadIfShortTwice(String ex, ExPlan p, List<SetLog> sets) {
    final last = lastSession(ex);
    if (!isShort(p, sets) || last == null || !isShort(p, last.$2)) return null;
    final eased = deload(p);
    if (eased == null || (eased.kg == p.kg && eased.reps == p.reps)) return null;
    _planBefore[ex] = p;
    plans[ex] = eased;
    final kgS = eased.kg == eased.kg.roundToDouble() ? '${eased.kg.toInt()}' : '${eased.kg}';
    return p.timed ? 'Two short sessions · next time ${eased.reps} s' : 'Two short sessions · next time $kgS kg';
  }

  /// The best set of a session: longest hold, most reps at bodyweight, else the heaviest weight
  /// (more reps breaks a tie).
  static SetLog _best(List<SetLog> sets, bool timed) => sets.reduce((a, b) {
    if (timed || (a.kg == 0 && b.kg == 0)) return b.reps > a.reps ? b : a;
    if (b.kg != a.kg) return b.kg > a.kg ? b : a;
    return b.reps > a.reps ? b : a;
  });

  /// How each exercise has grown since its first session, biggest gain first. Only exercises
  /// logged on at least two days. unit: 'kg' (heaviest set), 'reps' (bodyweight), 's' (hold).
  List<({String ex, String unit, double start, double now, double best, List<double> series})> get strength {
    final out = <({String ex, String unit, double start, double now, double best, List<double> series})>[];
    for (final ex in {...setLog.keys, ...strengthFirst.keys}) {
      final timed = plan(ex).timed;
      final days = (setLog[ex] ?? const {}).entries.where((e) => e.value.isNotEmpty).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final sessions = [
        if (strengthFirst[ex] != null && (days.isEmpty || strengthFirst[ex]!.$1.compareTo(days.first.key) < 0))
          strengthFirst[ex]!.$2,
        for (final d in days) _best(d.value, timed),
      ];
      if (sessions.length < 2) continue;
      final bodyweight = sessions.every((x) => x.kg == 0);
      final unit = timed ? 's' : (bodyweight ? 'reps' : 'kg');
      double v(SetLog x) => unit == 'kg' ? x.kg : x.reps.toDouble();
      final series = sessions.map(v).toList();
      out.add((
        ex: ex,
        unit: unit,
        start: series.first,
        now: series.last,
        best: series.reduce((a, b) => a > b ? a : b),
        series: series,
      ));
    }
    double gain(({String ex, String unit, double start, double now, double best, List<double> series}) x) =>
        x.start == 0 ? 0 : (x.now - x.start) / x.start;
    return out..sort((a, b) => gain(b).compareTo(gain(a)));
  }

  /// Which body area an exercise trains, from its name (legs before push: "leg press").
  static String areaOf(String ex) {
    final n = ex.toLowerCase();
    const areas = [
      ('Core', ['plank', 'core', 'crunch', 'sit-up', 'situp', 'ab ', 'abs', 'hold', 'hang', 'bridge', 'twist']),
      ('Legs', ['leg', 'squat', 'lunge', 'deadlift', 'calf', 'hip', 'glute', 'step-up']),
      ('Pull', ['pull', 'row', 'lat', 'curl', 'bicep', 'chin', 'shrug', 'face']),
    ];
    for (final (area, words) in areas) {
      if (words.any(n.contains)) return area;
    }
    return 'Push'; // chest, shoulder press, triceps, push-ups, dips, flys
  }

  /// Average gain since the first session, per body area and overall (0.25 = +25%).
  ({double? overall, Map<String, double> areas}) get strengthSummary {
    final rows = strength.where((r) => r.start > 0).toList();
    if (rows.isEmpty) return (overall: null, areas: const {});
    double avg(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double gain(({String ex, String unit, double start, double now, double best, List<double> series}) r) =>
        (r.now - r.start) / r.start;
    final areas = <String, double>{};
    for (final a in const ['Push', 'Pull', 'Legs', 'Core']) {
      final xs = rows.where((r) => areaOf(r.ex) == a).map(gain);
      if (xs.isNotEmpty) areas[a] = avg(xs);
    }
    return (overall: avg(rows.map(gain)), areas: areas);
  }

  void undoSet(String ex) {
    final sets = setLog[ex]?[today];
    if (sets == null || sets.isEmpty) return;
    setLog[ex]![today] = sets.sublist(0, sets.length - 1);
    final before = _planBefore.remove(ex);
    if (before != null) plans[ex] = before;
    _save();
  }

  void setTreadmill({double? speed, double? incline}) {
    treadSpeed = speed ?? treadSpeed;
    treadIncline = incline ?? treadIncline;
    _save();
  }

  void addCardio(Cardio c) {
    cardio.add(c);
    _save();
  }

  /// Body weight for calorie estimates: latest weigh-in, else the start weight.
  double get bodyKg => latestKg ?? startKg;

  void finishOnboarding({required DateTime start, required double kg, double? todayKg}) {
    startDay = dayKey(start);
    startKg = kg;
    onboarded = true;
    lastOpenDay = today;
    if (todayKg != null) {
      weights.removeWhere((w) => w.day == today);
      weights.add(Weigh(today, todayKg));
    }
    _save();
  }

  // ---- hints: one coach card a day, each shown once; the first-meal tip doesn't count ----

  static const cardHints = ['reminders', 'backup', 'widget', 'pace', 'junk-rule'];

  /// True on day 1 until the first meal is logged: "tap a meal, the runner runs 100 m".
  bool get showFirstWin => onboarded && !seenHints.contains('first-win') && mealsDone == 0 && lapHistory.isEmpty;

  /// Which card hint is eligible today (order = priority), ignoring the once-a-day limit.
  String? get _eligibleHint {
    for (final h in cardHints) {
      if (seenHints.contains(h)) continue;
      final ok = switch (h) {
        'reminders' => lap >= 2 && mealsDone >= 1 && !remindersOn,
        'backup' => lap >= 2 && !signedIn,
        'widget' => lapHistory.values.any((v) => v == 4),
        'pace' => lap >= 28 && lap <= 30 && weights.length >= 2,
        'junk-rule' => lap >= 31 && lap <= 37,
        _ => false,
      };
      if (ok) return h;
    }
    return null;
  }

  /// The coach card for today, or null. Claims the day's slot the first time it's asked.
  String? coachCard() {
    if (!onboarded) return null;
    if (hintDay == today) return hintToday != null && !seenHints.contains(hintToday) ? hintToday : null;
    final h = _eligibleHint;
    if (h == null) return null;
    hintDay = today;
    hintToday = h;
    _save();
    return h;
  }

  /// Event hints (first junk meal, steps check) jump the queue: they're about what just happened.
  void showHintNow(String h) {
    if (seenHints.contains(h)) return;
    hintDay = today;
    hintToday = h;
    _save();
  }

  void dismissHint(String h) {
    seenHints.add(h);
    _save();
  }

  bool get drawerDot => onboarded && lap >= 3 && !seenHints.contains('drawer');

  /// Days since the app was last opened (for "welcome back"); records today as opened.
  int markOpened() {
    final last = lastOpenDay;
    lastOpenDay = today;
    _save();
    return last == null ? 0 : _date(today).difference(_date(last)).inDays;
  }

  void setReminders(bool on) {
    remindersOn = on;
    if (on) seenHints.add('reminders');
    _save();
  }

  bool reminderOn(String type) => remindersOn && (reminderTypes[type] ?? true);

  void setReminderType(String type, bool on) {
    reminderTypes[type] = on;
    _save();
  }

  bool get pausedToday => pausedDay == today;

  void setPausedToday(bool on) {
    pausedDay = on ? today : null;
    _save();
  }

  /// Weighed in today already?
  bool get weighedToday => weights.any((w) => w.day == today);

  /// The cut day ([lap]) a given offset from today falls on.
  int lapIn(int days) => lap + days;

  void setHealthAsked() {
    healthAsked = true;
    _save();
  }

  // ---- after lap 84 ----

  bool get inMaintenance => maintenanceUntil != null && today.compareTo(maintenanceUntil!) <= 0;

  /// The day's kcal goal: the cut's 1,800, or ~2,300 during a planned 2-week maintenance break.
  int get kcalGoal => inMaintenance ? baseKcal + 500 : baseKcal;

  bool get needsFinishChoice => onboarded && lap >= laps && finishChoice == null;

  void chooseFinish(String choice) {
    finishChoice = choice;
    if (choice == 'again') {
      cutRound++;
      startDay = today;
      startKg = latestKg ?? startKg;
      finishChoice = null; // a new 84 laps; ask again at the end
    } else if (choice == 'maintenance') {
      final t = _date(today);
      maintenanceUntil = dayKey(DateTime(t.year, t.month, t.day + 13));
    }
    _save();
  }

  void restoreGym() {
    exercises = [...gymDefaults];
    _splitFromExercises();
    gymTicks.removeWhere((e) => !exercises.contains(e));
    _save();
  }

  /// One weigh-in per day; logging again the same day replaces it.
  void logWeight(double kg) {
    weights.removeWhere((w) => w.day == today);
    weights.add(Weigh(today, kg));
    _save();
  }

  void removeWeight(Weigh w) {
    weights.remove(w);
    _save();
  }

  double? get latestKg => weights.isEmpty ? null : weights.last.kg;

  /// Average of weigh-ins from the last 7 calendar days (not the last 7 entries).
  double? avgKg(int fromDaysAgo, int toDaysAgo) {
    final t = _date(today);
    final xs = weights
        .where((w) {
          final d = t.difference(_date(w.day)).inDays;
          return d >= fromDaysAgo && d < toDaysAgo;
        })
        .map((w) => w.kg)
        .toList();
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  /// The 7-day average once it holds 3+ weigh-ins; one morning swings 1–2 kg with water and salt.
  double? get trendKg {
    final t = _date(today);
    final n = weights.where((w) => t.difference(_date(w.day)).inDays < 7).length;
    return n >= 3 ? avgKg(0, 7) : null;
  }

  /// kg off the 7-day average over the last two weeks, or null without both weeks weighed.
  double? get twoWeekDrop {
    final a = avgKg(0, 7), b = avgKg(14, 21);
    return a == null || b == null ? null : b - a;
  }

  /// Under 0.4 kg a week for two weeks, after the first three (water weight) and not in a break.
  bool get stalled => goal == 0 && lap >= 21 && !inMaintenance && (twoWeekDrop ?? 1) < .8;

  /// Average kcal and protein over the last 7 finished days that have food logged.
  ({int kcal, int protein, int days}) get weekFood {
    final ds = lastDays(8).take(7).where((d) => (kcalHistory[d] ?? 0) > 0).toList();
    if (ds.isEmpty) return (kcal: 0, protein: 0, days: 0);
    int avg(Map<String, int> h) => ds.fold(0, (a, d) => a + (h[d] ?? 0)) ~/ ds.length;
    return (kcal: avg(kcalHistory), protein: avg(proteinHistory), days: ds.length);
  }

  /// Gym sessions in the current cut week (rule: 3–5).
  int get gymThisWeek => weekDaysSoFar.where((d) => (gymHistory[d] ?? 0) > 0).length;
  bool get gymToday => (gymHistory[today] ?? 0) > 0;

  /// Steps seen today (from Health), kept per day for perfect days and the recap.
  void noteSteps(int v) {
    if ((stepsHistory[today] ?? -1) == v) return;
    stepsHistory[today] = v;
    _save();
  }

  /// A perfect day: every meal, the water and the step target.
  bool perfect(String d) {
    final isToday = d == today;
    return (isToday ? legsDone : lapHistory[d] ?? 0) >= 4 &&
        (isToday ? water : waterHistory[d] ?? 0) >= waterGoal &&
        (stepsHistory[d] ?? 0) >= stepTargetOn(d);
  }

  int get perfectDays => {...lapHistory.keys, today}.where(perfect).length;

  /// The last 7 days ending today, for the weekly recap.
  ({int full, int perfect, int gym, int water, int steps, int spent, double? kgChange}) get week {
    final ds = lastDays(7);
    final kgA = avgKg(0, 7), kgB = avgKg(7, 14);
    final stepDays = ds.where((d) => stepsHistory[d] != null).toList();
    return (
      full: ds.where((d) => (d == today ? legsDone : lapHistory[d] ?? 0) >= 4).length,
      perfect: ds.where(perfect).length,
      gym: ds.where((d) => (gymHistory[d] ?? 0) > 0).length,
      water: ds.where((d) => (d == today ? water : waterHistory[d] ?? 0) >= waterGoal).length,
      steps: stepDays.isEmpty ? 0 : stepDays.fold(0, (a, d) => a + stepsHistory[d]!) ~/ stepDays.length,
      spent: expenses.where((e) => ds.contains(e.day)).fold(0, (a, e) => a + e.taka),
      kgChange: kgA == null || kgB == null ? null : kgA - kgB,
    );
  }

  /// AI estimates counted on this phone for a quota day ('flash' / 'lite').
  Map<String, int> aiUsedOn(String day) => aiDay == day ? aiUsed : const {};

  /// One more estimate on [key]'s model, or [to] when Google says the day's quota is gone.
  void noteAi(String day, String key, {int? to}) {
    if (aiDay != day) {
      aiDay = day;
      aiUsed = {};
    }
    aiUsed[key] = to ?? (aiUsed[key] ?? 0) + 1;
    _save();
  }

  /// "2 Parathas, and dim bhaji!" and "2 parathas dim bhaji" are the same meal.
  /// Also "milk tea" = "dudh cha", "vat" = "bhat" (food_search.dart).
  static String aiKey(String text) => canonicalKey(text);

  bool hasEstimate(String text) => aiMeals.containsKey(aiKey(text));

  /// A saved estimate for this description, or null.
  List<Eaten>? savedEstimate(String text) {
    final k = aiKey(text);
    final hit = aiMeals.remove(k);
    if (hit != null) aiMeals[k] = hit; // most recent last, so the oldest goes first when full
    return hit;
  }

  /// Keep an estimate (last 100 descriptions) and its foods (last 200, one per name).
  void saveEstimate(String text, List<Eaten> items) {
    final k = aiKey(text);
    if (k.isEmpty || items.isEmpty) return;
    aiMeals
      ..remove(k)
      ..[k] = [for (final e in items) e.withQty(e.qty)];
    while (aiMeals.length > 100) {
      aiMeals.remove(aiMeals.keys.first);
    }
    for (final e in items) {
      aiFoods
        ..removeWhere((f) => f.name.toLowerCase() == e.name.toLowerCase())
        ..insert(0, e.withQty(1));
    }
    if (aiFoods.length > 200) aiFoods = aiFoods.sublist(0, 200);
    _save();
  }

  void setFamily(String? id) {
    familyId = id;
    _save();
  }

  // ---- coaching ----

  void setInvite(String role, String? code) {
    code == null ? inviteCodes.remove(role) : inviteCodes[role] = code;
    _save();
  }

  void addHelping(String owner, String name, String role) {
    helping = [
      ...helping.where((h) => h['owner'] != owner),
      {'owner': owner, 'name': name, 'role': role},
    ];
    _save();
  }

  void removeHelping(String owner) {
    helping = helping.where((h) => h['owner'] != owner).toList();
    _save();
  }

  /// A phone that only helps someone skips onboarding and opens on the people it helps; turning
  /// it off starts their own plan's onboarding.
  void setHelperOnly(bool v) {
    helperOnly = v;
    onboarded = v;
    _save();
  }

  /// How this person uses Daur (asked once, after the account): just them, a trainer, or family.
  void setRole(String r) {
    role = r;
    _save();
  }

  /// A Students / Family tab next to Today, Gym and Progress: trainers and family helpers, and
  /// anyone who has started helping someone.
  bool get helps => role == 'trainer' || role == 'family' || helping.isNotEmpty;

  /// A new diet chart (from the trainer, or back to the plan with null). Meals already logged keep
  /// what was eaten; the choice of option carries over where the chart still has it.
  void setChart(List<Meal>? c, {String by = '', List<String> changes = const [], String at = ''}) {
    if (c != null && c.length != 4) return; // four meals, or nothing
    chart = c;
    chartBy = c == null ? '' : by;
    chartChanges = changes;
    if (at.isNotEmpty) chartAt = at;
    useChart(c);
    _save();
  }

  /// What a helper picked to cook today ({meal id: option}); meals already eaten keep theirs.
  /// Returns what changed, in words, for the "Ma is cooking…" message.
  List<String> applyCook(Map<String, int> picks, {required String at}) {
    cookAt = at;
    final said = <String>[];
    for (final m in meals) {
      final i = picks[m.id];
      if (i == null || i < 0 || i >= m.options.length || done.containsKey(m.id)) continue;
      if (option[m.id] != i) said.add('${m.name}: ${m.options[i].name}');
      option[m.id] = i;
    }
    _save();
    return said;
  }

  /// After an Undo restored an older state: the chart or picks at [at] stay seen, not re-applied.
  void markPlanSeen(String kind, String at) {
    kind == 'diet' ? chartAt = at : cookAt = at;
    _save();
  }

  void seeNotes(String newest) {
    if (newest.compareTo(notesSeen) <= 0) return;
    notesSeen = newest;
    _save();
  }

  /// What a helper sees (cloud.dart publishes it): today's meals, kcal and protein, water, steps,
  /// sleep, weight, streak, gym and strength. No spending, no account details.
  Map<String, Object?> coachSummary() => {
    'v': 1,
    'day': today,
    'lap': lap,
    'streak': streak,
    'best': bestStreak,
    'meals': [
      for (final m in meals)
        {
          'name': m.name,
          'window': m.window,
          'status': done.containsKey(m.id)
              ? 'done'
              : skipped.contains(m.id)
              ? 'skipped'
              : fasted(m)
              ? 'fasting'
              : m == nextMeal
              ? 'next'
              : 'todo',
          'food': done.containsKey(m.id) ? mealLabel(m) : chosen(m).name,
          'option': m.options.indexOf(chosen(m)),
          'items': chosen(m).items,
          'kcal': mealKcal(m),
          'time': done[m.id],
        },
    ],
    'chart': [for (final m in meals) m.toJson()],
    'chartBy': chartBy,
    'chartChanges': chartChanges,
    'chartAt': chartAt,
    'extras': [
      for (final e in extras) {'name': e.name, 'kcal': e.totalKcal},
    ],
    'kcal': kcal,
    'kcalGoal': kcalGoal,
    'protein': protein,
    'proteinRange': [proteinRange.$1, proteinRange.$2],
    'goal': goal,
    'burnLeft': burnLeft,
    'eatLeft': eatLeft,
    'water': water,
    'waterGoal': waterGoal,
    'steps': stepsToday,
    'stepTarget': stepTargetOn(today),
    'sleepMin': sleepMin,
    'startKg': startKg,
    'nowKg': trendKg ?? latestKg,
    'weights': [
      for (final w in weights.length > 60 ? weights.sublist(weights.length - 60) : weights) [w.day, w.kg],
    ],
    'gymThisWeek': gymThisWeek,
    'sessions': [
      for (final d in (routineLog.keys.toList()..sort()).reversed.take(8)) [d, routineLog[d], gymHistory[d] ?? 0],
    ],
    'strength': [
      for (final x in strength) {'ex': x.ex, 'unit': x.unit, 'start': x.start, 'now': x.now},
    ],
  };

  int? get sleepMin => sleepHistory[today];
  void setSleep(int? minutes) {
    if (minutes == sleepHistory[today]) return;
    minutes == null || minutes <= 0 ? sleepHistory.remove(today) : sleepHistory[today] = minutes;
    _save();
  }

  /// This phone's data now belongs to [uid] (first sign-in claims it).
  void claim(String uid) {
    ownerUid = uid;
    _save();
  }

  /// Erase everything on this phone (the caller signs out first, so the cloud copy stays).
  void eraseAll() {
    _read(const {});
    _save();
  }

  /// The cloud copy was deleted: the next sign-in claims this phone's data afresh.
  void releaseOwner() {
    ownerUid = null;
    _save();
  }

  /// A different person signed in and has nothing in the cloud: start them fresh, so one
  /// account's laps never land in another's. The previous owner's copy is already in the cloud.
  void startFresh(String uid) {
    _read(const {});
    ownerUid = uid;
    _save();
  }
}
