import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// One icon vocabulary for food across the app (outlined/rounded Material, ink colour).
/// Category is told by shape, never by colour (design/DIRECTION.md: one accent, one role).

IconData mealIcon(String mealId) => switch (mealId) {
  'm1' => Icons.wb_twilight_rounded, // breakfast: sunrise
  'm2' => Icons.light_mode_outlined, // lunch: midday sun
  'm3' => Icons.local_cafe_outlined, // snack: tea break
  'm4' => Icons.bedtime_outlined, // dinner: night
  _ => Icons.restaurant_outlined,
};

IconData categoryIcon(String cat) => switch (cat) {
  'office-lunch' => Icons.dinner_dining_outlined,
  'street' => Icons.storefront_outlined,
  'staple' => Icons.rice_bowl_outlined,
  'protein' => Icons.set_meal_outlined,
  'curry/veg' => Icons.soup_kitchen_outlined,
  'breakfast' => Icons.breakfast_dining_outlined,
  'fast-food' => Icons.fastfood_outlined,
  'sweet' => Icons.cake_outlined,
  'drink' => Icons.local_drink_outlined,
  'fruit' => Icons.eco_outlined,
  'mine' => Icons.edit_note_rounded,
  _ => Icons.restaurant_outlined,
};

/// Keyword → icon, checked in order (first match wins), so "fish fry" is fish, not fried.
const _foodWords = <(List<String>, IconData)>[
  (['egg', 'omelette', 'dim ', 'dimer', 'dim-'], Icons.egg_alt_outlined),
  (['salad', 'shosha', 'cucumber'], Icons.eco_outlined),
  (['pizza'], Icons.local_pizza_outlined),
  (['burger', 'sandwich', 'shawarma', 'roll'], Icons.lunch_dining_outlined),
  (['fries', 'fried chicken', 'nugget'], Icons.fastfood_outlined),
  (['noodle', 'chowmein', 'soup', 'haleem', 'nehari', 'paya', 'pasta', 'ramen'], Icons.ramen_dining_outlined),
  (['tea', 'cha', 'coffee', 'latte'], Icons.emoji_food_beverage_outlined),
  (
    [
      'juice',
      'coke',
      'pepsi',
      'soft drink',
      'lassi',
      'borhani',
      'milk',
      'shake',
      'water',
      'energy drink',
      'sugarcane',
      'ros',
    ],
    Icons.local_drink_outlined,
  ),
  (['ice cream', 'kulfi'], Icons.icecream_outlined),
  (['biscuit', 'cookie', 'chanachur', 'chips'], Icons.cookie_outlined),
  (
    [
      'mishti',
      'roshogolla',
      'chomchom',
      'kalojam',
      'jilapi',
      'jalebi',
      'firni',
      'payesh',
      'sandesh',
      'halua',
      'pitha',
      'cake',
      'laddu',
      'chocolate',
      'sweet',
    ],
    Icons.cake_outlined,
  ),
  (
    [
      'fish',
      'mach',
      'rui',
      'katla',
      'ilish',
      'hilsa',
      'pangas',
      'tilapia',
      'koi',
      'pabda',
      'shing',
      'magur',
      'chingri',
      'prawn',
      'shrimp',
      'shutki',
    ],
    Icons.set_meal_outlined,
  ),
  (
    [
      'chicken',
      'murg',
      'beef',
      'gorur',
      'mutton',
      'khasi',
      'kebab',
      'kabab',
      'tikka',
      'chap',
      'boti',
      'meat',
      'mangsho',
    ],
    Icons.kebab_dining_outlined,
  ),
  (['rice', 'bhaat', 'polao', 'biryani', 'kacchi', 'tehari', 'khichuri', 'muri', 'chira'], Icons.rice_bowl_outlined),
  (
    ['roti', 'ruti', 'paratha', 'porota', 'naan', 'bread', 'toast', 'puri', 'luchi', 'bun', 'oats'],
    Icons.bakery_dining_outlined,
  ),
  (['dal', 'chola', 'chana', 'bhorta', 'bhaji', 'sabji', 'torkari', 'shak', 'curry'], Icons.soup_kitchen_outlined),
  (
    [
      'banana',
      'kola',
      'guava',
      'apple',
      'mango',
      'papaya',
      'orange',
      'malta',
      'melon',
      'jackfruit',
      'dates',
      'litchi',
      'grape',
      'pineapple',
      'almond',
      'fruit',
    ],
    Icons.eco_outlined,
  ),
  (['whey', 'protein'], Icons.fitness_center_rounded),
  (
    ['singara', 'samosa', 'piyaju', 'beguni', 'pakora', 'chop', 'fuchka', 'chotpoti', 'jhalmuri', 'velpuri'],
    Icons.storefront_outlined,
  ),
];

/// A food's own icon from its name, falling back to its category.
IconData foodIcon(String name, [String cat = '']) {
  final n = name.toLowerCase();
  for (final (words, icon) in _foodWords) {
    if (words.any(n.contains)) return icon;
  }
  return cat.isEmpty ? Icons.restaurant_outlined : categoryIcon(cat);
}

