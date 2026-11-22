import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/backup_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_db.dart';

final today = dateOnly(testNow);

Future<int> waterToday(TestApp app) async =>
    (await HabitRepository(app.db).getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.water)
        .valueOn(today);

void main() {
  testWidgets('widget gets today\'s open tasks (max 3) and water', (
    tester,
  ) async {
    final app = await pumpPetal(
      tester,
      screen: const Size(412, 1800), // so today's tasks are on screen
      setup: (db) async {
        final repo = TaskRepository(db, clock: () => testNow);
        await repo.create(
          TaskDraft(title: 'Late', dueDate: addDays(today, -1)),
        );
        for (final t in ['A', 'B', 'C']) {
          await repo.create(TaskDraft(title: t, dueDate: today));
        }
        await repo.create(
          TaskDraft(title: 'Later', dueDate: addDays(today, 3)),
        );
      },
    );
    final data = app.widget.last!;
    expect(data.date, today);
    expect(data.tasks, ['Late', 'A', 'B']); // overdue first, 3 max
    expect(data.openCount, 4);
    expect(data.water, 0);
    expect(data.waterGoal, 8);

    // Ticking a task and a glass in the app updates the widget.
    await tester.tap(find.bySemanticsLabel('Mark done: Late'));
    await tester.pumpAndSettle();
    expect(app.widget.last!.openCount, 3);
    expect(app.widget.last!.tasks, ['A', 'B', 'C']);
  });

  testWidgets('"+ glass" taps on the widget are added on start', (
    tester,
  ) async {
    final app = await pumpPetal(tester, widgetGlasses: 2);
    await tester.pumpAndSettle();
    expect(await waterToday(app), 2);
    expect(find.text('2/8'), findsOneWidget);
    expect(app.widget.last!.water, 2);
  });

  testWidgets('glasses tapped just before midnight count for that day', (
    tester,
  ) async {
    final yesterday = today.subtract(const Duration(days: 1));
    final app = await pumpPetal(
      tester,
      widgetGlasses: 1,
      widgetGlassesDay: yesterday,
    );
    await tester.pumpAndSettle();
    expect(await waterToday(app), 0);
    final water = (await HabitRepository(app.db).getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.water);
    expect(water.valueOn(yesterday), 1);
  });

  testWidgets('taps on two different days are both kept', (tester) async {
    final yesterday = today.subtract(const Duration(days: 1));
    final app = await pumpPetal(
      tester,
      widgetGlasses: 1,
      widgetOlderGlasses: [(day: yesterday, glasses: 2)],
    );
    await tester.pumpAndSettle();
    expect(await waterToday(app), 1);
    final water = (await HabitRepository(app.db).getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.water);
    expect(water.valueOn(yesterday), 2);
  });

  testWidgets('widget glasses never push water past the goal', (tester) async {
    final app = await pumpPetal(
      tester,
      widgetGlasses: 5,
      setup: (db) async {
        final water = (await HabitRepository(db).getHabits(today)).first.habit;
        await HabitRepository(db).setValue(water.id, today, 6);
      },
    );
    await tester.pumpAndSettle();
    expect(await waterToday(app), 8);
  });

  testWidgets('restore from Settings replaces data after confirming', (
    tester,
  ) async {
    // Make a backup elsewhere.
    final other = newTestDatabase();
    addTearDown(other.close);
    await TaskRepository(
      other,
      clock: () => testNow,
    ).create(const TaskDraft(title: 'From backup'));
    final backup = await BackupRepository(
      other,
      clock: () => testNow,
    ).buildJson();

    final app = await pumpPetal(
      tester,
      screen: const Size(412, 2400),
      setup: (db) => TaskRepository(
        db,
        clock: () => testNow,
      ).create(const TaskDraft(title: 'Current')),
    );
    app.files.fileToPick = backup;

    await tester.tap(find.bySemanticsLabel('Me tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    expect(find.text('Restore from a backup?'), findsOneWidget);
    await tester.tap(find.text('Choose backup file'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Restored from 2026-11-13: 1 tasks'),
      findsOneWidget,
    );
    final titles = (await TaskRepository(app.db).getAll()).map((t) => t.title);
    expect(titles, ['From backup']);
  });

  testWidgets('restore: cancelling the dialog or picker changes nothing', (
    tester,
  ) async {
    final app = await pumpPetal(
      tester,
      screen: const Size(412, 2400),
      setup: (db) => TaskRepository(
        db,
        clock: () => testNow,
      ).create(const TaskDraft(title: 'Current')),
    );
    await tester.tap(find.bySemanticsLabel('Me tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Picker cancelled (fileToPick stays null).
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose backup file'));
    await tester.pumpAndSettle();

    expect((await TaskRepository(app.db).getAll()).single.title, 'Current');
  });
}
