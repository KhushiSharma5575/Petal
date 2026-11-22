import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/task.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../logic/task_filter.dart';
import '../logic/task_groups.dart';

/// Every task, live from the database.
final tasksProvider = StreamProvider<List<TaskItem>>((ref) {
  return ref.watch(taskRepositoryProvider).watchAll();
});

/// Minutes before the due time to send a reminder (setting; default 15).
final reminderLeadProvider = StreamProvider<int>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchInt(
        SettingKeys.reminderLeadMinutes,
        SettingDefaults.reminderLeadMinutes,
      );
});

/// The list + day the Tasks screen is filtered to.
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  void setList(TaskList? list) => state = state.withList(list);
  void toggleDay(DateTime day) => state = state.toggleDay(day);
  void clearDay() => state = state.clearDay();
  void clearAll() => state = const TaskFilter();
}

final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

/// Which groups are folded. Completed starts folded.
class CollapsedGroupsNotifier extends Notifier<Set<TaskGroup>> {
  @override
  Set<TaskGroup> build() => {TaskGroup.completed};

  void toggle(TaskGroup g) =>
      state = state.contains(g) ? ({...state}..remove(g)) : {...state, g};
}

final collapsedGroupsProvider =
    NotifierProvider<CollapsedGroupsNotifier, Set<TaskGroup>>(
      CollapsedGroupsNotifier.new,
    );

/// The tasks the screen shows, filtered and grouped. Null while loading.
final visibleGroupsProvider = Provider<Map<TaskGroup, List<TaskItem>>?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  if (tasks == null) return null;
  final filter = ref.watch(taskFilterProvider);
  final today = ref.watch(todayProvider);
  return groupTasks(tasks.where(filter.matches), today);
});

/// Tasks for the Today screen: overdue and today's open tasks first, then
/// those already done today. [shown] is capped at [todayTaskLimit].
class TodayTasks {
  const TodayTasks({
    required this.shown,
    required this.total,
    required this.doneCount,
  });
  final List<TaskItem> shown;
  final int total;
  final int doneCount;
}

const todayTaskLimit = 5;

final todayTasksProvider = Provider<TodayTasks?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  if (tasks == null) return null;
  final today = ref.watch(todayProvider);
  final open = <TaskItem>[], done = <TaskItem>[];
  for (final t in tasks) {
    final g = groupOf(t, today);
    if (g == TaskGroup.overdue || g == TaskGroup.today) {
      open.add(t);
    } else if (t.done && t.dueDate != null && isSameDay(t.dueDate!, today)) {
      done.add(t);
    }
  }
  open.sort(compareOpenTasks);
  final all = [...open, ...done];
  return TodayTasks(
    shown: all.take(todayTaskLimit).toList(),
    total: all.length,
    doneCount: done.length,
  );
});

/// Open-task counts per day for the week strip dots (respects the list
/// filter, ignores the day filter).
final weekDotsProvider = Provider<Map<DateTime, int>>((ref) {
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final list = ref.watch(taskFilterProvider).list;
  return openTasksPerDay(
    list == null ? tasks : tasks.where((t) => t.list == list),
  );
});
