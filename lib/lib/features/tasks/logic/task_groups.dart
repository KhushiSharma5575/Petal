import '../../../core/utils/dates.dart';
import '../../../data/models/task.dart';

/// The sections of the Tasks screen, in display order.
enum TaskGroup {
  overdue('Overdue'),
  today('Today'),
  tomorrow('Tomorrow'),
  later('Later'),
  noDate('No date'),
  completed('Completed');

  const TaskGroup(this.label);
  final String label;
}

/// Which group an open or done task belongs to on [today].
TaskGroup groupOf(TaskItem t, DateTime today) {
  if (t.done) return TaskGroup.completed;
  final due = t.dueDate;
  if (due == null) return TaskGroup.noDate;
  final diff = daysBetween(today, due);
  if (diff < 0) return TaskGroup.overdue;
  if (diff == 0) return TaskGroup.today;
  if (diff == 1) return TaskGroup.tomorrow;
  return TaskGroup.later;
}

/// Sorts tasks into groups. Only non-empty groups are returned, in
/// [TaskGroup] order.
///
/// Open tasks: earliest date first; on the same day, timed tasks by time,
/// then untimed; then High > Medium > Low; then oldest first.
/// Completed: most recently completed first.
Map<TaskGroup, List<TaskItem>> groupTasks(
  Iterable<TaskItem> tasks,
  DateTime today,
) {
  final buckets = {for (final g in TaskGroup.values) g: <TaskItem>[]};
  for (final t in tasks) {
    buckets[groupOf(t, today)]!.add(t);
  }
  for (final MapEntry(key: group, value: list) in buckets.entries) {
    list.sort(group == TaskGroup.completed ? _byDoneAtDesc : compareOpenTasks);
  }
  return {
    for (final MapEntry(key: g, value: list) in buckets.entries)
      if (list.isNotEmpty) g: list,
  };
}

int compareOpenTasks(TaskItem a, TaskItem b) {
  final da = a.dueDate, db = b.dueDate;
  if (da != db) {
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
  final ta = a.dueTime, tb = b.dueTime;
  if (ta != tb) {
    if (ta == null) return 1;
    if (tb == null) return -1;
    return ta.compareTo(tb);
  }
  final p = a.priority.index.compareTo(b.priority.index);
  if (p != 0) return p;
  return a.createdAt.compareTo(b.createdAt);
}

int _byDoneAtDesc(TaskItem a, TaskItem b) {
  final da = a.doneAt ?? a.createdAt, db = b.doneAt ?? b.createdAt;
  return db.compareTo(da);
}
