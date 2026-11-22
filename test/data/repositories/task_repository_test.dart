import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/data/repositories/task_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  final now = DateTime(2026, 11, 13, 9, 30);

  setUp(() {
    db = newTestDatabase();
    repo = TaskRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  final draft = TaskDraft(
    title: '  Call the plumber  ',
    dueDate: DateTime(2026, 11, 14),
    dueTime: const ClockTime(10, 0),
    priority: TaskPriority.high,
    list: TaskList.personal,
    reminder: true,
    subtasks: const [
      SubtaskDraft(text: 'Find number'),
      SubtaskDraft(text: 'Book slot', done: true),
      SubtaskDraft(text: '   '), // blank subtasks are dropped
    ],
  );

  test('create then read back every field', () async {
    final id = await repo.create(draft);
    final t = (await repo.getById(id))!;

    expect(t.title, 'Call the plumber'); // trimmed
    expect(t.dueDate, DateTime(2026, 11, 14));
    expect(t.dueTime, const ClockTime(10, 0));
    expect(t.priority, TaskPriority.high);
    expect(t.list, TaskList.personal);
    expect(t.reminder, isTrue);
    expect(t.done, isFalse);
    expect(t.createdAt, now);
    expect(t.subtasks.map((s) => s.text), ['Find number', 'Book slot']);
    expect(t.subtasks.map((s) => s.done), [false, true]);
    expect(t.subtasksDone, 1);
  });

  test('a task without a date never keeps a time or reminder', () async {
    final id = await repo.create(
      const TaskDraft(
        title: 'Someday',
        dueTime: ClockTime(8, 0),
        reminder: true,
      ),
    );
    final t = (await repo.getById(id))!;
    expect(t.dueDate, isNull);
    expect(t.dueTime, isNull);
    expect(t.reminder, isFalse);
  });

  test('update replaces fields and subtasks but keeps done state', () async {
    final id = await repo.create(draft);
    await repo.setDone(id, true);
    await repo.update(
      id,
      draft.copyWith(
        title: 'Call plumber',
        list: TaskList.work,
        subtasks: const [SubtaskDraft(text: 'Only one')],
      ),
    );
    final t = (await repo.getById(id))!;
    expect(t.title, 'Call plumber');
    expect(t.list, TaskList.work);
    expect(t.subtasks.single.text, 'Only one');
    expect(t.done, isTrue);
  });

  test('setDone records and clears doneAt', () async {
    final id = await repo.create(draft);
    await repo.setDone(id, true);
    expect((await repo.getById(id))!.doneAt, now);
    await repo.setDone(id, false);
    final t = (await repo.getById(id))!;
    expect(t.done, isFalse);
    expect(t.doneAt, isNull);
  });

  test(
    'delete removes subtasks too, and restore brings everything back',
    () async {
      final id = await repo.create(draft);
      final deleted = await repo.delete(id);

      expect(await repo.getById(id), isNull);
      expect(await db.select(db.subtasks).get(), isEmpty); // cascade

      await repo.restore(deleted!);
      final back = (await repo.getById(id))!;
      expect(back.title, deleted.title);
      expect(back.subtasks.map((s) => s.id), deleted.subtasks.map((s) => s.id));
    },
  );

  test('moveToDate returns previous dates and can be undone', () async {
    final a = await repo.create(
      TaskDraft(title: 'A', dueDate: DateTime(2026, 11, 10)),
    );
    final b = await repo.create(
      TaskDraft(title: 'B', dueDate: DateTime(2026, 11, 11)),
    );

    final previous = await repo.moveToDate([a, b], DateTime(2026, 11, 13));
    expect((await repo.getById(a))!.dueDate, DateTime(2026, 11, 13));
    expect(previous, {a: DateTime(2026, 11, 10), b: DateTime(2026, 11, 11)});

    await repo.restoreDueDates(previous);
    expect((await repo.getById(b))!.dueDate, DateTime(2026, 11, 11));
  });

  test('watchAll emits on every change', () async {
    final emissions = <int>[];
    final sub = repo.watchAll().listen((tasks) => emissions.add(tasks.length));
    await pumpEventQueue();
    final id = await repo.create(draft);
    await pumpEventQueue();
    await repo.delete(id);
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions, [0, 1, 0]);
  });

  test('count', () async {
    expect(await repo.count(), 0);
    await repo.create(draft);
    expect(await repo.count(), 1);
  });
}
