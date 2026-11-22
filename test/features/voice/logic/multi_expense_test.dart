import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/features/voice/logic/voice_parser.dart';
import 'package:petal/features/voice/state/speech_service.dart';

/// Friday 13 November 2026, 10:00.
final now = DateTime(2026, 11, 13, 10, 0);

List<ExpenseDraft> spends(String said) {
  final c = parseVoice(said, now);
  expect(c, isA<AddExpenses>(), reason: '"$said" should be expenses, got $c');
  return (c as AddExpenses).drafts;
}

void main() {
  group('several expenses at once', () {
    test('with commas and "and"', () {
      final s = spends('spent 100 on food, 200 on travel and 50 on coffee');
      expect(s.map((e) => e.amount), [10000, 20000, 5000]);
      expect(s.map((e) => e.category), [
        ExpenseCategory.food,
        ExpenseCategory.travel,
        ExpenseCategory.food,
      ]);
      expect(s.map((e) => e.note), ['Food', 'Travel', 'Coffee']);
    });

    test('speech without commas', () {
      final s = spends('i spent 250 on lunch 180 on uber and 499 on netflix');
      expect(s.map((e) => e.amount), [25000, 18000, 49900]);
      expect(s.map((e) => e.category), [
        ExpenseCategory.food,
        ExpenseCategory.travel,
        ExpenseCategory.fun,
      ]);
    });

    test('words before the amounts', () {
      final s = spends('lunch 250, uber 180 and coffee 60');
      expect(s.map((e) => e.amount), [25000, 18000, 6000]);
      expect(s.map((e) => e.note), ['Lunch', 'Uber', 'Coffee']);
    });

    test('number words', () {
      final s = spends('paid fifty for tea and twenty for parking');
      expect(s.map((e) => e.amount), [5000, 2000]);
    });

    test('a day said once applies to all', () {
      final s = spends('yesterday i spent 100 on food and 40 on bus');
      expect(s.every((e) => e.date == DateTime(2026, 11, 12)), isTrue);
    });

    test('the confirm card lists each one with a total', () {
      final c = parseVoice('spent 100 on food and 200 on travel', now);
      final text = describeCommand(c, now);
      expect(text, startsWith('2 spends, ₹300 in total'));
      expect(text, contains('₹100 · Food'));
      expect(text, contains('₹200 · Travel'));
    });

    test('one amount is still a single expense', () {
      expect(parseVoice('spent 250 on lunch', now), isA<AddExpense>());
    });

    test('tasks with numbers stay tasks', () {
      expect(parseVoice('call 2 people at 5', now), isA<AddTask>());
      expect(parseVoice('add buy 2 kg rice and 3 kg dal', now), isA<AddTask>());
    });
  });

  group('ways people say a spend', () {
    ExpenseDraft one(String said) {
      final c = parseVoice(said, now);
      expect(c, isA<AddExpense>(), reason: '"$said" should be a spend, got $c');
      return (c as AddExpense).draft;
    }

    test('"add" + amount is money, not a task', () {
      expect(one('add 200 for lunch').amount, 20000);
      expect(one('add expense 50 for tea').note, 'Tea');
      expect(one('add 500 rupees petrol').category, ExpenseCategory.travel);
      expect(one('add an expense of 300 for groceries').amount, 30000);
    });

    test('"add task" and reminders stay tasks', () {
      expect(parseVoice('add task pay 500 rent', now), isA<AddTask>());
      expect(
        parseVoice('remind me to pay 700 internet bill friday', now),
        isA<AddTask>(),
      );
    });

    test('cue in the middle or with "I have"', () {
      final y = one('yesterday i spent 120 on snacks');
      expect(y.amount, 12000);
      expect(y.date, DateTime(2026, 11, 12));
      expect(one('i have spent 90 on coffee').note, 'Coffee');
      expect(one('for lunch i paid 250').amount, 25000);
      expect(one('expenses 40 for auto').category, ExpenseCategory.travel);
    });

    test('money words without "spent"', () {
      final e = one('200 rupees for dinner with my friends');
      expect(e.amount, 20000);
      expect(e.note, 'Dinner with my friends');
      expect(one('rs 99 on milk').category, ExpenseCategory.food);
    });

    test('hundreds and thousands in words', () {
      expect(one('spent two hundred on lunch').amount, 20000);
      expect(one('spent two hundred and fifty on lunch').amount, 25000);
      expect(one('paid a hundred for parking').amount, 10000);
      expect(one('paid one thousand five hundred for shoes').amount, 150000);
      expect(one('spent ninety on chai').amount, 9000);
    });

    test('times, dates and quantities are never rupees', () {
      final lunch = parseVoice('lunch with priya at 1 pm', now);
      expect(lunch, isA<AddTask>());
      expect(parseVoice('add 2 eggs to shopping list', now), isA<AddTask>());
      final meeting = parseVoice('meeting with client at 4 30 pm', now);
      expect((meeting as AddTask).draft.dueTime?.minute, 30);
      expect(meeting.draft.dueTime?.hour, 16);
      expect(one('spent 100 on food at 5 pm').amount, 10000);
    });

    test('no "spent" needed for two named items', () {
      final s = spends('coffee 120 and sandwich 180');
      expect(s.map((e) => e.amount), [12000, 18000]);
    });

    test('"spended", "payed" and other everyday ways', () {
      final e = one('i spended 250 for lunch');
      expect(e.amount, 25000);
      expect(e.note, 'Lunch');
      expect(e.category, ExpenseCategory.food);
      expect(one('I spended two hundred fifty for lunch').amount, 25000);
      expect(one('payed 40 for auto').note, 'Auto');
      expect(one('i spent it 120 on snacks').note, 'Snacks');
      expect(one('spent around 300 on groceries').amount, 30000);
      expect(one('buyed a shirt for 799').amount, 79900);
    });

    test('gave money', () {
      expect(one('gave 500 to mom').amount, 50000);
    });

    test('several with "add"', () {
      final s = spends('add 100 for food and 200 for travel');
      expect(s.map((e) => e.amount), [10000, 20000]);
    });
  });

  group('joining speech chunks', () {
    test('keeps earlier chunks when the recognizer starts over', () {
      final j = TranscriptJoiner();
      j.add('spent 100');
      j.add('spent 100 on food', chunkDone: true);
      j.add('200');
      j.add('200 on travel', chunkDone: true);
      expect(
        j.add('200 on travel', isFinal: true),
        'spent 100 on food 200 on travel',
      );
    });

    test('final result with only the last chunk', () {
      final j = TranscriptJoiner();
      j.add('spent 100 on food', chunkDone: true);
      j.add('and 50');
      expect(
        j.add('and 50 on coffee', isFinal: true),
        'spent 100 on food and 50 on coffee',
      );
    });

    test('recognizers that repeat everything are not doubled', () {
      final j = TranscriptJoiner();
      j.add('spent 100 on food', chunkDone: true);
      expect(
        j.add('spent 100 on food and 50 on tea', isFinal: true),
        'spent 100 on food and 50 on tea',
      );
    });

    test('a restart without a chunk marker is still kept', () {
      final j = TranscriptJoiner();
      j.add('spent 100 on food and');
      j.add('200');
      expect(j.text, 'spent 100 on food and 200');
    });

    test('plain single phrase', () {
      final j = TranscriptJoiner();
      j.add('add milk');
      expect(j.add('add milk tomorrow', isFinal: true), 'add milk tomorrow');
    });
  });
}
