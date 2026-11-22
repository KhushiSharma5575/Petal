import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/tasks/state/reminder_sync.dart';

import '../../../helpers/fake_reminder_platform.dart';

void main() {
  final now = DateTime(2026, 11, 13, 8, 0);
  late FakeReminderPlatform platform;
  late ReminderSync sync;

  setUp(() {
    platform = FakeReminderPlatform();
    sync = ReminderSync(platform);
  });

  TaskItem task(
    int id, {
    bool reminder = true,
    bool done = false,
    ClockTime? time,
  }) => TaskItem(
    id: id,
    title: 'Task $id',
    dueDate: DateTime(2026, 11, 13),
    dueTime: time ?? const ClockTime(10, 0),
    reminder: reminder,
    done: done,
    list: TaskList.work,
    createdAt: now,
  );

  test(
    'schedules reminders with lead time, title and a helpful body',
    () async {
      await sync.sync([task(1), task(2, reminder: false)], 15, now);
      expect(platform.scheduled.keys, [1]);
      final r = platform.scheduled[1]!;
      expect(r.when, DateTime(2026, 11, 13, 9, 45));
      expect(r.title, 'Task 1');
      expect(r.body, 'Today, 10 am · Work');
    },
  );

  test(
    'cancels reminders for tasks that were done, turned off or deleted',
    () async {
      await sync.sync([task(1), task(2), task(3)], 15, now);
      await sync.sync([task(1, done: true), task(2, reminder: false)], 15, now);
      expect(platform.scheduled, isEmpty);
    },
  );

  test('re-schedules when the time or lead changes', () async {
    await sync.sync([task(1)], 15, now);
    await sync.sync([task(1, time: const ClockTime(11, 0))], 30, now);
    expect(platform.scheduled[1]!.when, DateTime(2026, 11, 13, 10, 30));
  });

  test('back-to-back syncs run in order', () async {
    final a = sync.sync([task(1)], 15, now);
    final b = sync.sync([], 15, now);
    await Future.wait([a, b]);
    expect(platform.scheduled, isEmpty);
  });
}
