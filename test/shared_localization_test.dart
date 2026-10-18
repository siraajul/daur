import 'package:daur/l10n.dart';
import 'package:daur/theme.dart';
import 'package:daur/visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'service messages use named placeholders without changing technical detail',
    () {
      expect(
        trLanguage('bn', 'Last backed up at {time}', {
          'time': '2026-10-18 12:00',
        }),
        'সর্বশেষ ব্যাকআপ: 2026-10-18 12:00',
      );
      expect(
        trLanguage('bn', 'Sync failed: {error}', {
          'error': 'permission-denied',
        }),
        'তথ্য মিলিয়ে নেওয়া ব্যর্থ: permission-denied',
      );
      expect(
        trLanguage('en', 'Sync failed: {error}', {'error': 'offline'}),
        'Sync failed: offline',
      );
    },
  );
  testWidgets(
    'shared Bangla controls and confirmation fit narrow large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bn'),
          supportedLocales: const [Locale('en'), Locale('bn')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  const PageHeader('Your data'),
                  GoogleButton(
                    onPressed: () => confirmPop(
                      context,
                      'Your data',
                      'Recovered your previous saved copy. Your damaged copy is retained on this phone.',
                      'Save',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(trLanguage('bn', 'Continue with Google')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(GoogleButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.text(trLanguage('bn', 'Cancel'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );
}
