import 'package:daur/friends.dart';
import 'package:daur/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('leaderboard: this week\'s points rank, last week\'s count for nothing, streak breaks a tie', (
    tester,
  ) async {
    const today = '2026-10-13', week = '2026-10-10'; // a Tuesday; the week began Saturday
    Map<String, dynamic> row(String uid, int points, int streak, {String w = week}) => {
      'uid': uid,
      'name': uid,
      'points': points,
      'week': w,
      'streak': streak,
      'legs': 2,
      'day': today,
    };
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Leaderboard(
              me: 'Rafi',
              today: today,
              rows: [
                row('Mitu', 600, 2),
                row('Rafi', 640, 1),
                row('Old', 2000, 9, w: '2026-10-03'), // last week's points: 0 now
                row('Nila', 600, 7), // ties Mitu on points, longer streak
                row('Joy', 150, 0),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You\'re 1st'), findsOneWidget);
    expect(find.text('Day 4 of 7 · resets Saturday'), findsOneWidget);
    // fourth and fifth below the podium, in order: Joy (150), then Old (0)
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Joy'), findsOneWidget);
    final joy = tester.getTopLeft(find.text('Joy')).dy, old = tester.getTopLeft(find.text('Old')).dy;
    expect(joy < old, isTrue);
    // Nila beats Mitu on the tie: second place is the left block, so Nila sits left of Mitu
    expect(tester.getTopLeft(find.text('Nila')).dx < tester.getTopLeft(find.text('Mitu')).dx, isTrue);
  });

  testWidgets('leaderboard by kg lifted ranks the lifted column and says what it counts', (tester) async {
    const today = '2026-10-13';
    Map<String, dynamic> row(String uid, int points, int lifted) => {
      'uid': uid,
      'name': uid,
      'points': points,
      'lifted': lifted,
      'week': '2026-10-10',
      'streak': 0,
      'day': today,
    };
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Leaderboard(
              me: 'A',
              today: today,
              by: 'lifted',
              rows: [row('A', 900, 1200), row('B', 300, 5400), row('C', 600, 0), row('D', 800, 300)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You\'re 2nd'), findsOneWidget); // B lifted more, though A has more points
    expect(find.text('5,400 kg'), findsOneWidget);
    expect(find.text('kg × reps over every set logged this week'), findsOneWidget);
  });

  testWidgets('steps typed in by hand are marked on the steps board', (tester) async {
    const today = '2026-10-13';
    Map<String, dynamic> row(String uid, int steps, {bool typed = false}) => {
      'uid': uid,
      'name': uid,
      'steps': steps,
      'week': '2026-10-10',
      'streak': 0,
      'day': today,
      if (typed) 'typed': true,
    };
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Leaderboard(
              me: 'A',
              today: today,
              by: 'steps',
              rows: [row('A', 30000), row('B', 41000, typed: true), row('C', 20000), row('D', 9000, typed: true)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('41,000 ✎'), findsOneWidget); // on the podium
    expect(find.text('9,000 ✎'), findsOneWidget); // in the list
    expect(find.text('30,000'), findsOneWidget);
    expect(find.text('✎ some steps typed in by hand, not from Health'), findsOneWidget);
  });
}
