import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/voice/logic/answers.dart';
import 'package:petal/features/voice/logic/voice_parser.dart';

/// Friday 13 November 2026, 10:00.
final now = DateTime(2026, 11, 13, 10);
final today = DateTime(2026, 11, 13);

AskPetal ask(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<AskPetal>(), reason: '"$said" should be a question, got $c');
  return c as AskPetal;
}

void main() {
  group('understands questions', () {
    test('spending', () {
      final q = ask('how much did I spend this week?');
      expect(q.kind, AskKind.spent);
      expect(q.when, 'this week');
      expect(q.from, DateTime(2026, 11, 9));
      expect(
        ask('how much did i spend on food today').category,
        ExpenseCategory.food,
      );
      expect(ask('what did I spend yesterday').when, 'yesterday');
    });
    test('budget, tasks, water, streaks, habits', () {
      expect(ask('how much budget is left').kind, AskKind.budgetLeft);
      expect(
        ask('how much can I still spend on shopping').category,
        ExpenseCategory.shopping,
      );
      expect(ask("what's on tomorrow").kind, AskKind.tasks);
      expect(ask('what do i have today').kind, AskKind.tasks);
      expect(ask('any tasks this week').when, 'this week');
      expect(ask('how many glasses of water today').kind, AskKind.water);
      expect(ask("what's my workout streak").habitKey, HabitKeys.workout);
      expect(ask('what habits are left').kind, AskKind.habitsLeft);
    });
    test('normal commands are not questions', () {
      expect(parseVoice('spent 250 on lunch', now), isA<AddExpense>());
      expect(parseVoice('add call mom tomorrow', now), isA<AddTask>());
      expect(parseVoice('what to buy for mom', now), isNot(isA<AskPetal>()));
    });
  });

  group('answers', () {
    var id = 1;
    Expense spend(int rupees, ExpenseCategory c, DateTime d) => Expense(
      id: id++,
      amount: rupees * 100,
      category: c,
      date: d,
      createdAt: d,
    );
    TaskItem task(String title, DateTime? due, {bool done = false}) => TaskItem(
      id: id++,
      title: title,
      dueDate: due,
      done: done,
      createdAt: now,
    );
    const water = Habit(
      id: 1,
      key: HabitKeys.water,
      name: 'Water',
      type: HabitType.count,
      goal: 8,
    );
    const workout = Habit(
      id: 2,
      key: HabitKeys.workout,
      name: 'Workout',
      type: HabitType.check,
      goal: 1,
    );
    final habits = [
      HabitWithLogs(water, {today: 3}),
      HabitWithLogs(workout, {
        today: 1,
        DateTime(2026, 11, 12): 1,
        DateTime(2026, 11, 11): 1,
      }),
    ];
    final expenses = [
      spend(250, ExpenseCategory.food, today),
      spend(100, ExpenseCategory.travel, today),
      spend(900, ExpenseCategory.shopping, DateTime(2026, 11, 10)),
    ];
    final tasks = [
      task('Call plumber', DateTime(2026, 11, 14)),
      task('Pay rent', DateTime(2026, 11, 14)),
      task('Old one', DateTime(2026, 11, 10)),
      task('Done one', DateTime(2026, 11, 14), done: true),
    ];
    String answer(String said) => answerQuestion(
      ask(said),
      tasks: tasks,
      expenses: expenses,
      budgets: {ExpenseCategory.shopping: 80000},
      habits: habits,
      today: now,
    );

    test('spending', () {
      expect(
        answer('how much did I spend today'),
        'You spent ₹350 today, mostly on food (₹250).',
      );
      expect(
        answer('how much did I spend on food this week'),
        'You spent ₹250 on food this week.',
      );
      expect(
        answer('how much did I spend yesterday'),
        'You haven\'t spent anything yesterday.',
      );
    });
    test('budgets', () {
      expect(
        answer('how much budget is left'),
        contains('Shopping is over budget.'),
      );
      expect(
        answer('how much can I still spend on shopping'),
        'Shopping is over budget by ₹100 this month.',
      );
    });
    test('tasks', () {
      expect(
        answer("what's on tomorrow"),
        'You have 2 tasks for tomorrow: Call plumber and Pay rent.',
      );
      expect(
        answer('what do i have today'),
        'Nothing planned today. Plus 1 overdue.',
      );
    });
    test('water, streaks, habits left', () {
      expect(
        answer('how much water today'),
        'You\'ve had 3 of 8 glasses today. 5 more to go.',
      );
      expect(
        answer("what's my workout streak"),
        'Your workout streak is 3 days.',
      );
      expect(answer('what habits are left'), 'Still to do today: water.');
    });
    test('joinWords', () {
      expect(joinWords(['a']), 'a');
      expect(joinWords(['a', 'b', 'c']), 'a, b and c');
      expect(
        joinWords(['a', 'b', 'c', 'd', 'e'], max: 3),
        'a, b, c and 2 more',
      );
    });
  });
}
