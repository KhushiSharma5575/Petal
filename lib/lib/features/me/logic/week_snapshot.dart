import '../../../core/utils/dates.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/habit.dart';
import '../../../data/models/task.dart';
import '../../habits/logic/habit_logic.dart';
import '../../money/logic/money_logic.dart';

/// The "this week so far" numbers at the top of Me.
class WeekSnapshot {
  const WeekSnapshot({
    required this.tasksDone,
    required this.habitsKeptPercent,
    required this.spent,
    required this.insight,
  });

  final int tasksDone;

  /// Done habit-days / possible habit-days, Monday to today. 0..100.
  final int habitsKeptPercent;

  /// Paise spent this week.
  final int spent;
  final String insight;
}

WeekSnapshot weekSnapshot({
  required Iterable<TaskItem> tasks,
  required Iterable<HabitWithLogs> habits,
  required Iterable<Expense> expenses,
  required DateTime today,
}) {
  final t = dateOnly(today);
  final monday = startOfWeek(t);
  final days = t.weekday; // Mon = 1 ... today
  bool inWeek(DateTime d) => !d.isBefore(monday) && !dateOnly(d).isAfter(t);

  final tasksDone = tasks
      .where((x) => x.done && x.doneAt != null && inWeek(x.doneAt!))
      .length;

  final active = habits.where((h) => h.habit.active).toList();
  var doneDays = 0;
  final perHabit = <Habit, int>{};
  for (final h in active) {
    var n = 0;
    for (var i = 0; i < days; i++) {
      if (isDone(h.habit, h.valueOn(addDays(monday, i)))) n++;
    }
    perHabit[h.habit] = n;
    doneDays += n;
  }
  final possible = active.length * days;
  final pct = possible == 0 ? 0 : (doneDays * 100 / possible).round();

  final weekTotals = totalsByCategory(expenses, rangeFor(MoneyPeriod.week, t));
  final spent = weekTotals.values.fold(0, (a, b) => a + b);

  return WeekSnapshot(
    tasksDone: tasksDone,
    habitsKeptPercent: pct,
    spent: spent,
    insight: _insight(perHabit, days, weekTotals),
  );
}

String _insight(
  Map<Habit, int> perHabit,
  int days,
  Map<ExpenseCategory, int> weekTotals,
) {
  if (days >= 2) {
    for (final MapEntry(key: h, value: n) in perHabit.entries) {
      if (n == days) return '${h.name} every day this week. Lovely.';
    }
  }
  if (perHabit.isNotEmpty) {
    final best = perHabit.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (best.value > 0) {
      return 'Most kept: ${best.key.name}, ${best.value} of $days '
          '${days == 1 ? 'day' : 'days'}.';
    }
  }
  if (weekTotals.isNotEmpty) {
    return 'Most of this week\'s spending went on '
        '${weekTotals.keys.first.label.toLowerCase()}.';
  }
  return 'A fresh week. Small steps count.';
}
