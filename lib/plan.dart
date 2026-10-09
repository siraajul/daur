// Siraj's 12-week plan, carried over from "Siraj vai Diet App (1).html".
// kcal / protein per option are estimates (design/DIRECTION.md, Content).

const startWeightKg = 109.0;
const kcalTarget = 1800;
const proteinTarget = '130–150';
const waterGlasses = 14; // 250 ml each = 3.5 L
const laps = 84; // 12 weeks

class MealOption {
  final String name;
  final List<String> items;
  final int kcal, protein;
  const MealOption(this.name, this.items, this.kcal, this.protein);

  Map<String, Object> toJson() => {'n': name, 'i': items, 'k': kcal, 'p': protein};
  static MealOption from(Map j) => MealOption(
    j['n'] as String,
    [for (final x in j['i'] as List) x as String],
    (j['k'] as num).toInt(),
    (j['p'] as num).toInt(),
  );
}

class Meal {
  final String id, name, window, note;
  final List<MealOption> options;
  const Meal(this.id, this.name, this.window, this.options, [this.note = '']);

  Meal withOptions(List<MealOption> options, [String? note]) => Meal(id, name, window, options, note ?? this.note);

  Map<String, Object> toJson() => {
    'id': id,
    'n': name,
    'w': window,
    'o': [for (final o in options) o.toJson()],
    if (note.isNotEmpty) 'note': note,
  };
  static Meal from(Map j) => Meal(
    j['id'] as String,
    j['n'] as String,
    j['w'] as String,
    [for (final o in j['o'] as List) MealOption.from(o as Map)],
    j['note'] as String? ?? '',
  );
}

/// Today's diet chart: the trainer's when there is one (Store.setChart), else the plan below.
/// The four meals and their windows stay; what's in each meal is the chart's.
List<Meal> get meals => _chart;
List<Meal> _chart = defaultMeals;
void useChart(List<Meal>? chart) => _chart = chart == null || chart.length != 4 ? defaultMeals : chart;

const defaultMeals = [
  Meal('m1', 'Breakfast', '08:00–09:00', [
    MealOption(
      'Eggs + roti',
      ['3 eggs: 2 whole + 1 white', '2 small atta roti', 'Cucumber, tomato, onion', 'Tea or coffee, no sugar'],
      384,
      22,
    ),
    MealOption('Eggs + oats', ['3 eggs: 2 whole + 1 white', '1 small bowl oats', '1 small banana'], 402, 24),
    MealOption(
      'Omelette',
      ['2-egg vegetable omelette', '2 small atta roti', 'Cucumber, tomato', 'Tea, no sugar'],
      356,
      17,
    ),
  ], 'Skip paratha, puri, singara, samosa, halwa, sweet biscuits, sugary tea'),
  Meal('m2', 'Lunch', '13:00–14:30', [
    MealOption(
      'Chicken',
      [
        '180–200 g chicken',
        '1 cup cooked rice',
        '1.5–2 cups vegetables',
        'Salad: cucumber, tomato, carrot, lemon',
        'Optional: ½ cup dal',
      ],
      640,
      52,
    ),
    MealOption(
      'Fish: rui + 1 cup rice',
      [
        '200 g fish (rui, katla, tilapia, pabda, koi)',
        '1 cup cooked rice',
        '1.5–2 cups vegetables',
        'Salad: cucumber, tomato, carrot, lemon',
        'Optional: ½ cup dal',
      ],
      618,
      46,
    ),
  ], 'Little oil. Pangas and ilish only sometimes'),
  Meal('m3', 'Snack', '16:30–18:00', [
    MealOption('Banana', ['1 small banana', 'Black tea or coffee, no sugar'], 95, 1),
    MealOption('Guava + egg', ['1 guava', '1 boiled egg'], 140, 8),
    MealOption('Apple + almonds', ['1 apple', '10 almonds'], 165, 4),
    MealOption('Gym day: banana + whey', ['1 banana', '1 scoop whey with water'], 212, 25),
  ], 'Skip chanachur, biscuits, singara, samosa, cake, soft drinks, sweet tea'),
  Meal('m4', 'Dinner', '20:00–21:00', [
    MealOption(
      'Chicken + potol',
      ['180–200 g chicken', 'Large serving of vegetables', 'Large salad', '1 small atta roti'],
      538,
      49,
    ),
    MealOption('Fish', ['200 g fish', 'Large serving of vegetables', 'Salad', '1 small roti'], 512, 44),
    MealOption('Eggs', ['2 whole eggs + 3 egg whites', 'Mixed vegetables', '1 small roti'], 430, 27),
    MealOption(
      'Bengali',
      ['Chicken or fish', 'Lau, potol, jhinga or shak', 'Salad', 'Optional: ½ cup rice instead of roti'],
      560,
      42,
    ),
  ]),
];

