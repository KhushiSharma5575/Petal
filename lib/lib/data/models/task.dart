import '../../core/utils/clock_time.dart';

/// Task priority. Stored in the database by [name].
enum TaskPriority {
  high('High'),
  medium('Medium'),
  low('Low');

  const TaskPriority(this.label);
  final String label;

  static TaskPriority parse(String s) =>
      values.firstWhere((p) => p.name == s, orElse: () => medium);
}

/// The fixed task lists. Stored in the database by [name].
enum TaskList {
  work('Work'),
  personal('Personal'),
  study('Study'),
  shopping('Shopping');

  const TaskList(this.label);
  final String label;

  static TaskList parse(String s) =>
      values.firstWhere((l) => l.name == s, orElse: () => personal);
}

class Subtask {
  const Subtask({
    required this.id,
    required this.text,
    required this.done,
    required this.sortOrder,
  });

  final int id;
  final String text;
  final bool done;
  final int sortOrder;
}

/// A saved task, as the UI sees it (never a raw database row).
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.medium,
    this.list = TaskList.personal,
    this.reminder = false,
    this.done = false,
    this.doneAt,
    required this.createdAt,
    this.repeatRule,
    this.subtasks = const [],
  });

  final int id;
  final String title;
  final String notes;

  /// Calendar day (midnight), or null for "No date".
  final DateTime? dueDate;

  /// Optional time of day; only meaningful with a [dueDate].
  final ClockTime? dueTime;
  final TaskPriority priority;
  final TaskList list;

  /// Whether to send a notification before the task is due.
  final bool reminder;
  final bool done;
  final DateTime? doneAt;
  final DateTime createdAt;

  /// Reserved for repeating tasks (later phase).
  final String? repeatRule;
  final List<Subtask> subtasks;

  int get subtasksDone => subtasks.where((s) => s.done).length;

  /// The editable fields of this task, for the edit sheet.
  TaskDraft toDraft() => TaskDraft(
    title: title,
    notes: notes,
    dueDate: dueDate,
    dueTime: dueTime,
    priority: priority,
    list: list,
    reminder: reminder,
    subtasks: [
      for (final s in subtasks) SubtaskDraft(text: s.text, done: s.done),
    ],
  );
}

class SubtaskDraft {
  const SubtaskDraft({required this.text, this.done = false});
  final String text;
  final bool done;

  SubtaskDraft copyWith({String? text, bool? done}) =>
      SubtaskDraft(text: text ?? this.text, done: done ?? this.done);

  @override
  bool operator ==(Object other) =>
      other is SubtaskDraft && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);
}

/// What the add/edit sheet produces. Immutable; use [copyWith] to change.
class TaskDraft {
  const TaskDraft({
    this.title = '',
    this.notes = '',
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.medium,
    this.list = TaskList.personal,
    this.reminder = false,
    this.subtasks = const [],
  });

  final String title;
  final String notes;
  final DateTime? dueDate;
  final ClockTime? dueTime;
  final TaskPriority priority;
  final TaskList list;
  final bool reminder;
  final List<SubtaskDraft> subtasks;

  bool get isValid => title.trim().isNotEmpty;

  /// Pass `clearDueDate`/`clearDueTime` to set those fields to null.
  TaskDraft copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    bool clearDueDate = false,
    ClockTime? dueTime,
    bool clearDueTime = false,
    TaskPriority? priority,
    TaskList? list,
    bool? reminder,
    List<SubtaskDraft>? subtasks,
  }) {
    final newDate = clearDueDate ? null : (dueDate ?? this.dueDate);
    return TaskDraft(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: newDate,
      // A time without a date makes no sense, so clearing the date clears it.
      dueTime: (clearDueTime || newDate == null)
          ? null
          : (dueTime ?? this.dueTime),
      priority: priority ?? this.priority,
      list: list ?? this.list,
      // Same for reminders: they need a date.
      reminder: newDate == null ? false : (reminder ?? this.reminder),
      subtasks: subtasks ?? this.subtasks,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      other.title == title &&
      other.notes == notes &&
      other.dueDate == dueDate &&
      other.dueTime == dueTime &&
      other.priority == priority &&
      other.list == list &&
      other.reminder == reminder &&
      _listEquals(other.subtasks, subtasks);

  @override
  int get hashCode => Object.hash(
    title,
    notes,
    dueDate,
    dueTime,
    priority,
    list,
    reminder,
    Object.hashAll(subtasks),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