/// An icon in a soft disc: the leading visual of every food row and meal leg.
class IconDisc extends StatelessWidget {
  const IconDisc(this.icon, {super.key, this.size = 44, this.onSheet = false, this.rare = false, this.color});
  final IconData icon;
  final double size;
  final bool onSheet, rare;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final bg = onSheet ? t.sheetRule : t.infield;
    final fg = color ?? (onSheet ? t.sheetInk : t.ink);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: size * .52, color: fg),
          ),
          if (rare)
            Positioned(
              right: -3,
              top: -3,
              child: Tooltip(
                message: 'Junk food',
                child: Container(
                  width: size * .42,
                  height: size * .42,
                  decoration: BoxDecoration(
                    color: onSheet ? t.sheetRed : t.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: onSheet ? t.sheet : t.ground, width: 2),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: size * .26,
                    color: onSheet ? t.sheet : t.ground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small icon + value pair (e.g. a flame and "640", a dumbbell and "26 g").
class Stat extends StatelessWidget {
  const Stat(this.icon, this.text, {super.key, this.color, this.size = 13});
  final IconData icon;
  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final c = color ?? t.ink2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size + 2, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: c,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The Google "G", drawn (Material has no brand icons; no asset needed). Colours per Google's brand.
class GoogleG extends StatelessWidget {
  const GoogleG({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GPainter());
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .2, r = (size.width - w) / 2, c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double d) => d * 3.1415926535 / 180;
    Paint p(int color) => Paint()
      ..color = Color(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawArc(rect, rad(215), rad(105), false, p(0xFFEA4335)); // red, top
    canvas.drawArc(rect, rad(145), rad(70), false, p(0xFFFBBC05)); // yellow, left
    canvas.drawArc(rect, rad(40), rad(105), false, p(0xFF34A853)); // green, bottom
    canvas.drawArc(rect, rad(0), rad(40), false, p(0xFF4285F4)); // blue, lower right
    canvas.drawRect(
      Rect.fromLTRB(c.dx, c.dy - w / 2, c.dx + r + w / 2, c.dy + w / 2),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}

/// "Continue with Google": white pill, the G, dark label (Google's sign-in button guidelines).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.busy = false, this.label = 'Continue with Google'});
  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white70,
        foregroundColor: const Color(0xFF1F1F1F),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF747775))),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const GoogleG(size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

/// One idea, one icon, one short line: what replaces a paragraph of advice.
class Tip extends StatelessWidget {
  const Tip(this.icon, this.text, {super.key, this.onSheet = false});
  final IconData icon;
  final String text;
  final bool onSheet;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconDisc(icon, size: 36, onSheet: onSheet),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: t.body(weight: FontWeight.w400, color: onSheet ? t.sheetInk : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's targets as icon pills, not a sentence.
class TargetChips extends StatelessWidget {
  const TargetChips({super.key, required this.kcal, required this.protein, required this.litres});
  final int kcal;
  final (int, int) protein;
  final String litres;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final k = kcal >= 1000 ? '${kcal ~/ 1000},${(kcal % 1000).toString().padLeft(3, '0')}' : '$kcal';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, text) in [
          (Icons.local_fire_department_rounded, '$k kcal'),
          (Icons.egg_alt_outlined, '${protein.$1}–${protein.$2} g'),
          (Icons.water_drop_outlined, '$litres L'),
          (Icons.directions_walk_rounded, '7k → 10k'),
          (Icons.fitness_center_rounded, '3–5×'),
        ])
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: t.lane, width: 1.5)),
            ),
            child: Stat(icon, text, color: t.ink, size: 14),
          ),
      ],
    );
  }
}

