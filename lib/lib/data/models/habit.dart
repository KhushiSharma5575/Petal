/// How a habit is measured.
enum HabitType {
  /// Done or not (Workout, Meditate, Read).
  check,

  /// A number of things, e.g. glasses of water.
  count,

  /// Minutes, e.g. Study.
  minutes;

  static HabitType parse(String s) =>
      values.firstWhere((t) => t.name == s, orElse: () => check);
}

/// Keys of the built-in habits (stable ids used by code and, later, voice).
abstract final class HabitKeys {
  static const water = 'water';
  static const workout = 'workout';
  static const study = 'study';
  static const meditate = 'meditate';
  static const read = 'read';
}

class Habit {
  const Habit({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.goal,
    this.sortOrder = 0,
    this.active = true,
  });

  final int id;
  final String key;
  final String name;
  final HabitType type;

  /// Daily target: 1 for check habits.
  final int goal;
  final int sortOrder;
  final bool active;
}

/// A habit plus its logged values, keyed by calendar day (midnight).
class HabitWithLogs {
  const HabitWithLogs(this.habit, this.values);
  final Habit habit;
  final Map<DateTime, int> values;

  int valueOn(DateTime day) => values[day] ?? 0;
}

/// One row of the weekly plan.
class PlanDay {
  const PlanDay({
    required this.weekday,
    this.workout = '',
    this.studyFocus = '',
  });

  /// 1 = Monday ... 7 = Sunday.
  final int weekday;
  final String workout;
  final String studyFocus;
}
