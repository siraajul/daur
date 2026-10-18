import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colours for warm ivory / muted teal, with a separately tuned dark palette.
/// Contrast evidence and alternatives live in design/color-research.html.
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

  // Warm ivory and muted teal: large surfaces stay neutral; accent marks actions and progress.
  static const light = Daur._(
    Color(0xFFF6F3EC),
    Color(0xFFEAEFE7),
    Color(0xFF25342F),
    Color(0xFF58665F),
    Color(0xFF7C8B81),
    Color(0xFFD3DAD1),
    Color(0xFF8A958E),
    Color(0xFF28645D),
    Color(0xFFFFFFFF),
    Color(0xFFFFFDF8),
    Color(0xFF25342F),
    Color(0xFF58665F),
    Color(0xFFD3DAD1),
  );
  static const dark = Daur._(
    Color(0xFF172420),
    Color(0xFF2D3F36),
    Color(0xFFEDF1E9),
    Color(0xFFB4BFB5),
    Color(0xFF7E9486),
    Color(0xFF42564A),
    Color(0xFF7E9486),
    Color(0xFF9CCFC0),
    Color(0xFF153E34),
    Color(0xFF22312B),
    Color(0xFFEDF1E9),
    Color(0xFFB4BFB5),
    Color(0xFF42564A),
  );

  /// Legacy name retained for existing callers; this is the accessible action tint.
  Color get sheetRed => accent;
  Color get error => identical(this, dark) ? const Color(0xFFFFB4AB) : const Color(0xFFA63C36);
  Color get warning => identical(this, dark) ? const Color(0xFFE3C27D) : const Color(0xFF805D1B);

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
    colorScheme: ColorScheme.fromSeed(seedColor: t.accent, brightness: b).copyWith(
      primary: t.accent,
      onPrimary: t.onAccent,
      surface: t.ground,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceContainer: t.infield,
      surfaceContainerLow: t.sheet,
      surfaceContainerHigh: t.infield,
      outline: t.lane,
      outlineVariant: t.rule,
      error: t.error,
    ),
    splashFactory: InkSparkle.splashFactory,
    // Native controls share the action tint.
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: t.sheetRed),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.infield,
      indicatorColor: t.ink.withValues(alpha: .22),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.ink)),
    ),
    // Menus use the neutral container surface.
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
    // Toasts use a raised surface and a readable action tint.
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
