import '../../../core/utils/clock_time.dart';
import '../../../data/models/task.dart';

/// Time used for reminders on tasks that have a date but no time.
const defaultReminderTime = ClockTime(9, 0);

/// When the reminder for [t] should fire, or null if it shouldn't.
///
/// - Needs `reminder` on, a due date, and the task not done.
/// - With a time: [leadMinutes] before it (default 15).
/// - Without a time: 9:00 am on the due day.
/// - Returns null if that moment has already passed ([now]).
DateTime? reminderTimeFor(TaskItem t, int leadMinutes, DateTime now) {
  final due = t.dueDate;
  if (!t.reminder || t.done || due == null) return null;
  final time = t.dueTime;
  final at = time == null
      ? defaultReminderTime.on(due)
      : time.on(due).subtract(Duration(minutes: leadMinutes));
  return at.isAfter(now) ? at : null;
}

/// Text for the "Remind me" switch, e.g. "15 min before" or "At 9 am".
String reminderHint(ClockTime? time, int leadMinutes) {
  if (time == null) return 'At ${defaultReminderTime.format()} that day';
  if (leadMinutes == 0) return 'At ${time.format()}';
  return '$leadMinutes min before';
}
