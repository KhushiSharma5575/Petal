import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/backup_repository.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/mood_repository.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9, 0);
  final today = DateTime(2026, 11, 16);

  Future<AppDatabase> filledDb() async {
    final db = newTestDatabase();
    final tasks = TaskRepository(db, clock: () => now);
    final id = await tasks.create(
      TaskDraft(
        title: 'Call plumber',
        dueDate: today,
        dueTime: const ClockTime(10, 0),
        subtasks: const [SubtaskDraft(text: 'Find number', done: true)],
      ),
    );
    await tasks.setDone(id, true);
    await ExpenseRepository(db, clock: () => now).add(
      ExpenseDraft(
        amount: 25050,
        category: ExpenseCategory.food,
        note: 'Lunch',
        date: today,
      ),
    );
    await ExpenseRepository(db).setBudget(ExpenseCategory.food, 500000);
    await MoodRepository(db).setMood(today, Mood.great);
    final water = (await HabitRepository(db).getHabits(today)).first.habit;
    await HabitRepository(db).setValue(water.id, today, 6);
    await HabitRepository(db).setGoal('water', 10);
    await SettingsRepository(db).set(SettingKeys.userName, 'Khushi');
    return db;
  }

  test(
    'backup then restore into a fresh database gives everything back',
    () async {
      final source = await filledDb();
      addTearDown(source.close);
      final bytes = await BackupRepository(
        source,
        clock: () => now,
      ).buildJson();

      final target = newTestDatabase();
      addTearDown(target.close);
      // Something already there gets replaced, not merged.
      await TaskRepository(
        target,
        clock: () => now,
      ).create(const TaskDraft(title: 'Old'));

      final summary = await BackupRepository(target).restore(bytes);
      expect(summary.tasks, 1);
      expect(summary.expenses, 1);
      expect(summary.moods, 1);
      expect(summary.createdAt, now);

      final task = (await TaskRepository(target).getAll()).single;
      expect(task.title, 'Call plumber');
      expect(task.done, isTrue);
      expect(task.doneAt, now);
      expect(task.dueTime, const ClockTime(10, 0));
      expect(task.subtasks.single.text, 'Find number');

      final spend = (await ExpenseRepository(target).getAll()).single;
      expect(spend.amount, 25050);
      expect(spend.note, 'Lunch');
      expect(await ExpenseRepository(target).getBudgets(), {
        ExpenseCategory.food: 500000,
      });
      expect(await MoodRepository(target).getMood(today), Mood.great);

      final water = (await HabitRepository(target).getHabits(today)).first;
      expect(water.habit.goal, 10);
      expect(water.valueOn(today), 6);
      expect(
        await SettingsRepository(target).get(SettingKeys.userName),
        'Khushi',
      );
    },
  );

  test('a file that is not a backup changes nothing', () async {
    final db = await filledDb();
    addTearDown(db.close);
    final repo = BackupRepository(db);

    for (final bad in [
      utf8.encode('hello'),
      utf8.encode('{"app": "Other", "tables": {}}'),
      utf8.encode(
        '{"app": "Petal", "formatVersion": 1, "tables": {"tasks": [{"nope": 1}]}}',
      ),
    ]) {
      await expectLater(
        repo.restore(bad),
        throwsA(isA<BackupFormatException>()),
      );
    }
    expect((await TaskRepository(db).getAll()).single.title, 'Call plumber');
  });

  test('a backup from a newer Petal is refused', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final newer = utf8.encode(
      '{"app": "Petal", "formatVersion": 1, "schemaVersion": 99, "tables": {}}',
    );
    await expectLater(
      BackupRepository(db).restore(newer),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });
}
