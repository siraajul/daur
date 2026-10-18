// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:daur/onboarding.dart';
import 'package:daur/l10n.dart';
import 'package:daur/plan.dart';
import 'package:daur/preferences.dart';
import 'package:daur/your_data.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:daur/store.dart';
import 'package:daur/theme.dart';
import 'package:daur/today.dart' show Cta;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignedOutAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform? get currentUser => null;
}

const draftKey = 'daur.onboarding.draft.v1';

Future<Store> openSetup(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
  double textScale = 1,
  Brightness brightness = Brightness.light,
  String language = 'en',
  Widget Function(Store)? screen,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final store = (await tester.runAsync(() async {
    final loaded = await Store.load();
    if (language != loaded.appLanguage) {
      loaded.setPreferences(language: language);
    }
    await loaded.saved;
    return loaded;
  }))!;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(brightness),
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen?.call(store) ?? OnboardingScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Map<String, Object> draft({int page = 1}) => {
  draftKey: jsonEncode({
    'start': DateTime.now().toIso8601String(),
    'kg': 72.5,
    'todayKg': null,
    'profile': const Profile(
      male: false,
      age: 42,
      heightCm: 164,
      activity: 1,
      goal: 1,
    ).toJson(),
    'page': page,
    'version': 2,
  }),
};

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Cta, 'Next'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = SignedOutAuth();
  });

  testWidgets(
    'numbered progress and Back work; no global Skip or swipe bypass',
    (tester) async {
      await openSetup(tester);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Back'), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 6'), findsOneWidget);
      await next(tester);
      expect(find.text('Step 2 of 6'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 6'), findsOneWidget);
    },
  );

  testWidgets('weight accepts direct input and rejects out-of-range values', (
    tester,
  ) async {
    await openSetup(tester, preferences: draft());
    await tester.tap(find.textContaining('72.5').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a weight between 30 and 300 kg'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '68.4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect((jsonDecode(preferences.getString(draftKey)!) as Map)['kg'], 68.4);
  });

  testWidgets(
    'saved draft resumes and review requires confirmation before saving profile',
    (tester) async {
      final store = await openSetup(tester, preferences: draft(page: 5));
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('Review your plan'), findsOneWidget);
      expect(find.text('Keep weight'), findsOneWidget);
      expect(find.text('Woman · 42 years · 164 cm'), findsOneWidget);
      expect(
        tester.widget<Cta>(find.widgetWithText(Cta, 'Start my plan')).onTap,
        isNull,
      );
      expect(store.onboarded, isFalse);
      final checkbox = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(
        checkbox,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      final control = find.descendant(
        of: checkbox,
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Cta>(find.widgetWithText(Cta, 'Start my plan')).onTap,
        isNotNull,
      );
      await tester.runAsync(() async {
        tester.widget<Cta>(find.widgetWithText(Cta, 'Start my plan')).onTap!();
        await store.saved;
      });
      await tester.pumpAndSettle();
      expect(store.onboarded, isTrue);
      expect(store.startKg, 72.5);
      expect(store.profile!.age, 42);
      expect(store.profile!.male, isFalse);
      expect(store.profile!.goal, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(draftKey),
        isNull,
      );
    },
  );

  testWidgets('goal and body details have separate focused steps', (
    tester,
  ) async {
    await openSetup(tester, preferences: draft(page: 2));
    expect(find.text('What is your goal?'), findsOneWidget);
    expect(find.text('Lose weight'), findsOneWidget);
    expect(find.text('Age'), findsNothing);
    await next(tester);
    expect(find.text('Step 4 of 6'), findsOneWidget);
    expect(find.text('Your body details'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Lose weight'), findsNothing);
  });

  testWidgets('desktop intro keeps guidance above the primary action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSetup(tester);
    final guidance = tester.getRect(find.text('Log your 4 meals a day.'));
    final action = tester.getRect(find.widgetWithText(Cta, 'Next'));
    expect(guidance.bottom, lessThan(action.top));
    expect(guidance.left, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small viewport with large text keeps body and review controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openSetup(tester, preferences: draft(page: 3), textScale: 2);
      expect(find.text('Your body details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await next(tester);
      await tester.tap(find.widgetWithText(Cta, 'Review my plan'));
      await tester.pumpAndSettle();
      final checkbox = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(
        checkbox,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      final control = find.descendant(
        of: checkbox,
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(control).value, isTrue);
      expect(
        tester.widget<Cta>(find.widgetWithText(Cta, 'Start my plan')).onTap,
        isNotNull,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dark onboarding CTA uses readable dark text on its pale accent',
    (tester) async {
      await openSetup(tester, brightness: Brightness.dark);
      final text = find.descendant(
        of: find.widgetWithText(Cta, 'Next'),
        matching: find.text('Next'),
      );
      final inherited = DefaultTextStyle.of(tester.element(text)).style;
      final effective = inherited.merge(tester.widget<Text>(text).style).color!;
      expect(effective, Daur.dark.onAccent);
      final light = Daur.dark.accent.computeLuminance();
      final dark = effective.computeLuminance();
      expect((light + .05) / (dark + .05), greaterThanOrEqualTo(4.5));
    },
  );

  testWidgets('Bangla onboarding translates progress, review and navigation', (
    tester,
  ) async {
    await openSetup(tester, preferences: draft(page: 5), language: 'bn');
    expect(find.text('ধাপ 6/6'), findsOneWidget);
    expect(find.text('আপনার পরিকল্পনা যাচাই করুন'), findsOneWidget);
    expect(find.text('ওজন স্থির রাখা'), findsOneWidget);
    await tester.tap(find.text(trLanguage('bn', 'Back')));
    await tester.pumpAndSettle();
    expect(find.text('আপনার ফোন থেকে কদম'), findsOneWidget);
    expect(find.widgetWithText(Cta, 'আমার পরিকল্পনা দেখুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bangla preferences translate food guidance, actions and language control',
    (tester) async {
      final store = await openSetup(
        tester,
        language: 'bn',
        screen: (s) => PreferencesScreen(store: s),
      );
      expect(find.text('খাবারের পছন্দ'), findsOneWidget);
      expect(find.text('অ্যালার্জি বা এড়িয়ে চলার খাবার'), findsOneWidget);
      final save = find.text('খাবারের নোট সংরক্ষণ করুন');
      await tester.ensureVisible(save);
      await tester.runAsync(() async {
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'খাবারের নোট সংরক্ষণ করুন'),
            )
            .onPressed!();
        await store.saved;
      });
      await tester.pumpAndSettle();
      expect(find.text('খাবারের নোট সংরক্ষিত হয়েছে।'), findsOneWidget);
      final language = find.text('ভাষা');
      await tester.scrollUntilVisible(
        language,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(language, findsOneWidget);
      await tester.pump();
      await tester.runAsync(() => store.saved);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Bangla data screen translates backup and erase confirmation', (
    tester,
  ) async {
    await openSetup(
      tester,
      language: 'bn',
      screen: (s) => DataScreen(store: s),
    );
    expect(find.text('আপনার তথ্য'), findsOneWidget);
    expect(find.widgetWithText(Cta, 'আমার তথ্য রপ্তানি করুন'), findsOneWidget);
    final erase = find.text('এই ফোনের তথ্য মুছুন');
    await tester.scrollUntilVisible(
      erase,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(erase);
    await tester.pumpAndSettle();
    expect(find.text('এই ফোনের তথ্য মুছবেন?'), findsOneWidget);
    expect(
      find.text(
        'এই ফোনের সব তথ্য ও পুনরুদ্ধারের কপি মুছে যাবে। প্রয়োজন হলে আগে ব্যাকআপ রপ্তানি করুন।',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('damaged draft cannot block setup', (tester) async {
    await openSetup(tester, preferences: {draftKey: '{broken'});
    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