/// Starting plan per exercise: sets × reps at kg. For timed holds, reps are seconds.
/// Logging a set updates the plan, so next session starts from what you actually did.
class ExPlan {
  final int sets, reps;
  final double kg;
  final bool timed;
  const ExPlan(this.sets, this.reps, this.kg, {this.timed = false});
  ExPlan copyWith({int? reps, double? kg}) => ExPlan(sets, reps ?? this.reps, kg ?? this.kg, timed: timed);
}

const gymPlans = {
  'Chest press / bench press': ExPlan(3, 10, 40),
  'Lat pulldown': ExPlan(3, 12, 55),
  'Seated row': ExPlan(3, 12, 50),
  'Shoulder press': ExPlan(3, 10, 14),
  'Leg press / squat': ExPlan(3, 12, 120),
  'Romanian deadlift': ExPlan(3, 10, 40),
  'Biceps curl': ExPlan(3, 12, 10),
  'Triceps pushdown': ExPlan(3, 12, 25),
  'Core / plank': ExPlan(3, 45, 0, timed: true),
};
final gymDefaults = gymPlans.keys.toList();
const newExercisePlan = ExPlan(3, 10, 0);

/// A new exercise's starting plan from its name: holds are timed (plank, wall sit, hang),
/// everything else starts as 3 × 10 at bodyweight (push-ups, pull-ups) until a weight is logged.
ExPlan planForNew(String name) => RegExp(r'plank|hold|wall ?sit|hang|bridge', caseSensitive: false).hasMatch(name)
    ? const ExPlan(3, 30, 0, timed: true)
    : newExercisePlan;
const restSeconds = 90;
const cardioTargetMin = 25;

/// Walking build-up: weeks 1–2 → 7,000, weeks 3–4 → 8,000, then 10,000 (9–10k).
int stepTargetForDay(int day) => day <= 14
    ? 7000
    : day <= 28
    ? 8000
    : 10000;

const fish = ['Rui', 'Katla', 'Tilapia', 'Pabda', 'Koi'];
const fishSometimes = ['Pangas', 'Ilish'];
const vegetables = [
  'Lau',
  'Jhinga',
  'Potol',
  'Papaya',
  'Beans',
  'Shak',
  'Cauliflower',
  'Cabbage',
  'Begun',
  'Mixed veg',
];
const keepRare = {
  'Fried': 'Singara, samosa, puri, beguni, pakora, fried chicken',
  'Fast food': 'Burger, pizza, shawarma, french fries',
  'Heavy Bengali': 'Kacchi, biryani, tehari, oily beef kala bhuna, paratha + beef curry',
  'Drinks': 'Coke, Pepsi, sweet juice, milkshake, energy drinks, sugary tea or coffee',
  'Snacks': 'Chanachur, chips, biscuits, chocolate, cake, sweets',
};
const rules = [
  'About 1,800 kcal a day',
  '130–150 g protein a day',
  'No sugary drinks',
  'Measure cooking oil',
  'No unlimited rice',
  'Protein at every main meal',
  '7,000–10,000 steps',
  'Gym 3–5× a week',
  '7–8 hours of sleep',
  'Consistent for 12 weeks',
];
const milestones = [('Month 1', '105–106', 30), ('Month 2', '102–103', 60), ('Month 3', '99–101', 84)];

