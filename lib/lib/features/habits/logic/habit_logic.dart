import '../../../core/utils/dates.dart';
import '../../../data/models/habit.dart';

/// Whether [value] meets [habit]'s daily goal.
bool isDone(Habit habit, int value) => switch (habit.type) {
  HabitType.check => value >= 1,
  HabitType.count || HabitType.minutes => value >= habit.goal,
};

/// 0.0 to 1.0 progress toward today's goal.
double progressOf(Habit habit, int value) {
  if (habit.goal <= 0) return value > 0 ? 1 : 0;
  return (value / habit.goal).clamp(0.0, 1.0);
}

/// Consecutive days the habit was done, counting back from [today].
///
/// If today isn't done yet, the streak still counts up to yesterday, so a
/// streak doesn't look "broken" first thing in the morning.
int streakOf(HabitWithLogs h, DateTime today) {
  var day = dateOnly(today);
  if (!isDone(h.habit, h.valueOn(day))) day = addDays(day, -1);
  var streak = 0;
  // A 2-year cap keeps this bounded even with odd data.
  while (streak < 730 && isDone(h.habit, h.valueOn(day))) {
    streak++;
    day = addDays(day, -1);
  }
  return streak;
}

/// (done, total) of active habits for [day]; drives the progress ring.
(int, int) dayProgress(Iterable<HabitWithLogs> habits, DateTime day) {
  final d = dateOnly(day);
  var done = 0, total = 0;
  for (final h in habits) {
    if (!h.habit.active) continue;
    total++;
    if (isDone(h.habit, h.valueOn(d))) done++;
  }
  return (done, total);
}

/// Water: each glass is 375 ml, so 8 glasses = 3 litres.
const mlPerGlass = 375;

/// "1.9 L" style text for [glasses].
String litresText(int glasses) {
  final litres = glasses * mlPerGlass / 1000;
  final text = litres.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} L';
}

/// New water value when glass number [index] (0-based) is tapped:
/// tapping an empty glass fills up to it; tapping the last full glass
/// empties it (so a mistaken tap is easy to undo).
int waterAfterTap(int current, int index) =>
    index + 1 == current ? index : index + 1;

/// "45 / 120 min"
String minutesText(int value, int goal) => '$value / $goal min';
