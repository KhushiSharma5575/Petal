import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/theme/petal_palette.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/mood_repository.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';
import 'package:petal/features/me/logic/week_snapshot.dart';
import 'package:petal/features/tasks/state/reminder_sync.dart';

import '../../helpers/test_app.dart';

/// Friday 13 November 2026 (week: Mon 9 - Sun 15).
final today = dateOnly(testNow);
DateTime d(int day) => DateTime(2026, 11, day);

Future<void> openMe(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Me tab'));
  await tester.pumpAndSettle();
}

void main() {
  group('weekSnapshot logic', () {
    const read = Habit(
      id: 1,
      key: 'read',
      name: 'Read',
      type: HabitType.check,
      goal: 1,
    );
    const water = Habit(
      id: 2,
      key: 'water',
      name: 'Water',
      type: HabitType.count,
      goal: 8,
    );

    test('counts tasks done, habit %, spend and picks an insight', () {
      final s = weekSnapshot(
        tasks: [
          TaskItem(
            id: 1,
            title: 'a',
            done: true,
            doneAt: d(10),
            createdAt: d(1),
          ),
          TaskItem(
            id: 2,
            title: 'b',
            done: true,
            doneAt: d(2),
            createdAt: d(1),
          ),
          TaskItem(id: 3, title: 'c', createdAt: d(1)),
        ],
        habits: [
          HabitWithLogs(read, {for (var i = 9; i <= 13; i++) d(i): 1}),
          HabitWithLogs(water, {d(9): 8, d(10): 3}),
        ],
        expenses: [
          Expense(
            id: 1,
            amount: 25000,
            category: ExpenseCategory.food,
            date: d(12),
            createdAt: d(12),
          ),
        ],
        today: today,
      );
      expect(s.tasksDone, 1);
      expect(s.habitsKeptPercent, 60); // (5 + 1) / (2 habits * 5 days)
      expect(s.spent, 25000);
      expect(s.insight, 'Read every day this week. Lovely.');
    });

    test('other insights', () {
      final best = weekSnapshot(
        tasks: const [],
        habits: [
          HabitWithLogs(read, {d(9): 1, d(11): 1}),
        ],
        expenses: const [],
        today: today,
      );
      expect(best.insight, 'Most kept: Read, 2 of 5 days.');
      final empty = weekSnapshot(
        tasks: const [],
        habits: const [],
        expenses: const [],
        today: today,
      );
      expect(empty.insight, 'A fresh week. Small steps count.');
    });
  });

  testWidgets('add your name; header and avatar update', (tester) async {
    final app = await pumpPetal(tester);
    await openMe(tester);
    expect(find.text('Me'), findsWidgets);
    await tester.tap(find.text('Add your name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Khushi');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Khushi'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
    expect(
      await SettingsRepository(app.db).get(SettingKeys.userName),
      'Khushi',
    );
  });

  testWidgets('weekly snapshot shows this week\'s numbers', (tester) async {
    await pumpPetal(
      tester,
      setup: (db) async {
        final tasks = TaskRepository(db, clock: () => testNow);
        final id = await tasks.create(const TaskDraft(title: 'x'));
        await tasks.setDone(id, true);
        await ExpenseRepository(db, clock: () => testNow).add(
          ExpenseDraft(
            amount: 45000,
            category: ExpenseCategory.food,
            date: today,
          ),
        );
      },
    );
    await openMe(tester);
    expect(find.bySemanticsLabel('Tasks done: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Spent: ₹450'), findsOneWidget);
  });

  testWidgets('habit grid: tap a past day to fix a tick', (tester) async {
    final app = await pumpPetal(tester, screen: const Size(412, 1400));
    await openMe(tester);
    final cell = find.bySemanticsLabel('Read on Wednesday, not done');
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Read on Wednesday, done'), findsOneWidget);
    final read = (await HabitRepository(app.db).getHabits(today))
        .firstWhere((h) => h.habit.key == HabitKeys.read);
    expect(read.valueOn(d(11)), 1);

    // Future days can't be ticked.
    expect(find.bySemanticsLabel('Read on Sunday, upcoming'), findsOneWidget);
  });

  testWidgets('edit the weekly plan; Today shows it', (tester) async {
    await pumpPetal(tester, screen: const Size(412, 1600));
    await openMe(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday: No workout')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Workout'),
      'Full body',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Study focus'),
      'Maths',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Full body · Study: Maths'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Today tab'));
    await tester.pumpAndSettle();
    expect(find.text('Full body'), findsOneWidget);
  });

  testWidgets('mood calendar: set a past day', (tester) async {
    final app = await pumpPetal(
      tester,
      screen: const Size(412, 1400),
      setup: (db) => MoodRepository(db).setMood(d(3), Mood.low),
    );
    await openMe(tester);
    await tester.tap(find.text('Mood'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('3 November, felt low'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('10 November, no check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Felt good'));
    await tester.pumpAndSettle();
    expect(await MoodRepository(app.db).getMood(d(10)), Mood.good);
    expect(find.bySemanticsLabel('10 November, felt good'), findsOneWidget);

    // Future days aren't tappable; can't go past this month.
    expect(find.bySemanticsLabel('20 November'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('theme switch re-themes the app and is saved', (tester) async {
    final app = await pumpPetal(tester, screen: const Size(412, 1800));
    await openMe(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Mint theme'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.text('Settings').first));
    expect(theme.extension<PetalPalette>()!.deep, PetalPalette.mint.deep);
    expect(
      await SettingsRepository(app.db).get(SettingKeys.themeAccent),
      'mint',
    );
  });

  testWidgets('water goal change shows on Today; water reminders schedule', (
    tester,
  ) async {
    final app = await pumpPetal(tester, screen: const Size(412, 2800));
    await openMe(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Water').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('10 glasses · 3.8 L'), findsOneWidget);

    await tester.tap(find.text('Water reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 3 hours'));
    await tester.pumpAndSettle();
    expect(app.reminders.daily.values.map((t) => t.$1).toList()..sort(), [
      9,
      12,
      15,
      18,
      21,
    ]);
    expect(
      app.reminders.daily.keys.every((id) => id >= waterReminderIdBase),
      isTrue,
    );

    await tester.tap(find.bySemanticsLabel('Today tab'));
    await tester.pumpAndSettle();
    expect(find.text('0/10'), findsOneWidget);
  });

  testWidgets('task reminder sync leaves water reminders alone', (
    tester,
  ) async {
    final app = await pumpPetal(
      tester,
      setup: (db) =>
          SettingsRepository(db).set(SettingKeys.waterReminderHours, '4'),
    );
    expect(app.reminders.daily, hasLength(4)); // 9, 13, 17, 21
    // Adding a task with a reminder triggers a task sync.
    await TaskRepository(app.db, clock: () => testNow).create(
      TaskDraft(
        title: 'Call',
        dueDate: today,
        dueTime: const ClockTime(18, 0),
        reminder: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(app.reminders.scheduled, hasLength(1));
    expect(app.reminders.daily, hasLength(4));
  });

  testWidgets('back up everything writes JSON to Downloads', (tester) async {
    final app = await pumpPetal(
      tester,
      screen: const Size(412, 2200),
      setup: (db) => TaskRepository(
        db,
        clock: () => testNow,
      ).create(const TaskDraft(title: 'Keep me')),
    );
    await openMe(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back up everything'));
    await tester.pumpAndSettle();
    expect(app.files.savedName, 'petal-backup-2026-11-13.json');
    final json = jsonDecode(utf8.decode(app.files.savedBytes!)) as Map;
    expect(json['app'], 'Petal');
    expect((json['tables'] as Map)['tasks'].single['title'], 'Keep me');
    expect((json['tables'] as Map)['habits'], hasLength(5));
    expect(
      find.text('Saved to Downloads/petal-backup-2026-11-13.json'),
      findsOneWidget,
    );
  });

  testWidgets('no overflow on a small phone with 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPetal(tester, screen: const Size(360, 740));
    await openMe(tester);
    for (final section in ['Habits', 'Mood', 'Settings']) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(section).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: section);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: section);
    }
  });
}
