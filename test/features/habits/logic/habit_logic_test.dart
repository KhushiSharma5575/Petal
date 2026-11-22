import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/features/habits/logic/habit_logic.dart';

void main() {
  final today = DateTime(2026, 11, 13);
  DateTime d(int day) => DateTime(2026, 11, day);

  const check = Habit(
    id: 1,
    key: 'read',
    name: 'Read',
    type: HabitType.check,
    goal: 1,
  );
  const water = Habit(
    id: 2,
    key: 'water',
    name: 'Water',
    type: HabitType.count,
    goal: 8,
  );
  const study = Habit(
    id: 3,
    key: 'study',
    name: 'Study',
    type: HabitType.minutes,
    goal: 120,
  );

  group('isDone', () {
    test('check habits need any value', () {
      expect(isDone(check, 0), isFalse);
      expect(isDone(check, 1), isTrue);
    });
    test('count and minute habits need the goal', () {
      expect(isDone(water, 7), isFalse);
      expect(isDone(water, 8), isTrue);
      expect(isDone(study, 119), isFalse);
      expect(isDone(study, 150), isTrue);
    });
  });

  test('progressOf is clamped to 0..1', () {
    expect(progressOf(study, 60), 0.5);
    expect(progressOf(study, 300), 1.0);
    expect(progressOf(water, 0), 0.0);
  });

  group('streakOf', () {
    test('counts back from today when today is done', () {
      final h = HabitWithLogs(check, {d(13): 1, d(12): 1, d(11): 1, d(9): 1});
      expect(streakOf(h, today), 3);
    });

    test('an unfinished today does not break the streak', () {
      final h = HabitWithLogs(check, {d(12): 1, d(11): 1});
      expect(streakOf(h, today), 2);
    });

    test('a missed yesterday resets to 0', () {
      final h = HabitWithLogs(check, {d(11): 1, d(10): 1});
      expect(streakOf(h, today), 0);
    });

    test('partial water days do not count', () {
      final h = HabitWithLogs(water, {d(13): 8, d(12): 5, d(11): 8});
      expect(streakOf(h, today), 1);
    });

    test('works across a month boundary', () {
      final h = HabitWithLogs(check, {
        DateTime(2026, 12, 1): 1,
        DateTime(2026, 11, 30): 1,
        DateTime(2026, 11, 29): 1,
      });
      expect(streakOf(h, DateTime(2026, 12, 1)), 3);
    });
  });

  test('dayProgress counts done habits out of active ones', () {
    final habits = [
      HabitWithLogs(check, {today: 1}),
      HabitWithLogs(water, {today: 3}),
      HabitWithLogs(study, {today: 120}),
      const HabitWithLogs(
        Habit(
          id: 9,
          key: 'x',
          name: 'Old',
          type: HabitType.check,
          goal: 1,
          active: false,
        ),
        {},
      ),
    ];
    expect(dayProgress(habits, today), (2, 3));
  });

  group('water', () {
    test('litres', () {
      expect(litresText(0), '0 L');
      expect(litresText(5), '1.9 L');
      expect(litresText(8), '3 L');
    });

    test(
      'tapping a glass fills up to it; tapping the last full one empties it',
      () {
        expect(waterAfterTap(0, 2), 3); // tap 3rd glass
        expect(waterAfterTap(3, 2), 2); // tap it again
        expect(waterAfterTap(3, 6), 7);
        expect(waterAfterTap(5, 0), 1); // tap first glass to go back to 1
      },
    );
  });
}
