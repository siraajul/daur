import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from design/DIRECTION.md. The ground is the running track:
/// tartan red by day, oxblood at night. Yellow has one job: "you are here / do this next".
class Daur {
  final Color ground, infield, ink, ink2, lane, rule, faint, accent, onAccent;
  final Color sheet, sheetInk, sheetInk2, sheetRule;
  const Daur._(
    this.ground,
    this.infield,
    this.ink,
    this.ink2,
    this.lane,
    this.rule,
    this.faint,
    this.accent,
    this.onAccent,
    this.sheet,
    this.sheetInk,
    this.sheetInk2,
    this.sheetRule,
  );

  static const light = Daur._(
    Color(0xFFAD3B26),
    Color(0xFF98321F),
    Color(0xFFFFF8F3),
    Color(0xFFFFD9CC),
    Color(0x8CFFF8F3),
    Color(0x47FFF8F3),
    Color(0x38FFF8F3),
    Color(0xFFFFD23F),
    Color(0xFF3A1208),
    Color(0xFFFFF6EF),
    Color(0xFF2A0E07),
    Color(0xFF7A4A3C),
    Color(0xFFEBD9CF),
  );
  static const dark = Daur._(
    Color(0xFF3D140C),
    Color(0xFF2C0E08),
    Color(0xFFFFF1EA),
    Color(0xFFE8B3A3),
    Color(0x61FFF1EA),
    Color(0x33FFF1EA),
    Color(0x29FFF1EA),
    Color(0xFFF5CB45),
    Color(0xFF3A1208),
    Color(0xFF1F0B07),
    Color(0xFFFFF1EA),
    Color(0xFFD9A898),
    Color(0xFF3A1A12),
  );

  /// Track red as text on the sheet: tartan on light, a lighter red on the dark sheet (contrast).
  Color get sheetRed => identical(this, dark) ? const Color(0xFFF2937B) : ground;

  static Daur of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;

  /// Display numerals (lap, metres, kg): wide and heavy. Unbounded stands in for SF Pro Expanded Black.
  TextStyle x(double size, {Color? color, FontWeight weight = FontWeight.w800}) => GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: weight,
    height: 1.0,
    letterSpacing: size >= 40 ? -size * 0.03 : 0,
    color: color ?? ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // Text steps: 28 title, 17 body, 15 secondary, 13 meta (the app's 7-step scale with 68 hero and 22 leg numerals).
  TextStyle title([Color? c]) => x(28, color: c ?? ink, weight: FontWeight.w700);
  TextStyle body({Color? color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontSize: 17, fontWeight: weight, color: color ?? ink, height: 1.25);
  TextStyle sec([Color? c]) => TextStyle(fontSize: 15, color: c ?? ink2, height: 1.35);
  TextStyle meta([Color? c]) => TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c ?? ink2, height: 1.3);
}

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.dark ? Daur.dark : Daur.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: t.ground,
    colorScheme: ColorScheme.fromSeed(seedColor: t.ground, brightness: b, surface: t.ground, primary: t.ink),
    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.infield,
      indicatorColor: t.ink.withValues(alpha: .22),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.ink)),
    ),
    // ⋯ menus: deep red like the pop-ups, not Material's default white
    popupMenuTheme: PopupMenuThemeData(
      color: t.infield,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.disabled) ? t.faint : t.ink,
        ),
      ),
    ),
    // toasts: the cream of the sheets so they stand out on the red, Undo in tartan red
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.sheet,
      contentTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.sheetInk),
      actionTextColor: t.sheetRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: t.sheet, showDragHandle: true),
    // Android's predictive back: the swipe previews the screen underneath; iOS keeps its own slide
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
