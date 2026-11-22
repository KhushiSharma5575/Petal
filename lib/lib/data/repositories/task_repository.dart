import 'package:drift/drift.dart';

import '../../core/utils/clock_time.dart';
import '../../core/utils/dates.dart';
import '../db/app_database.dart';
import '../models/task.dart';

/// All task reads and writes. The UI talks to this, never to drift directly.
class TaskRepository {
  TaskRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Every task with its subtasks. Emits again whenever tasks or subtasks
  /// change.
  Stream<List<TaskItem>> watchAll() {
    // A tiny query that "reads from" both tables: drift re-runs it on any
    // write to either one, and we then load the full data. The SQL text
    // must be unique per repository: drift shares one stream between
    // identical queries, so two "SELECT 1"s would watch the same tables.
    return _db
        .customSelect("SELECT 'tasks'", readsFrom: {_db.tasks, _db.subtasks})
        .watch()
        .asyncMap((_) => getAll());
  }

  Future<List<TaskItem>> getAll() async {
    final taskRows = await _db.select(_db.tasks).get();
    final subRows = await (_db.select(
      _db.subtasks,
    )..orderBy([(s) => OrderingTerm.asc(s.sortOrder)])).get();
    final subsByTask = <int, List<Subtask>>{};
    for (final s in subRows) {
      (subsByTask[s.taskId] ??= []).add(_toSubtask(s));
    }
    return [for (final t in taskRows) _toItem(t, subsByTask[t.id] ?? const [])];
  }

  Future<TaskItem?> getById(int id) async {
    final row = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final subs =
        await (_db.select(_db.subtasks)
              ..where((s) => s.taskId.equals(id))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    return _toItem(row, subs.map(_toSubtask).toList());
  }

  Future<int> count() async {
    final c = _db.tasks.id.count();
    final row = await (_db.selectOnly(_db.tasks)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  /// Saves a new task and returns its id.
  Future<int> create(TaskDraft draft) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.tasks)
          .insert(_fieldsFrom(draft).copyWith(createdAt: Value(_now())));
      await _insertSubtasks(id, draft.subtasks);
      return id;
    });
  }

  /// Replaces the editable fields (and subtasks) of task [id]. Done state is
  /// left alone; use [setDone] for that.
  Future<void> update(int id, TaskDraft draft) {
    return _db.transaction(() async {
      await (_db.update(
        _db.tasks,
      )..where((t) => t.id.equals(id))).write(_fieldsFrom(draft));
      await (_db.delete(_db.subtasks)..where((s) => s.taskId.equals(id))).go();
      await _insertSubtasks(id, draft.subtasks);
    });
  }

  Future<void> setDone(int id, bool done) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(done: Value(done), doneAt: Value(done ? _now() : null)),
    );
  }

  /// Sets the due date of several tasks at once (e.g. "Move all to today").
  /// Returns each task's previous date so the change can be undone with
  /// [restoreDueDates].
  Future<Map<int, DateTime?>> moveToDate(Iterable<int> ids, DateTime date) {
    return _db.transaction(() async {
      final idList = ids.toList();
      final rows = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.isIn(idList))).get();
      final previous = {
        for (final r in rows)
          r.id: r.dueDate == null ? null : fromIsoDate(r.dueDate!),
      };
      await (_db.update(_db.tasks)..where((t) => t.id.isIn(idList))).write(
        TasksCompanion(dueDate: Value(toIsoDate(date))),
      );
      return previous;
    });
  }

  Future<void> restoreDueDates(Map<int, DateTime?> dates) {
    return _db.transaction(() async {
      for (final MapEntry(key: id, value: date) in dates.entries) {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(dueDate: Value(date == null ? null : toIsoDate(date))),
        );
      }
    });
  }

  /// Deletes a task (and its subtasks). Returns the deleted task so it can
  /// be put back with [restore].
  Future<TaskItem?> delete(int id) {
    return _db.transaction(() async {
      final item = await getById(id);
      if (item == null) return null;
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
      return item;
    });
  }

  /// Puts back a task removed by [delete], with the same id and subtasks.
  Future<void> restore(TaskItem item) {
    return _db.transaction(() async {
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              id: Value(item.id),
              title: item.title,
              notes: Value(item.notes),
              dueDate: Value(
                item.dueDate == null ? null : toIsoDate(item.dueDate!),
              ),
              dueTime: Value(item.dueTime?.inMinutes),
              priority: Value(item.priority.name),
              listName: Value(item.list.name),
              reminder: Value(item.reminder),
              done: Value(item.done),
              doneAt: Value(item.doneAt),
              createdAt: item.createdAt,
              repeatRule: Value(item.repeatRule),
            ),
          );
      for (final s in item.subtasks) {
        await _db
            .into(_db.subtasks)
            .insert(
              SubtasksCompanion.insert(
                id: Value(s.id),
                taskId: item.id,
                body: s.text,
                done: Value(s.done),
                sortOrder: Value(s.sortOrder),
              ),
            );
      }
    });
  }

  // --- mapping -------------------------------------------------------------

  TasksCompanion _fieldsFrom(TaskDraft d) => TasksCompanion(
    title: Value(d.title.trim()),
    notes: Value(d.notes.trim()),
    dueDate: Value(d.dueDate == null ? null : toIsoDate(d.dueDate!)),
    dueTime: Value(d.dueDate == null ? null : d.dueTime?.inMinutes),
    priority: Value(d.priority.name),
    listName: Value(d.list.name),
    reminder: Value(d.dueDate != null && d.reminder),
  );

  Future<void> _insertSubtasks(int taskId, List<SubtaskDraft> subs) async {
    var order = 0;
    for (final s in subs) {
      if (s.text.trim().isEmpty) continue;
      await _db
          .into(_db.subtasks)
          .insert(
            SubtasksCompanion.insert(
              taskId: taskId,
              body: s.text.trim(),
              done: Value(s.done),
              sortOrder: Value(order++),
            ),
          );
    }
  }

  static Subtask _toSubtask(SubtaskRow s) =>
      Subtask(id: s.id, text: s.body, done: s.done, sortOrder: s.sortOrder);

  static TaskItem _toItem(TaskRow t, List<Subtask> subs) => TaskItem(
    id: t.id,
    title: t.title,
    notes: t.notes,
    dueDate: t.dueDate == null ? null : fromIsoDate(t.dueDate!),
    dueTime: t.dueTime == null ? null : ClockTime.fromMinutes(t.dueTime!),
    priority: TaskPriority.parse(t.priority),
    list: TaskList.parse(t.listName),
    reminder: t.reminder,
    done: t.done,
    doneAt: t.doneAt,
    createdAt: t.createdAt,
    repeatRule: t.repeatRule,
    subtasks: subs,
  );
}
