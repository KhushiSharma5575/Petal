import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../../data/models/task.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/task_repository.dart';
import '../logic/task_groups.dart';
import 'reminder_sync.dart';

/// Actions the Tasks UI can take. Keeps widgets free of repository details.
class TasksController {
  TasksController(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<int> add(TaskDraft draft) => _repo.create(draft);

  Future<void> save(int id, TaskDraft draft) => _repo.update(id, draft);

  Future<void> setDone(TaskItem t, bool done) => _repo.setDone(t.id, done);

  /// Deletes [id]; returns the task so the caller can offer Undo.
  Future<TaskItem?> delete(int id) => _repo.delete(id);

  Future<void> undoDelete(TaskItem t) => _repo.restore(t);

  /// Moves every overdue open task to today. Returns their old dates for
  /// Undo.
  Future<Map<int, DateTime?>> moveOverdueToToday(List<TaskItem> overdue) {
    final today = _ref.read(todayProvider);
    return _repo.moveToDate(
      overdue
          .where((t) => groupOf(t, today) == TaskGroup.overdue)
          .map((t) => t.id),
      today,
    );
  }

  Future<void> undoMove(Map<int, DateTime?> previous) =>
      _repo.restoreDueDates(previous);

  /// Called when the user turns on "Remind me". Android shows its permission
  /// prompt only if it hasn't been answered yet; otherwise this just reports
  /// the current state.
  Future<ReminderPermissionResult> ensureReminderPermission() async {
    final platform = _ref.read(reminderPlatformProvider);
    final allowed = await platform.requestPermission();
    if (!allowed) return ReminderPermissionResult.blocked;
    if (!await platform.canUseExactTiming()) {
      return ReminderPermissionResult.inexact;
    }
    return ReminderPermissionResult.ok;
  }

  Future<void> openExactTimingSettings() =>
      _ref.read(reminderPlatformProvider).requestExactTiming();
}

enum ReminderPermissionResult { ok, inexact, blocked }

final tasksControllerProvider = Provider<TasksController>(TasksController.new);
