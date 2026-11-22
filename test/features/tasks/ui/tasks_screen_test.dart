import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/task_repository.dart';

import '../../../helpers/test_app.dart';

/// Today in tests is Friday 13 November 2026.
Future<void> seed(AppDatabase db) async {
  final repo = TaskRepository(db, clock: () => testNow);
  await repo.create(
    TaskDraft(
      title: 'Pay bill',
      dueDate: DateTime(2026, 11, 11),
      list: TaskList.personal,
    ),
  );
  await repo.create(
    TaskDraft(
      title: 'Client report',
      dueDate: DateTime(2026, 11, 13),
      dueTime: const ClockTime(17, 0),
      priority: TaskPriority.high,
      list: TaskList.work,
      reminder: true,
    ),
  );
  await repo.create(
    TaskDraft(
      title: 'Buy milk',
      dueDate: DateTime(2026, 11, 14),
      list: TaskList.shopping,
      subtasks: const [
        SubtaskDraft(text: 'Milk', done: true),
        SubtaskDraft(text: 'Bread'),
      ],
    ),
  );
  await repo.create(const TaskDraft(title: 'Someday idea'));
}

Future<void> openTasks(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Tasks tab'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state when there are no tasks', (tester) async {
    await pumpPetal(tester);
    await openTasks(tester);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('shows groups in order with task details', (tester) async {
    // Tall screen so every group is on screen at once. Narrow (360 dp) to
    // catch overflow on small phones.
    await pumpPetal(tester, setup: seed, screen: const Size(360, 1600));
    await openTasks(tester);

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('OVERDUE · 1'), lessThan(y('TODAY · 1')));
    expect(y('TODAY · 1'), lessThan(y('TOMORROW · 1')));
    expect(y('TOMORROW · 1'), lessThan(y('NO DATE · 1')));

    expect(find.text('Today, 5 pm'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('1/2 subtasks'), findsOneWidget);
    expect(find.text('Move all to today'), findsOneWidget);
  });

  testWidgets('add a task through the sheet', (tester) async {
    final app = await pumpPetal(tester);
    await openTasks(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Water the plants');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pump();
    await tester.tap(find.text('Study'));
    await tester.pump();
    await tester.ensureVisible(find.text('Add task'));
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Water the plants'), findsOneWidget);
    expect(find.text('TOMORROW · 1'), findsOneWidget);
    final saved = await TaskRepository(app.db).getAll();
    expect(saved.single.list, TaskList.study);
    expect(saved.single.dueDate, DateTime(2026, 11, 14));
  });

  testWidgets('ticking a task moves it to the folded Completed group', (
    tester,
  ) async {
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    await tester.tap(find.bySemanticsLabel('Mark done: Client report'));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETED · 1'), findsOneWidget);
    expect(find.text('Client report'), findsNothing); // Completed is folded

    await tester.tap(find.text('COMPLETED · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Client report'), findsOneWidget);
  });

  testWidgets('delete from the detail sheet, then undo', (tester) async {
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    await tester.tap(find.text('Someday idea'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Delete task'));
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    expect(find.text('Someday idea'), findsNothing);
    expect(find.text('Deleted "Someday idea"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Someday idea'), findsOneWidget);
  });

  testWidgets('edit a task and add a subtask', (tester) async {
    final app = await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    await tester.tap(find.text('Someday idea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Plan trip');
    final subField = find.widgetWithText(TextField, 'Add a subtask');
    await tester.ensureVisible(subField);
    await tester.enterText(subField, 'Pick dates');
    await tester.ensureVisible(find.byTooltip('Add subtask'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add subtask'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Plan trip'), findsOneWidget);
    expect(find.text('0/1 subtasks'), findsOneWidget);
    final t = (await TaskRepository(
      app.db,
    ).getAll()).firstWhere((t) => t.title == 'Plan trip');
    expect(t.subtasks.single.text, 'Pick dates');
  });

  testWidgets('back on an edited task asks before discarding', (tester) async {
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    await tester.tap(find.text('Someday idea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.pump(); // let the sheet rebuild before pressing back
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsNothing);
    expect(find.text('Someday idea'), findsOneWidget);
  });

  testWidgets('move all overdue to today, then undo', (tester) async {
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    await tester.tap(find.text('Move all to today'));
    await tester.pumpAndSettle();
    expect(find.text('OVERDUE · 1'), findsNothing);
    expect(find.text('TODAY · 2'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('OVERDUE · 1'), findsOneWidget);
  });

  testWidgets('list filter and week strip', (tester) async {
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);

    // Filter to Shopping.
    await tester.tap(find.text('All lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping').last);
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Client report'), findsNothing);

    // Back to all, then pick Friday 13 in the week strip.
    await tester.tap(find.text('Shopping').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All lists').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 13 November')));
    await tester.pumpAndSettle();
    expect(find.text('Client report'), findsOneWidget);
    expect(find.text('Buy milk'), findsNothing);
    expect(find.text('Showing Today'), findsOneWidget);

    // Tap the same day again to show everything.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 13 November')));
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('reminders are scheduled for tasks with Remind me on', (
    tester,
  ) async {
    final app = await pumpPetal(tester, setup: seed);
    // Client report: today 5 pm, reminder on -> 4:45 pm.
    expect(
      app.reminders.scheduled.values.single.when,
      DateTime(2026, 11, 13, 16, 45),
    );

    await openTasks(tester);
    await tester.tap(find.bySemanticsLabel('Mark done: Client report'));
    await tester.pumpAndSettle();
    expect(app.reminders.scheduled, isEmpty);
  });

  testWidgets('selected chips have readable (white) labels', (tester) async {
    await pumpPetal(tester);
    await openTasks(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // "No date" and "Personal" are selected by default.
    for (final label in ['No date', 'Personal']) {
      final style = DefaultTextStyle.of(tester.element(find.text(label))).style;
      final chipColor = tester.widget<Text>(find.text(label)).style?.color;
      expect(chipColor ?? style.color, Colors.white, reason: label);
    }
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Work'))
          .selected,
      isFalse,
    );
  });

  testWidgets('no overflow with 2x font size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPetal(tester, setup: seed);
    await openTasks(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
