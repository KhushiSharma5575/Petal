import '../../../core/utils/dates.dart';
import '../../../data/models/task.dart';

/// What the Tasks screen is currently showing: one list (or all), and
/// optionally only one day picked in the week strip.
class TaskFilter {
  const TaskFilter({this.list, this.day});

  /// null = All lists.
  final TaskList? list;

  /// null = every day.
  final DateTime? day;

  bool get isActive => list != null || day != null;

  bool matches(TaskItem t) {
    if (list != null && t.list != list) return false;
    if (day != null) {
      final due = t.dueDate;
      if (due == null || !isSameDay(due, day!)) return false;
    }
    return true;
  }

  TaskFilter withList(TaskList? list) => TaskFilter(list: list, day: day);

  /// Picking the day that's already selected clears it ("tap again to show
  /// all").
  TaskFilter toggleDay(DateTime d) => TaskFilter(
    list: list,
    day: day != null && isSameDay(day!, d) ? null : dateOnly(d),
  );

  TaskFilter clearDay() => TaskFilter(list: list);

  @override
  bool operator ==(Object other) =>
      other is TaskFilter && other.list == list && other.day == day;

  @override
  int get hashCode => Object.hash(list, day);
}

/// The 7 days (Mon to Sun) of the week containing [today].
List<DateTime> weekOf(DateTime today) {
  final monday = startOfWeek(today);
  return [for (var i = 0; i < 7; i++) addDays(monday, i)];
}

/// Number of open tasks due on each day (for the dots in the week strip).
Map<DateTime, int> openTasksPerDay(Iterable<TaskItem> tasks) {
  final counts = <DateTime, int>{};
  for (final t in tasks) {
    final due = t.dueDate;
    if (t.done || due == null) continue;
    final d = dateOnly(due);
    counts[d] = (counts[d] ?? 0) + 1;
  }
  return counts;
}
