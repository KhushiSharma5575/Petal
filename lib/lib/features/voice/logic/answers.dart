import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/habit.dart';
import '../../../data/models/task.dart';
import '../../habits/logic/habit_logic.dart';
import '../../money/logic/money_logic.dart';
import 'voice_parser.dart';

/// Petal's spoken answer to [q], from the data on the phone. Written to
/// sound natural read aloud (no emoji, short sentences).
String answerQuestion(
  AskPetal q, {
  required List<TaskItem> tasks,
  required List<Expense> expenses,
  required Map<ExpenseCategory, int> budgets,
  required List<HabitWithLogs> habits,
  required DateTime today,
}) {
  final t = dateOnly(today);
  switch (q.kind) {
    case AskKind.spent:
      final totals = totalsByCategory(expenses, (q.from, q.to));
      final c = q.category;
      if (c != null) {
        final spent = totals[c] ?? 0;
        return spent == 0
            ? 'You haven\'t spent anything on ${c.label.toLowerCase()} '
                  '${q.when}.'
            : 'You spent ${formatRupees(spent)} on ${c.label.toLowerCase()} '
                  '${q.when}.';
      }
      final total = totals.values.fold(0, (a, b) => a + b);
      if (total == 0) return 'You haven\'t spent anything ${q.when}.';
      final top = totals.entries.first; // biggest first
      if (totals.length == 1) {
        return 'You spent ${formatRupees(total)} ${q.when}, all on '
            '${top.key.label.toLowerCase()}.';
      }
      return 'You spent ${formatRupees(total)} ${q.when}, mostly on '
          '${top.key.label.toLowerCase()} (${formatRupees(top.value)}).';

    case AskKind.budgetLeft:
      if (budgets.isEmpty) {
        return 'You haven\'t set any budgets yet. You can set them in Money.';
      }
      final usage = budgetUsage(expenses, budgets, t);
      final c = q.category;
      if (c != null) {
        final u = usage.where((u) => u.category == c).firstOrNull;
        if (u == null) {
          return 'You haven\'t set a ${c.label.toLowerCase()} budget. You can '
              'set one in Money.';
        }
        return u.over
            ? '${c.label} is over budget by ${formatRupees(u.spent - u.limit)} '
                  'this month.'
            : 'You have ${formatRupees(u.limit - u.spent)} left in your '
                  '${c.label.toLowerCase()} budget this month.';
      }
      final left = usage.fold(0, (sum, u) => sum + (u.limit - u.spent));
      final over = [
        for (final u in usage)
          if (u.over) u.category.label,
      ];
      final start = left > 0
          ? 'You have ${formatRupees(left)} left across your budgets this '
                'month.'
          : 'You\'ve used all your budgets this month.';
      if (over.isEmpty) return start;
      return '$start ${joinWords(over)} ${over.length == 1 ? 'is' : 'are'} '
          'over budget.';

    case AskKind.tasks:
      final open = tasks.where((x) => !x.done && x.dueDate != null).toList();
      final inRange = [
        for (final x in open)
          if (!x.dueDate!.isBefore(q.from) && !x.dueDate!.isAfter(q.to)) x,
      ];
      final overdue = q.when == 'today'
          ? open.where((x) => x.dueDate!.isBefore(t)).length
          : 0;
      final names = [for (final x in inRange) x.title];
      final when = q.when == 'tomorrow' ? 'for tomorrow' : q.when;
      final main = names.isEmpty
          ? 'Nothing planned $when.'
          : 'You have ${names.length} '
                '${names.length == 1 ? 'task' : 'tasks'} $when: '
                '${joinWords(names, max: 3)}.';
      if (overdue == 0) {
        return names.isEmpty && q.when == 'today'
            ? '$main Enjoy your day!'
            : main;
      }
      return '$main Plus $overdue overdue.';

    case AskKind.water:
      final water = habits
          .where((h) => h.habit.key == HabitKeys.water)
          .firstOrNull;
      if (water == null) return 'Water tracking is off.';
      final day = q.from.isAfter(t) ? t : q.from;
      final had = water.valueOn(day);
      final goal = water.habit.goal;
      final glasses = '$had ${had == 1 ? 'glass' : 'glasses'}';
      if (!isSameDay(day, t)) return 'You had $glasses of $goal yesterday.';
      if (had >= goal) return 'You\'ve had $glasses today. Goal reached!';
      final left = goal - had;
      return 'You\'ve had $had of $goal glasses today. $left more to go.';

    case AskKind.streak:
      final key = q.habitKey;
      if (key != null) {
        final h = habits.where((h) => h.habit.key == key).firstOrNull;
        if (h == null) return 'That habit is turned off.';
        final days = streakOf(h, t);
        final name = h.habit.name.toLowerCase();
        return days == 0
            ? 'No $name streak yet. Today is a good day to start!'
            : 'Your $name streak is $days ${days == 1 ? 'day' : 'days'}.';
      }
      HabitWithLogs? best;
      var bestDays = 0;
      for (final h in habits) {
        final d = streakOf(h, t);
        if (d > bestDays) {
          best = h;
          bestDays = d;
        }
      }
      return best == null
          ? 'No streaks yet. Tick a habit today to start one.'
          : 'Your best streak is ${best.habit.name.toLowerCase()}: $bestDays '
                '${bestDays == 1 ? 'day' : 'days'}.';

    case AskKind.habitsLeft:
      final left = [
        for (final h in habits)
          if (!isDone(h.habit, h.valueOn(t))) h.habit.name.toLowerCase(),
      ];
      if (habits.isEmpty) return 'You have no habits yet.';
      return left.isEmpty
          ? 'All your habits are done today. Amazing!'
          : 'Still to do today: ${joinWords(left)}.';
  }
}

/// "a, b and c"; with [max], "a, b, c and 2 more".
String joinWords(List<String> words, {int? max}) {
  if (words.isEmpty) return '';
  var shown = words;
  var extra = 0;
  if (max != null && words.length > max) {
    shown = words.take(max).toList();
    extra = words.length - max;
  }
  if (extra > 0) return '${shown.join(', ')} and $extra more';
  if (shown.length == 1) return shown.first;
  return '${shown.take(shown.length - 1).join(', ')} and ${shown.last}';
}
