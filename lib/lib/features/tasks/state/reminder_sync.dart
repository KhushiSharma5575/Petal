import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/reminder_platform.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/task.dart';
import '../logic/due_label.dart';
import '../logic/reminder_time.dart';
import 'tasks_providers.dart';

/// Keeps the phone's scheduled notifications in line with the tasks.
///
/// Rather than scheduling/cancelling at each edit (easy to get wrong with
/// undo, "move all", done/undone...), we look at the full task list after
/// every change and fix any differences. Task id = notification id.
class ReminderSync {
  ReminderSync(this._platform);

  final ReminderPlatform _platform;
  Future<void> _last = Future.value();

  /// Runs syncs one after another so two quick edits can't interleave.
  /// A failed sync never blocks the ones after it.
  Future<void> sync(List<TaskItem> tasks, int leadMinutes, DateTime now) {
    return _last = _last
        .catchError((Object _) {})
        .then((_) => _sync(tasks, leadMinutes, now))
        .catchError((Object _) {});
  }

  Future<void> _sync(
    List<TaskItem> tasks,
    int leadMinutes,
    DateTime now,
  ) async {
    final wanted = <int, (TaskItem, DateTime)>{};
    for (final t in tasks) {
      final at = reminderTimeFor(t, leadMinutes, now);
      if (at != null) wanted[t.id] = (t, at);
    }

    // Only touch task notifications; ids from waterReminderIdBase up belong
    // to water reminders.
    final pending = (await _platform.pendingIds()).where(
      (id) => id < waterReminderIdBase,
    );
    for (final id in pending.toSet().difference(wanted.keys.toSet())) {
      await _platform.cancel(id);
    }
    // A reminder already in the tray goes away once its task is done or
    // deleted. One for a task still open stays until the user dismisses it.
    try {
      final open = {
        for (final t in tasks)
          if (!t.done) t.id,
      };
      for (final id in await _platform.shownIds()) {
        if (id < waterReminderIdBase && !open.contains(id)) {
          await _platform.cancel(id);
        }
      }
    } catch (_) {
      // Tidying the tray is a nice-to-have; never let it stop scheduling.
    }
    // Re-scheduling an existing id replaces it, which also picks up edits to
    // the title or time.
    for (final MapEntry(key: id, value: (task, at)) in wanted.entries) {
      try {
        await _platform.schedule(
          id: id,
          when: at,
          title: task.title,
          body: _body(task, at),
        );
      } catch (_) {
        // E.g. the time passed while this sync was queued: skip just this
        // one, the rest still get scheduled.
      }
    }
  }

  /// Worded for the moment the notification shows: a task due tomorrow
  /// whose reminder fires tomorrow says "Today", not "Tomorrow".
  String _body(TaskItem t, DateTime firesAt) {
    final due = dueLabel(t.dueDate, t.dueTime, dateOnly(firesAt));
    return due.isEmpty ? t.list.label : '$due · ${t.list.label}';
  }
}

/// Notification ids for water reminders start here (task ids never get this
/// high in a personal app).
const waterReminderIdBase = 900000;

/// Daytime hours for water reminders, every [everyHours] from 9:00 to
/// 21:00. Empty when off (0).
List<int> waterReminderHours(int everyHours) =>
    everyHours <= 0 ? const [] : [for (var h = 9; h <= 21; h += everyHours) h];

/// One queue per platform object (not a global, which would outlive it).
final _waterQueues = Expando<Future<void>>();

/// Re-creates the daily water reminders for the chosen interval. Runs one
/// at a time, so quickly switching "every 2h" -> "Off" can't leave extra
/// reminders behind.
Future<void> syncWaterReminders(ReminderPlatform platform, int everyHours) {
  final previous = _waterQueues[platform] ?? Future<void>.value();
  return _waterQueues[platform] = previous
      .catchError((Object _) {})
      .then((_) => _syncWater(platform, everyHours))
      .catchError((Object _) {});
}

Future<void> _syncWater(ReminderPlatform platform, int everyHours) async {
  final pending = await platform.pendingIds();
  final ids = {
    ...pending.where((id) => id >= waterReminderIdBase),
    // Every id any interval can use, even if not reported as pending.
    for (var i = 0; i < waterReminderHours(1).length; i++)
      waterReminderIdBase + i,
  };
  for (final id in ids) {
    await platform.cancel(id);
  }
  for (final (i, hour) in waterReminderHours(everyHours).indexed) {
    await platform.scheduleDaily(
      id: waterReminderIdBase + i,
      hour: hour,
      minute: 0,
      title: 'Time for some water',
      body: 'A glass now keeps you on track. Tap a glass in Petal when done.',
    );
  }
}

final reminderPlatformProvider = Provider<ReminderPlatform>(
  (ref) => LocalReminderPlatform(),
);

final reminderSyncProvider = Provider<ReminderSync>(
  (ref) => ReminderSync(ref.watch(reminderPlatformProvider)),
);

/// Watched once by the app root: re-syncs reminders whenever tasks or the
/// lead time change.
final reminderSyncRunnerProvider = Provider<void>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  final lead = ref.watch(reminderLeadProvider).value;
  if (tasks == null || lead == null) return;
  ref.read(reminderSyncProvider).sync(tasks, lead, ref.read(clockProvider)());
});
