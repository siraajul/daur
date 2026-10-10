import 'package:daur/store.dart';
import 'package:daur/theme.dart';
import 'package:daur/workout_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the trainer adds an exercise, edits one, and the send button counts the changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = await Store.load();
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: WorkoutEditor(owner: 'owner', ownerName: 'Siraj Islam', initial: workoutFrom(s.workout)),
      ),
    );
    expect(find.text('No changes yet'), findsOneWidget);

    await tester.tap(find.text('Exercise on Push day'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dips');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Dips'), findsOneWidget);
    expect(find.text('Send to Siraj'), findsOneWidget);
    expect(find.text('1 change'), findsOneWidget);

    // a name already in the workout is refused
    await tester.tap(find.text('Exercise on Push day'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dips');
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.text('dips is already in the workout'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // one more set on the first push exercise
    final first = s.exercisesOn('Push').first;
    await tester.tap(find.text(first));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More sets'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 changes'), findsOneWidget);
  });
}
