import 'package:daur/coaching.dart';
import 'package:daur/friends.dart';
import 'package:daur/l10n.dart';
import 'package:daur/students.dart';
import 'package:daur/spending.dart';
import 'package:daur/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daur/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bangla invitation labels preserve raw invitation code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        supportedLocales: const [Locale('en'), Locale('bn')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: InviteCard(
            role: 'trainer',
            icon: Icons.fitness_center,
            sees: 'All that, plus gym and strength',
            code: 'ABCD2345',
            busy: false,
            onMake: () {},
            onRevoke: () {},
          ),
        ),
      ),
    );
    expect(find.text('প্রশিক্ষক'), findsOneWidget);
    expect(find.text('এসবের পাশাপাশি জিম ও শক্তির অগ্রগতি'), findsOneWidget);
    expect(find.text('ABCD2345'), findsOneWidget);
    expect(find.byTooltip('কপি'), findsOneWidget);
  });

  testWidgets('Bangla leaderboard localizes ranking and explanation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        supportedLocales: const [Locale('en'), Locale('bn')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Leaderboard(
              rows: [
                {
                  'uid': 'rafi',
                  'name': 'Rafi',
                  'points': 10,
                  'streak': 1,
                  'week': '2026-10-10',
                  'day': '2026-10-13',
                },
              ],
              me: 'rafi',
              today: '2026-10-13',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('আপনার অবস্থান: 1'), findsOneWidget);
    expect(find.text('৭ দিনের মধ্যে 4 দিন · শনিবার নতুন শুরু'), findsOneWidget);
    expect(find.text('আপনি'), findsOneWidget);
  });

  test(
    'student flags and placeholders localize without changing default API',
    () {
      final date = DateTime(2026, 10, 18);
      expect(studentFlags({}, null, date), contains('Never opened Daur'));
      expect(studentFlags({}, null, date, 'bn'), contains('কখনও Daur খোলেননি'));
      expect(
        trLanguage('bn', 'Remove {name}?', {'name': 'Rafi'}),
        'Rafi-কে সরাবেন?',
      );
    },
  );
  testWidgets('Bangla spending keeps category IDs and user notes unchanged', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.load();
    store.addExpense(
      Expense(dayKey(DateTime.now()), 500, 'food', 'Weekly rice'),
    );
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        supportedLocales: const [Locale('en'), Locale('bn')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        home: SpendingScreen(store: store),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('বাজার'), findsOneWidget);
    expect(find.text('Weekly rice'), findsOneWidget);
    expect(find.text('খরচ যোগ করুন'), findsOneWidget);
    expect(store.expenses.single.cat, 'food');
  });
}
