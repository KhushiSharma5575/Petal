import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/models/mood.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/voice/logic/voice_parser.dart';

/// Friday 13 November 2026, 10:00.
final now = DateTime(2026, 11, 13, 10, 0);
DateTime d(int day, [int month = 11, int year = 2026]) =>
    DateTime(year, month, day);

TaskDraft task(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<AddTask>(), reason: '"$said" should be a task, got $c');
  return (c as AddTask).draft;
}

ExpenseDraft expense(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<AddExpense>(), reason: '"$said" should be an expense, got $c');
  return (c as AddExpense).draft;
}

LogHabit habit(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<LogHabit>(), reason: '"$said" should be a habit, got $c');
  return c as LogHabit;
}

Mood mood(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<SetMood>(), reason: '"$said" should be a mood, got $c');
  return (c as SetMood).mood;
}

void main() {
  group('tasks: the spec examples', () {
    test('add call the plumber tomorrow at 10 am, high priority', () {
      final t = task('add call the plumber tomorrow at 10 am, high priority');
      expect(t.title, 'Call the plumber');
      expect(t.dueDate, d(14));
      expect(t.dueTime, const ClockTime(10, 0));
      expect(t.priority, TaskPriority.high);
      expect(t.list, TaskList.personal);
      expect(t.reminder, isFalse);
    });

    test('remind me to submit the report on Friday', () {
      final t = task('remind me to submit the report on Friday');
      expect(t.title, 'Submit the report');
      expect(t.dueDate, d(13)); // today is Friday
      expect(t.list, TaskList.work);
      expect(t.reminder, isTrue);
    });
  });

  group('tasks: dates', () {
    test('today, tomorrow, day after tomorrow', () {
      expect(task('add pay rent today').dueDate, d(13));
      expect(task('add pay rent tomorrow').dueDate, d(14));
      expect(task('add pay rent the day after tomorrow').dueDate, d(15));
    });

    test('weekday names, "next" weekday and next week', () {
      expect(task('add call mom on monday').dueDate, d(16));
      expect(task('add call mom saturday').dueDate, d(14));
      expect(task('add call mom next friday').dueDate, d(20));
      expect(task('add plan holiday next week').dueDate, d(16));
      expect(task('add clean room this weekend').dueDate, d(14));
    });

    test('"on 15 November" and friends', () {
      expect(task('add pay rent on 15 november').dueDate, d(15));
      expect(task('add pay rent on the 15th of November').dueDate, d(15));
      expect(task('add pay rent November 15').dueDate, d(15));
      expect(
        task('add pay rent on 1 jan').dueDate,
        d(1, 1, 2027),
      ); // past -> next year
      expect(
        task('add pay rent on 13 november').dueDate,
        d(13),
      ); // today, not next year
    });
  });

  group('tasks: times', () {
    test('6 pm, 6:30 pm, at 18:00, dotted a.m.', () {
      expect(task('add gym at 6 pm').dueTime, const ClockTime(18, 0));
      expect(task('add gym at 6:30 pm').dueTime, const ClockTime(18, 30));
      expect(task('add gym at 18:00').dueTime, const ClockTime(18, 0));
      expect(task('add gym at 7 a.m. tomorrow').dueTime, const ClockTime(7, 0));
      expect(task('add gym 7am tomorrow').dueTime, const ClockTime(7, 0));
      expect(
        task('add lunch with sam at noon').dueTime,
        const ClockTime(12, 0),
      );
    });

    test('a time alone means today, or tomorrow if it has passed', () {
      final later = task('add call bank at 6 pm');
      expect(later.dueDate, d(13));
      final passed = task('add call bank at 9 am');
      expect(passed.dueDate, d(14));
    });

    test('parts of the day', () {
      expect(
        task('remind me to call mom tomorrow evening').dueTime,
        const ClockTime(18, 0),
      );
      expect(
        task('add stretch tomorrow morning').dueTime,
        const ClockTime(9, 0),
      );
      final tonight = task('add watch the match tonight');
      expect(tonight.dueDate, d(13));
      expect(tonight.dueTime, const ClockTime(20, 0));
    });

    test('bare "at 6" guesses pm for 1-7', () {
      expect(task('add dinner at 6').dueTime, const ClockTime(18, 0));
      expect(task('add jog tomorrow at 8').dueTime, const ClockTime(8, 0));
    });

    test('"at 2:00 PM" with capitals', () {
      expect(
        task('Add Dentist At 2:00 PM Tomorrow').dueTime,
        const ClockTime(14, 0),
      );
    });
  });

  group('tasks: priority and lists', () {
    test('priority words', () {
      expect(task('add urgent call the bank').priority, TaskPriority.high);
      expect(task('add file taxes, important').priority, TaskPriority.high);
      expect(task('add reply to sam ASAP').priority, TaskPriority.high);
      expect(task('add water plants low priority').priority, TaskPriority.low);
      expect(task('add water plants').priority, TaskPriority.medium);
      expect(task('add reply to sam asap').title, 'Reply to sam');
    });

    test('list from keywords', () {
      expect(task('add buy milk').list, TaskList.shopping);
      expect(task('add groceries for the week').list, TaskList.shopping);
      expect(task('add revise chapter 4').list, TaskList.study);
      expect(task('add prepare for the exam').list, TaskList.study);
      expect(task('add team meeting at 3 pm').list, TaskList.work);
      expect(task('add send report to client').list, TaskList.work);
      expect(task('add call grandma').list, TaskList.personal);
    });
  });

  group('tasks: messy real speech', () {
    test('polite and filler openings', () {
      expect(
        task('can you add call the plumber tomorrow').title,
        'Call the plumber',
      );
      expect(
        task('please remind me to pay the electricity bill').title,
        'Pay the electricity bill',
      );
      expect(task('hey petal could you please add buy eggs').title, 'Buy eggs');
      expect(task('um so add book tickets').title, 'Book tickets');
      expect(task('I need to renew my passport').title, 'Renew my passport');
      expect(task('add a task to water the plants').title, 'Water the plants');
      expect(
        task('remember to take out the trash').title,
        'Take out the trash',
      );
    });

    test('missing "add": anything else becomes a task to confirm', () {
      final t = task('call dentist tomorrow');
      expect(t.title, 'Call dentist');
      expect(t.dueDate, d(14));
      expect(task('tomorrow call dentist').title, 'Call dentist');
    });

    test('"remind me" sets the reminder; plain add does not', () {
      expect(task('remind me to drink water at 4 pm').reminder, isTrue);
      expect(task('add drink water at 4 pm').reminder, isFalse);
    });

    test('task cues win over habit and expense words', () {
      expect(task('remind me to drink water at 4 pm').title, 'Drink water');
      expect(task('add buy water bottles').list, TaskList.shopping);
      expect(task('remind me to pay 500 for rent').title, 'Pay 500 for rent');
    });

    test('nothing useful is not understood', () {
      expect(parseVoice('', now), isA<NotUnderstood>());
      expect(parseVoice('add', now), isA<NotUnderstood>());
      expect(parseVoice('um', now), isA<NotUnderstood>());
      expect(parseVoice('please', now), isA<NotUnderstood>());
    });
  });

  group('expenses', () {
    test('spent 250 on lunch', () {
      final e = expense('spent 250 on lunch');
      expect(e.amount, 25000);
      expect(e.category, ExpenseCategory.food);
      expect(e.note, 'Lunch');
      expect(e.date, d(13));
    });

    test('paid 700 for internet bill', () {
      final e = expense('paid 700 for internet bill');
      expect(e.amount, 70000);
      expect(e.category, ExpenseCategory.bills);
      expect(e.note, 'Internet bill');
    });

    test('uber 180', () {
      final e = expense('uber 180');
      expect(e.amount, 18000);
      expect(e.category, ExpenseCategory.travel);
      expect(e.note, 'Uber');
    });

    test('currencies, commas, decimals and k', () {
      expect(expense('spent rs 1,200 on shoes').amount, 120000);
      expect(
        expense('spent rs 1,200 on shoes').category,
        ExpenseCategory.shopping,
      );
      expect(expense('I spent ₹99.50 on coffee').amount, 9950);
      expect(
        expense('paid 500 rupees for movie tickets').category,
        ExpenseCategory.fun,
      );
      expect(
        expense('paid 500 rupees for movie tickets').note,
        'Movie tickets',
      );
      expect(expense('spent 2k on groceries').amount, 200000);
      expect(expense('spent 2k on groceries').category, ExpenseCategory.food);
    });

    test('bought X for N, and yesterday', () {
      final e = expense('bought medicine for 120');
      expect(e.amount, 12000);
      expect(e.category, ExpenseCategory.health);
      expect(e.note, 'Medicine');
      expect(expense('spent 300 on dinner yesterday').date, d(12));
    });

    test('unknown category falls back to Other with the words as note', () {
      final e = expense('spent 300 on stuff');
      expect(e.category, ExpenseCategory.other);
      expect(e.note, 'Stuff');
      expect(expense('spent 300').note, '');
    });

    test('"buy groceries" with no amount is a task, not a spend', () {
      expect(parseVoice('buy groceries', now), isA<AddTask>());
    });
  });

  group('habits', () {
    test('water glasses, digits and words', () {
      final h = habit('drank 2 glasses of water');
      expect(h.habitKey, HabitKeys.water);
      expect(h.amount, 2);
      expect(habit('drank two glasses of water').amount, 2);
      expect(habit('had a glass of water').amount, 1);
      expect(habit('I just drank some water').amount, 1);
    });

    test('workout', () {
      for (final said in [
        'done with gym',
        'finished my workout',
        'worked out',
        'went to the gym',
        'did my workout',
        'gym done',
      ]) {
        expect(habit(said).habitKey, HabitKeys.workout, reason: said);
      }
    });

    test('study minutes', () {
      expect(habit('studied for 45 minutes').habitKey, HabitKeys.study);
      expect(habit('studied for 45 minutes').amount, 45);
      expect(habit('studied for an hour').amount, 60);
      expect(habit('studied for 1.5 hours').amount, 90);
      expect(habit('studied for half an hour').amount, 30);
      expect(habit('studied for 2 hours').amount, 120);
      expect(habit('I studied for twenty minutes').amount, 20);
      expect(habit('done studying').amount, isNull); // = mark done
    });

    test('meditate and read', () {
      expect(habit('meditated').habitKey, HabitKeys.meditate);
      expect(habit('did my meditation').habitKey, HabitKeys.meditate);
      expect(habit('read 20 pages').habitKey, HabitKeys.read);
      expect(habit('finished reading').habitKey, HabitKeys.read);
    });

    test('future-tense habits are tasks to plan, not logs', () {
      expect(parseVoice('study for the exam tomorrow', now), isA<AddTask>());
      expect(parseVoice('meditate at 7 pm', now), isA<AddTask>());
    });
  });

  group('mood', () {
    test('feeling great/good/okay/low/bad', () {
      expect(mood('feeling great'), Mood.great);
      expect(mood('feeling good'), Mood.good);
      expect(mood('feeling okay'), Mood.okay);
      expect(mood('feeling low'), Mood.low);
      expect(mood('feeling bad'), Mood.bad);
    });

    test('natural variants', () {
      expect(mood("I'm feeling ok"), Mood.okay);
      expect(mood('I feel really amazing today'), Mood.great);
      expect(mood('feeling a bit down'), Mood.low);
      expect(mood('i am feeling terrible'), Mood.bad);
      expect(mood('Feeling good today.'), Mood.good);
    });

    test('unknown feeling words are not moods', () {
      expect(parseVoice('feeling hungry', now), isNot(isA<SetMood>()));
    });
  });

  group('describe (confirmation text)', () {
    test('task', () {
      expect(
        describeCommand(
          parseVoice(
            'add call the plumber tomorrow at 10 am, high priority',
            now,
          ),
          now,
        ),
        'Task: "Call the plumber" · Tomorrow, 10 am · High priority · Personal',
      );
      // A reminder needs a day to fire, so without one the card doesn't
      // promise a reminder (Edit lets the user add a day).
      expect(
        describeCommand(parseVoice('remind me to pay rent', now), now),
        'Task: "Pay rent" · Personal',
      );
      expect(
        describeCommand(parseVoice('remind me to pay rent tomorrow', now), now),
        'Task: "Pay rent" · Tomorrow · Personal · With reminder',
      );
    });

    test('expense, habit, mood', () {
      expect(
        describeCommand(parseVoice('spent 250 on lunch', now), now),
        'Spend: ₹250 · Food · "Lunch" · Today',
      );
      expect(
        describeCommand(parseVoice('drank 2 glasses of water', now), now),
        'Water: +2 glasses',
      );
      expect(
        describeCommand(parseVoice('studied for 45 minutes', now), now),
        'Study: +45 min',
      );
      expect(
        describeCommand(parseVoice('worked out', now), now),
        'Workout: done today',
      );
      expect(
        describeCommand(parseVoice('feeling great', now), now),
        'Today\'s mood: Great',
      );
    });
  });
}