/// Default option per meal when none was picked: Eggs + oats and Guava + egg, so the default day
/// reaches the protein target (24 + 52 + 8 + 49 = 133 g, 1,720 kcal). Index 0 otherwise.
const defaultOption = {'m1': 1, 'm3': 1};

/// Body details for a personal plan. Without one, the app runs the original plan above.
class Profile {
  final bool male;
  final int age, heightCm;
  final int activity; // 0 desk job, 1 on my feet, 2 physical work
  final int goal; // 0 lose, 1 keep, 2 gain
  const Profile({required this.male, required this.age, required this.heightCm, this.activity = 0, this.goal = 0});

  static const activityNames = ['Desk job', 'On my feet', 'Physical work'];
  static const goalNames = ['Lose', 'Keep', 'Gain'];

  /// The weekly pace each goal aims for, in words.
  String get paceText => switch (goal) {
    1 => 'steady weight',
    2 => 'about 0.25 kg a week up',
    _ => 'about 0.5 kg a week down',
  };
  static const _factor = [1.2, 1.375, 1.55];

  Map<String, Object> toJson() => {'m': male, 'a': age, 'h': heightCm, 'act': activity, 'g': goal};
  static Profile from(Map j) => Profile(
    male: j['m'] as bool,
    age: (j['a'] as num).toInt(),
    heightCm: (j['h'] as num).toInt(),
    activity: (j['act'] as num?)?.toInt() ?? 0,
    goal: (j['g'] as num?)?.toInt() ?? 0,
  );

  Profile copyWith({bool? male, int? age, int? heightCm, int? activity, int? goal}) => Profile(
    male: male ?? this.male,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
  );

  /// Maintenance calories: Mifflin–St Jeor × activity.
  double tdee(double kg) => (10 * kg + 6.25 * heightCm - 5 * age + (male ? 5 : -161)) * _factor[activity.clamp(0, 2)];

  /// Lose: about 0.5 kg a week, 500 under maintenance, never more than a quarter, never below a
  /// floor. Keep: maintenance. Gain: 300 over, a slow gain that stays mostly muscle with training.
  int kcal(double kg) {
    final m = tdee(kg);
    final k = switch (goal) {
      1 => m,
      2 => m + 300,
      _ => m - (m * .25).clamp(0, 500),
    }.clamp(male ? 1500.0 : 1200.0, 4500.0);
    return (k / 50).round() * 50;
  }

  /// 1.6–2.0 g per kg of a healthy-weight reference (BMI 25 cap), rounded to 5 g.
  (int, int) protein(double kg) {
    final h = heightCm / 100;
    final ref = kg / (h * h) > 25 ? 25 * h * h : kg;
    int r5(double v) => (v / 5).round() * 5;
    return (r5(ref * 1.6), r5(ref * (goal == 2 ? 2.2 : 2.0)));
  }

  /// 35 ml per kg, in 250 ml glasses, 8–16.
  int glasses(double kg) => (kg * 35 / 250).round().clamp(8, 16);

  /// Month targets from the expected change at this target (7,700 kcal ≈ 1 kg): down for Lose,
  /// the same for Keep, up for Gain.
  List<(String, String, int)> targets(double startKg) {
    final perMonth = (tdee(startKg) - kcal(startKg)) * 30 / 7700; // positive = down
    String half(double v) {
      final x = (v * 2).round() / 2; // nearest 0.5 kg
      return x.toStringAsFixed(x == x.roundToDouble() ? 0 : 1);
    }

    return [
      for (final (i, day) in const [30, 60, 84].indexed)
        (
          'Month ${i + 1}',
          '${half(startKg - perMonth * day / 30 - .5)}–${half(startKg - perMonth * day / 30 + .5)}',
          day,
        ),
    ];
  }
}