/// Weekly loss on a bar: slow, on pace (0.6–0.9 kg a week), fast. The dot is this week.
class PaceGauge extends StatelessWidget {
  const PaceGauge({super.key, required this.perWeek, this.kcal, this.stalled = false});
  final double? perWeek; // kg lost per week; null = not enough weigh-ins
  final int? kcal; // the day's goal, for "stay at"
  final bool stalled;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    final v = perWeek;
    final kcalS = kcal == null ? '' : ' · stay at ${kcal! ~/ 1000},${(kcal! % 1000).toString().padLeft(3, '0')} kcal';
    final (icon, verdict) = stalled
        ? (Icons.trending_flat_rounded, 'Stalled · −150 kcal or +2,000 steps')
        : v == null
        ? (Icons.monitor_weight_outlined, 'Weigh 3–7 mornings, before breakfast · tap +')
        : v < .4
        ? (Icons.trending_flat_rounded, 'Slow · give it one more week')
        : v <= 1
        ? (Icons.check_circle_outline_rounded, 'On pace$kcalS')
        : (Icons.speed_rounded, 'Fast · eat a bit more if tired');
    return Semantics(
      label: v == null ? verdict : '${v.toStringAsFixed(1)} kilos a week. $verdict',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(painter: _PacePainter(t, v)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 20, color: v != null && v >= .6 && v <= 1 && !stalled ? t.accent : t.ink),
              const SizedBox(width: 8),
              Expanded(child: Text(verdict, style: t.body())),
            ],
          ),
        ],
      ),
    );
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter(this.t, this.v);
  final Daur t;
  final double? v;
  static const lo = -.25, hi = 1.5; // kg a week shown

  @override
  void paint(Canvas canvas, Size size) {
    double x(double kg) => (kg - lo) / (hi - lo) * size.width;
    const y = 30.0;
    final base = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = t.lane;
    canvas.drawLine(Offset(x(lo), y), Offset(x(hi), y), base);
    // the on-pace band
    canvas.drawLine(
      Offset(x(.6), y),
      Offset(x(.9), y),
      base
        ..color = t.ink
        ..strokeWidth = 10,
    );
    void label(String s, double kg) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: t.meta()),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x(kg) - tp.width / 2).clamp(0, size.width - tp.width), y + 9));
    }

    label('slow', .15);
    label('0.6–0.9', .75);
    label('fast', 1.3);
    final value = v;
    if (value == null) return;
    final p = Offset(x(value.clamp(lo, hi)), y);
    canvas.drawCircle(p, 9, Paint()..color = t.accent);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.ground,
    );
    final tp = TextPainter(
      text: TextSpan(text: '${value >= 0 ? '−' : '+'}${value.abs().toStringAsFixed(1)} kg/wk', style: t.sec(t.ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((p.dx - tp.width / 2).clamp(0, size.width - tp.width), 0));
  }

  @override
  bool shouldRepaint(_PacePainter o) => o.v != v || o.t != t;
}

/// The one header for every screen you open: back (or a down chevron for a session you close),
/// the big title on the same line, actions on the right, one short line under it. The same shape
/// as the tabs' header, where the menu button sits in place of back.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.sub, this.actions = const [], this.onBack, this.close = false});
  final String title;
  final String? sub;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final t = Daur.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack ?? () => Navigator.maybePop(context),
              tooltip: close ? 'Close' : 'Back',
              icon: Icon(close ? Icons.keyboard_arrow_down_rounded : Icons.arrow_back, color: t.ink),
            ),
            Expanded(
              child: Text(title, style: t.title(), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            ...actions,
          ],
        ),
        if (sub != null) Text(sub!, style: t.sec()),
      ],
    );
  }
}

/// Pop-ups in the app's look: a deep-red card, the question in the display font, one yellow pill
/// for the main action and plain ink text for the rest. Every pop-up in the app goes through here.
Widget _popCard(BuildContext context, String title, List<Widget> children) {
  final t = Daur.of(context);
  return Dialog(
    backgroundColor: t.infield,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.x(22)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

Widget _popMain(Daur t, String label, VoidCallback onTap) => FilledButton(
  onPressed: onTap,
  style: FilledButton.styleFrom(
    backgroundColor: t.accent,
    foregroundColor: t.onAccent,
    minimumSize: const Size.fromHeight(52),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  ),
  child: Text(label),
);

Widget _popSide(Daur t, String label, VoidCallback onTap) => TextButton(
  onPressed: onTap,
  style: TextButton.styleFrom(
    foregroundColor: t.ink,
    minimumSize: const Size.fromHeight(48),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  ),
  child: Text(label),
);

/// "Are you sure?": the action as the yellow pill, Cancel under it.
Future<bool> confirmPop(BuildContext context, String title, String body, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Daur.of(ctx);
        return _popCard(ctx, title, [
          Text(body, style: t.sec()),
          const SizedBox(height: 20),
          _popMain(t, action, () => Navigator.pop(ctx, true)),
          _popSide(t, 'Cancel', () => Navigator.pop(ctx, false)),
        ]);
      },
    ) ??
    false;

/// Asks for one number, typed big. [side] is an optional second action (closes first, then runs).
Future<double?> askNumber(
  BuildContext context,
  String title, {
  String? initial,
  String? hint,
  String? prefix,
  String? suffix,
  bool decimal = false,
  (String, VoidCallback)? side,
}) {
  final c = TextEditingController(text: initial ?? '');
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final t = Daur.of(ctx);
      void save() => Navigator.pop(ctx, double.tryParse(c.text.trim()));
      UnderlineInputBorder line(Color color) => UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2));
      return _popCard(ctx, title, [
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
          onSubmitted: (_) => save(),
          style: t.x(36),
          cursorColor: t.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.sec(t.ink2),
            prefixText: prefix,
            suffixText: suffix,
            prefixStyle: t.x(20),
            suffixStyle: t.x(18, color: t.ink2),
            enabledBorder: line(t.lane),
            focusedBorder: line(t.accent),
          ),
        ),
        const SizedBox(height: 20),
        _popMain(t, 'Save', save),
        if (side != null)
          _popSide(t, side.$1, () {
            Navigator.pop(ctx);
            side.$2();
          }),
      ]);
    },
  );
}
