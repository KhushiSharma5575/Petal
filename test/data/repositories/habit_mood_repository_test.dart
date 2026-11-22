import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/mood_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  final today = DateTime(2026, 11, 13);

  group('HabitRepository', () {
    late AppDatabase db;
    late HabitRepository repo;
    setUp(() {
      db = newTestDatabase();
      repo = HabitRepository(db);
    });
    tearDown(() => db.close());

    test('a new database has the five default habits in order', () async {
      final habits = await repo.getHabits(today);
      expect(habits.map((h) => h.habit.key), [
        'water',
        'workout',
        'study',
        'meditate',
        'read',
      ]);
      final water = habits.first.habit;
      expect(water.type, HabitType.count);
      expect(water.goal, 8);
      expect(habits[2].habit.goal, 120);
    });

    test('setValue, addValue and clearing with 0', () async {
      final study = (await repo.getHabits(today))[2].habit;
      await repo.setValue(study.id, today, 30);
      await repo.addValue(study.id, today, 30);
      expect(await repo.getValue(study.id, today), 60);

      final h = (await repo.getHabits(today))[2];
      expect(h.valueOn(today), 60);

      await repo.setValue(study.id, today, 0);
      expect(await repo.getValue(study.id, today), 0);
    });

    test('weekly plan defaults to empty and can be saved', () async {
      expect((await repo.watchPlanFor(1).first).workout, '');
      await repo.setPlan(const PlanDay(weekday: 1, workout: 'Legs'));
      expect((await repo.watchPlanFor(1).first).workout, 'Legs');
    });
  });

  // Regression: both repositories once used the same "SELECT 1" trigger
  // query, and drift shared it, so the habits stream silently watched the
  // tasks tables instead.
  test('task and habit streams each react to their own tables', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final tasks = TaskRepository(db);
    final habits = HabitRepository(db);

    var taskEmits = 0, habitEmits = 0;
    final s1 = tasks.watchAll().listen((_) => taskEmits++);
    final s2 = habits.watchHabits(today).listen((_) => habitEmits++);
    addTearDown(s1.cancel);
    addTearDown(s2.cancel);
    await pumpEventQueue();
    expect((taskEmits, habitEmits), (1, 1));

    final water = (await habits.getHabits(today)).first.habit;
    await habits.setValue(water.id, today, 3);
    await pumpEventQueue();
    expect(habitEmits, 2);

    await tasks.create(const TaskDraft(title: 'x'));
    await pumpEventQueue(times: 50);
    expect(taskEmits, 2);
  });

  group('MoodRepository', () {
    late AppDatabase db;
    late MoodRepository repo;
    setUp(() {
      db = newTestDatabase();
      repo = MoodRepository(db);
    });
    tearDown(() => db.close());

    test('set, replace, read range and clear', () async {
      await repo.setMood(today, Mood.good);
      await repo.setMood(today, Mood.great);
      await repo.setMood(DateTime(2026, 11, 2), Mood.low);
      expect(await repo.watchMood(today).first, Mood.great);
      expect(
        await repo.moodsBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        {today: Mood.great, DateTime(2026, 11, 2): Mood.low},
      );
      await repo.setMood(today, null);
      expect(await repo.watchMood(today).first, isNull);
    });
  });

  test('upgrading a version-1 database keeps tasks and adds habits', () async {
    // Recreate the exact version-1 schema (Phase 2) with one task in it.
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE tasks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '',
            due_date TEXT NULL, due_time INTEGER NULL,
            priority TEXT NOT NULL DEFAULT 'medium',
            list TEXT NOT NULL DEFAULT 'personal',
            reminder INTEGER NOT NULL DEFAULT 0 CHECK (reminder IN (0, 1)),
            done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)),
            done_at INTEGER NULL, created_at INTEGER NOT NULL,
            repeat_rule TEXT NULL)''');
        raw.execute('''
          CREATE TABLE subtasks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
            text TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)),
            sort_order INTEGER NOT NULL DEFAULT 0)''');
        raw.execute(
          'CREATE TABLE settings (key TEXT NOT NULL, '
          'value TEXT NOT NULL, PRIMARY KEY (key))',
        );
        raw.execute("INSERT INTO tasks (title, created_at) VALUES ('Kept', 0)");
        raw.execute('PRAGMA user_version = 1');
      },
    );
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    addTearDown(db.close);

    final tasks = await TaskRepository(db).getAll();
    expect(tasks.single.title, 'Kept');
    final habits = await HabitRepository(db).getHabits(today);
    expect(habits, hasLength(5));
    await MoodRepository(db).setMood(today, Mood.okay); // new table works
  });
}
