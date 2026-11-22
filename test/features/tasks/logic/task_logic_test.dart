import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/tasks/logic/due_label.dart';
import 'package:petal/features/tasks/logic/due_shortcuts.dart';
import 'package:petal/features/tasks/logic/reminder_time.dart';
import 'package:petal/features/tasks/logic/task_filter.dart';
import 'package:petal/features/tasks/logic/task_groups.dart';

/// Friday 13 November 2026.
final today = DateTime(2026, 11, 13);
DateTime d(int day, [int month = 11]) => DateTime(2026, month, day);

var _nextId = 1;
TaskItem task(
  String title, {
  DateTime? due,
  ClockTime? time,
  TaskPriority priority = TaskPriority.medium,
  TaskList list = TaskList.personal,
  bool done = false,
  DateTime? doneAt,
  bool reminder = false,
  DateTime? createdAt,
}) => TaskItem(
  id: _nextId++,
  title: title,
  dueDate: due,
  dueTime: time,
  priority: priority,
  list: list,
  done: done,
  doneAt: doneAt,
  reminder: reminder,
  createdAt: createdAt ?? DateTime(2026, 11, 1),
);

void main() {
  group('groupTasks', () {
    test(
      'puts each task in the right group, in order, skipping empty ones',
      () {
        final groups = groupTasks([
          task('later', due: d(20)),
          task('no date'),
          task('overdue', due: d(10)),
          task('today', due: d(13)),
          task('tomorrow', due: d(14)),
          task('done', due: d(13), done: true),
        ], today);

        expect(groups.keys, [
          TaskGroup.overdue,
          TaskGroup.today,
          TaskGroup.tomorrow,
          TaskGroup.later,
          TaskGroup.noDate,
          TaskGroup.completed,
        ]);
        expect(groups[TaskGroup.overdue]!.single.title, 'overdue');
        expect(groups[TaskGroup.completed]!.single.title, 'done');

        expect(groupTasks([task('x')], today).keys, [TaskGroup.noDate]);
      },
    );

    test('done overdue tasks are Completed, not Overdue', () {
      final groups = groupTasks([task('a', due: d(1), done: true)], today);
      expect(groups.keys, [TaskGroup.completed]);
    });

    test('sorts by time, then untimed, then priority, then age', () {
      final groups = groupTasks([
        task('untimed low', due: today, priority: TaskPriority.low),
        task('untimed high', due: today, priority: TaskPriority.high),
        task('6 pm', due: today, time: const ClockTime(18, 0)),
        task('9 am', due: today, time: const ClockTime(9, 0)),
        task(
          'untimed high older',
          due: today,
          priority: TaskPriority.high,
          createdAt: DateTime(2026),
        ),
      ], today);
      expect(groups[TaskGroup.today]!.map((t) => t.title), [
        '9 am',
        '6 pm',
        'untimed high older',
        'untimed high',
        'untimed low',
      ]);
    });

    test('Later is sorted by date', () {
      final groups = groupTasks([
        task('b', due: d(30)),
        task('a', due: d(16)),
      ], today);
      expect(groups[TaskGroup.later]!.map((t) => t.title), ['a', 'b']);
    });

    test('Completed shows most recently done first', () {
      final groups = groupTasks([
        task('first', done: true, doneAt: DateTime(2026, 11, 12, 8)),
        task('last', done: true, doneAt: DateTime(2026, 11, 13, 8)),
      ], today);
      expect(groups[TaskGroup.completed]!.map((t) => t.title), [
        'last',
        'first',
      ]);
    });

    test('works across a month boundary', () {
      expect(groupOf(task('x', due: d(1, 12)), d(30)), TaskGroup.tomorrow);
      expect(groupOf(task('x', due: d(2, 12)), d(30)), TaskGroup.later);
      expect(groupOf(task('x', due: d(30)), d(1, 12)), TaskGroup.overdue);
    });
  });

  group('TaskFilter', () {
    final work = task('w', list: TaskList.work, due: today);
    final shop = task('s', list: TaskList.shopping, due: d(14));
    final undated = task('u');

    test('list filter', () {
      const f = TaskFilter(list: TaskList.work);
      expect([work, shop, undated].where(f.matches), [work]);
    });

    test('day filter hides undated tasks', () {
      final f = TaskFilter(day: d(14));
      expect([work, shop, undated].where(f.matches), [shop]);
    });

    test('tapping the same day again clears it', () {
      final f = const TaskFilter().toggleDay(today);
      expect(f.day, today);
      expect(f.toggleDay(DateTime(2026, 11, 13, 15)).day, isNull);
      expect(f.toggleDay(d(14)).day, d(14));
    });
  });

  group('week strip', () {
    test('weekOf runs Monday to Sunday', () {
      final week = weekOf(today);
      expect(week.first, d(9));
      expect(week.last, d(15));
      expect(weekOf(d(15)).first, d(9)); // Sunday belongs to the same week
    });

    test('openTasksPerDay counts only open, dated tasks', () {
      final counts = openTasksPerDay([
        task('a', due: today),
        task('b', due: today),
        task('c', due: today, done: true),
        task('d'),
      ]);
      expect(counts, {today: 2});
    });
  });

  group('due shortcuts (today is Friday)', () {
    test('resolve', () {
      expect(resolveShortcut(DueShortcut.today, today), d(13));
      expect(resolveShortcut(DueShortcut.tomorrow, today), d(14));
      expect(resolveShortcut(DueShortcut.weekend, today), d(14)); // Saturday
      expect(resolveShortcut(DueShortcut.nextWeek, today), d(16)); // Monday
      expect(resolveShortcut(DueShortcut.none, today), isNull);
    });

    test('weekend on Saturday or Sunday is today', () {
      expect(resolveShortcut(DueShortcut.weekend, d(14)), d(14));
      expect(resolveShortcut(DueShortcut.weekend, d(15)), d(15));
    });

    test('next week on a Sunday is the next day', () {
      expect(resolveShortcut(DueShortcut.nextWeek, d(15)), d(16));
    });

    test('shortcutFor picks the best chip for a date', () {
      expect(shortcutFor(null, today), DueShortcut.none);
      expect(shortcutFor(d(13), today), DueShortcut.today);
      expect(shortcutFor(d(14), today), DueShortcut.tomorrow); // not Weekend
      expect(shortcutFor(d(16), today), DueShortcut.nextWeek);
      expect(shortcutFor(d(25), today), DueShortcut.pick);
    });
  });

  group('dueLabel', () {
    test('relative names', () {
      expect(dueLabel(d(13), null, today), 'Today');
      expect(
        dueLabel(d(14), const ClockTime(18, 30), today),
        'Tomorrow, 6:30 pm',
      );
      expect(dueLabel(d(12), null, today), 'Yesterday');
      expect(dueLabel(d(17), null, today), 'Tuesday');
      expect(dueLabel(d(23), null, today), 'Mon 23 Nov');
      expect(dueLabel(d(1), null, today), 'Sun 1 Nov');
      expect(dueLabel(null, null, today), '');
    });

    test('ClockTime.format', () {
      expect(const ClockTime(0, 0).format(), '12 am');
      expect(const ClockTime(12, 0).format(), '12 pm');
      expect(const ClockTime(18, 5).format(), '6:05 pm');
    });
  });

  group('reminderTimeFor', () {
    final now = DateTime(2026, 11, 13, 8, 0);

    test('15 minutes before a timed task', () {
      final t = task(
        'a',
        due: d(13),
        time: const ClockTime(10, 0),
        reminder: true,
      );
      expect(reminderTimeFor(t, 15, now), DateTime(2026, 11, 13, 9, 45));
    });

    test('9 am for a task with a date but no time', () {
      final t = task('a', due: d(14), reminder: true);
      expect(reminderTimeFor(t, 15, now), DateTime(2026, 11, 14, 9, 0));
    });

    test('none when off, done, undated or already past', () {
      expect(reminderTimeFor(task('a', due: d(14)), 15, now), isNull);
      expect(
        reminderTimeFor(
          task('a', due: d(14), reminder: true, done: true),
          15,
          now,
        ),
        isNull,
      );
      expect(reminderTimeFor(task('a', reminder: true), 15, now), isNull);
      expect(
        reminderTimeFor(
          task('a', due: d(13), time: const ClockTime(8, 10), reminder: true),
          15,
          now,
        ),
        isNull,
      ); // 7:55 has passed
    });

    test('reminderHint', () {
      expect(reminderHint(const ClockTime(10, 0), 15), '15 min before');
      expect(reminderHint(const ClockTime(10, 0), 0), 'At 10 am');
      expect(reminderHint(null, 15), 'At 9 am that day');
    });
  });

  group('TaskDraft', () {
    test('clearing the date also clears time and reminder', () {
      final draft = TaskDraft(
        title: 'x',
        dueDate: today,
        dueTime: const ClockTime(9, 0),
        reminder: true,
      ).copyWith(clearDueDate: true);
      expect(draft.dueTime, isNull);
      expect(draft.reminder, isFalse);
    });

    test('needs a non-blank title', () {
      expect(const TaskDraft(title: '  ').isValid, isFalse);
      expect(const TaskDraft(title: 'a').isValid, isTrue);
    });
  });
}
