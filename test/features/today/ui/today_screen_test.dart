import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/shell/nav_state.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/core/widgets/confetti.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';
import 'package:petal/features/habits/ui/water_card.dart';

import '../../../helpers/test_app.dart';

/// Today in tests: Friday 13 November 2026, 10:00.
final today = dateOnly(testNow);

Future<Map<String, Habit>> habitsByKey(AppDatabase db) async => {
  for (final h in await HabitRepository(db).getHabits(today))
    h.habit.key: h.habit,
};

void main() {
  testWidgets('fresh start: ring 0/5, mood prompt, empty water, no tasks', (
    tester,
  ) async {
    await pumpPetal(tester);
    expect(find.text('Good morning!'), findsOneWidget);
    expect(find.text('Friday, 13 November'), findsOneWidget);
    expect(find.bySemanticsLabel('0 of 5 habits done today'), findsOneWidget);
    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(find.text('0/8'), findsOneWidget);
    expect(
      find.text('Nothing due today. Enjoy it, or add something below.'),
      findsOneWidget,
    );
    for (final name in ['Workout', 'Study', 'Meditate', 'Read']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('mood check-in collapses to one line, and can be changed', (
    tester,
  ) async {
    await pumpPetal(tester);
    await tester.tap(find.bySemanticsLabel('Feeling good'));
    await tester.pumpAndSettle();
    expect(find.text('Feeling good'), findsOneWidget);
    expect(find.text('How are you feeling?'), findsNothing);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Feeling great'));
    await tester.pumpAndSettle();
    expect(find.text('Feeling great'), findsOneWidget);
  });

  testWidgets(
    'tapping glasses fills water; tapping the last one again undoes',
    (tester) async {
      await pumpPetal(tester);
      final glasses = find.descendant(
        of: find.byType(WaterCard),
        matching: find.byType(InkResponse),
      );
      await tester.tap(glasses.at(2));
      await tester.pumpAndSettle();
      expect(find.text('3/8'), findsOneWidget);
      expect(find.text('1.1 L of 3 L'), findsOneWidget);

      await tester.tap(glasses.at(2));
      await tester.pumpAndSettle();
      expect(find.text('2/8'), findsOneWidget);
    },
  );

  testWidgets('study +30 and ticking a habit update the ring', (tester) async {
    // With "earn your streaks" off, Study has the quick +30 button.
    await pumpPetal(
      tester,
      setup: (db) =>
          SettingsRepository(db).set(SettingKeys.earnStreaks, 'false'),
    );
    await tester.tap(find.bySemanticsLabel('Add 30 minutes of study'));
    await tester.pumpAndSettle();
    expect(find.textContaining('30 / 120 min'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Meditate'));
    await tester.pumpAndSettle();
    expect(find.text('Done today'), findsOneWidget);
    expect(find.bySemanticsLabel('1 of 5 habits done today'), findsOneWidget);
  });

  testWidgets('streaks and today\'s planned workout are shown', (tester) async {
    await pumpPetal(
      tester,
      setup: (db) async {
        final repo = HabitRepository(db);
        final read = (await habitsByKey(db))[HabitKeys.read]!;
        for (var i = 1; i <= 3; i++) {
          await repo.setValue(read.id, addDays(today, -i), 1);
        }
        await repo.setPlan(
          const PlanDay(weekday: DateTime.friday, workout: 'Full body'),
        );
      },
    );
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('Full body'), findsOneWidget);
  });

  testWidgets('finishing the last habit celebrates once, with confetti', (
    tester,
  ) async {
    await pumpPetal(
      tester,
      setup: (db) async {
        final repo = HabitRepository(db);
        final h = await habitsByKey(db);
        await repo.setValue(h[HabitKeys.water]!.id, today, 8);
        await repo.setValue(h[HabitKeys.workout]!.id, today, 1);
        await repo.setValue(h[HabitKeys.study]!.id, today, 120);
        await repo.setValue(h[HabitKeys.meditate]!.id, today, 1);
      },
    );
    // Opening the screen with 4/5 done: no celebration yet.
    expect(find.text('All habits done today!'), findsNothing);
    expect(find.byType(ConfettiBurst), findsNothing);

    await tester.tap(find.bySemanticsLabel('Read'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('All habits done today!'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing); // played once, gone
    expect(find.text('All habits done today!'), findsOneWidget); // stays
  });

  testWidgets('no confetti drawn when "Remove animations" is on', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpPetal(
      tester,
      setup: (db) async {
        final repo = HabitRepository(db);
        final h = await habitsByKey(db);
        for (final key in [HabitKeys.water, HabitKeys.study]) {
          await repo.setValue(h[key]!.id, today, h[key]!.goal);
        }
        await repo.setValue(h[HabitKeys.workout]!.id, today, 1);
        await repo.setValue(h[HabitKeys.meditate]!.id, today, 1);
      },
    );
    await tester.tap(find.bySemanticsLabel('Read'));
    await tester.pump();
    expect(find.text('All habits done today!'), findsOneWidget);
    expect(
      find.byType(CustomPaint).evaluate().where((e) {
        final p = (e.widget as CustomPaint).painter;
        return p != null && p.runtimeType.toString() == '_ConfettiPainter';
      }),
      isEmpty,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('today\'s tasks: max 5, overdue first, See all opens Tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1800) * 2.625;
    await pumpPetal(
      tester,
      screen: const Size(412, 1800),
      setup: (db) async {
        final repo = TaskRepository(db, clock: () => testNow);
        await repo.create(
          TaskDraft(title: 'Late one', dueDate: addDays(today, -2)),
        );
        for (var i = 1; i <= 6; i++) {
          await repo.create(TaskDraft(title: 'Task $i', dueDate: today));
        }
        await repo.create(
          TaskDraft(title: 'Tomorrow thing', dueDate: addDays(today, 1)),
        );
      },
    );

    expect(find.text('Late one'), findsOneWidget);
    expect(find.textContaining('Overdue ·'), findsOneWidget);
    expect(find.text('Task 4'), findsOneWidget);
    expect(find.text('Task 5'), findsNothing); // only 5 shown
    expect(find.text('+2 more in Tasks'), findsOneWidget);
    expect(find.text('Tomorrow thing'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Mark done: Task 1'));
    await tester.pumpAndSettle();
    expect(find.text('6 to do · 1 done'), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('My tasks'), findsOneWidget);
  });

  testWidgets('"Add a task" pre-fills today', (tester) async {
    final app = await pumpPetal(tester, screen: const Size(412, 1600));
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Call mom');
    await tester.pump(); // let the Add button enable before tapping it
    await tester.ensureVisible(find.text('Add task'));
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    expect(find.text('Call mom'), findsOneWidget);
    final saved = await TaskRepository(app.db).getAll();
    expect(saved.single.dueDate, today);
  });

  testWidgets('Spent today opens Money', (tester) async {
    await pumpPetal(tester);
    await tester.tap(find.text('Spent today'));
    await tester.pumpAndSettle();
    expect(find.text('No spends yet'), findsOneWidget);
    expect(AppTab.money.label, 'Money');
  });

  testWidgets('no overflow on a small phone with 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPetal(tester, screen: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
