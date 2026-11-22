import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/features/habits/logic/earn_logic.dart';

import '../../helpers/test_app.dart';

void main() {
  group('rules', () {
    test('a walk needs the step target; a gym session 20 min + 300 steps', () {
      bool earned(int steps, int mins, {bool hasSteps = true}) => workoutEarned(
        steps: steps,
        elapsed: Duration(minutes: mins),
        stepTarget: 1000,
        hasSteps: hasSteps,
      );
      expect(earned(1000, 5), isTrue);
      expect(earned(999, 5), isFalse);
      expect(earned(300, 20), isTrue);
      expect(earned(299, 25), isFalse);
      expect(earned(0, 20, hasSteps: false), isTrue);
      expect(earned(0, 19, hasSteps: false), isFalse);
    });

    test('a session survives a restart, and a phone reboot', () {
      final s = WorkoutSession(DateTime(2026, 11, 13, 7), 5000);
      final back = WorkoutSession.decode(s.encode())!;
      expect(back.start, s.start);
      expect(back.stepsAt(5600), 600);
      expect(back.stepsAt(120), 120); // phone restarted: counter from 0
      expect(WorkoutSession.decode(''), isNull);
      expect(WorkoutSession(s.start, null).stepsAt(9000), 0);
    });

    test('focus time only counts while face down', () {
      final c = FocusClock();
      final t = DateTime(2026, 11, 13, 9);
      c.setFaceDown(true, t);
      c.setFaceDown(false, t.add(const Duration(minutes: 10)));
      expect(c.focusedAt(t.add(const Duration(minutes: 30))).inMinutes, 10);
      c.setFaceDown(true, t.add(const Duration(minutes: 30)));
      expect(c.focusedAt(t.add(const Duration(minutes: 35))).inMinutes, 15);
      expect(clockText(const Duration(minutes: 24, seconds: 5)), '24:05');
    });
  });

  testWidgets('workout streak is earned with steps', (tester) async {
    final app = await pumpPetal(tester);
    await tester.tap(find.bySemanticsLabel('Start a workout session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    app.device.stepsController.add(5000); // first reading = start
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Finish'), findsOneWidget);
    app.device.stepsController.add(6100);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1100'), findsOneWidget);
    await tester.tap(find.text('Finish and earn streak'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final workout = (await HabitRepository(app.db).getHabits(dateOnly(testNow)))
        .firstWhere((h) => h.habit.key == HabitKeys.workout);
    expect(workout.valueOn(dateOnly(testNow)), 1);
    expect(
      await SettingsRepository(app.db).get(SettingKeys.workoutSession),
      '',
    );
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });

  testWidgets('focus timer adds minutes to Study only while face down', (
    tester,
  ) async {
    var now = testNow;
    final app = await pumpPetal(tester, clock: () => now);
    await tester.tap(find.bySemanticsLabel('Start a focus timer for Study'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start').last);
    await tester.pump();
    expect(find.textContaining('Paused'), findsOneWidget);
    expect(app.device.screenKeptOn, isTrue);

    app.device.faceDownController.add(true);
    await tester.pump();
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Focusing'), findsOneWidget);

    app.device.faceDownController.add(false); // picked up: paused
    await tester.pump();
    now = now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('15:00'), findsOneWidget); // 10 of 25 done

    app.device.faceDownController.add(true);
    await tester.pump();
    now = now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Well done!'), findsOneWidget);
    expect(app.device.screenKeptOn, isFalse);
    final study = (await HabitRepository(app.db).getHabits(dateOnly(testNow)))
        .firstWhere((h) => h.habit.key == HabitKeys.study);
    expect(study.valueOn(dateOnly(testNow)), 25);
  });

  testWidgets('add a habit of your own', (tester) async {
    final app = await pumpPetal(tester, screen: const Size(412, 1400));
    await tester.tap(find.text('Add a habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skincare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add habit'));
    await tester.pumpAndSettle();
    expect(find.text('Skincare'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Skincare'));
    await tester.pumpAndSettle();
    final skincare = (await HabitRepository(app.db).getHabits(
      dateOnly(testNow),
    )).firstWhere((h) => h.habit.name == 'Skincare');
    expect(skincare.valueOn(dateOnly(testNow)), 1);
  });
}
