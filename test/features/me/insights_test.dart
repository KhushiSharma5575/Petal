import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/features/me/logic/insights.dart';

/// Friday 13 November 2026.
final today = DateTime(2026, 11, 13);

const workout = Habit(
  id: 1,
  key: HabitKeys.workout,
  name: 'Workout',
  type: HabitType.check,
  goal: 1,
);

var _id = 1;
Expense spend(int rupees, DateTime d) => Expense(
  id: _id++,
  amount: rupees * 100,
  category: ExpenseCategory.food,
  date: d,
  createdAt: d,
);

void main() {
  test('happier on workout days', () {
    final logs = <DateTime, int>{};
    final moods = <DateTime, Mood>{};
    for (var i = 1; i <= 20; i++) {
      final d = addDays(today, -i);
      final worked = i.isEven;
      if (worked) logs[d] = 1;
      moods[d] = worked ? Mood.great : Mood.okay;
    }
    final found = findInsights(
      habits: [HabitWithLogs(workout, logs)],
      moods: moods,
      expenses: const [],
      today: today,
    );
    expect(found.first, 'You feel happier on days you work out.');
  });

  test('weekends cost more', () {
    final expenses = [
      for (var i = 1; i <= 56; i++)
        spend(
          addDays(today, -i).weekday >= DateTime.saturday ? 900 : 200,
          addDays(today, -i),
        ),
    ];
    final found = findInsights(
      habits: const [],
      moods: const {},
      expenses: expenses,
      today: today,
    );
    expect(found, contains('You spend about 5x more a day on weekends.'));
  });

  test('a quiet start shows nothing rather than guesses', () {
    expect(
      findInsights(
        habits: [HabitWithLogs(workout, {today: 1})],
        moods: {today: Mood.good},
        expenses: [spend(100, today)],
        today: today,
      ),
      isEmpty,
    );
  });

  test('mood of the week', () {
    expect(
      weekMood({
        DateTime(2026, 11, 10): Mood.good,
        DateTime(2026, 11, 11): Mood.good,
        DateTime(2026, 11, 12): Mood.low,
        DateTime(2026, 11, 2): Mood.bad, // last week
      }, today),
      Mood.good,
    );
  });
}
