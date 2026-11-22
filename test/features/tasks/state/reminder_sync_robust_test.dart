import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/clock_time.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/tasks/state/reminder_sync.dart';

import '../../../helpers/fake_reminder_platform.dart';

/// Throws on the first schedule call, like the plugin does when a time has
/// just passed.
class _FlakyPlatform extends FakeReminderPlatform {
  bool failNext = true;
  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (failNext) {
      failNext = false;
      throw ArgumentError('Must be a date in the future');
    }
    return super.schedule(id: id, when: when, title: title, body: body);
  }
}

void main() {
  final now = DateTime(2026, 11, 13, 22, 0);

  TaskItem task(int id, DateTime day, [ClockTime? time]) => TaskItem(
    id: id,
    title: 'Task $id',
    dueDate: day,
    dueTime: time,
    reminder: true,
    createdAt: now,
  );

  test('one failed reminder never stops later syncs', () async {
    final platform = _FlakyPlatform();
    final sync = ReminderSync(platform);
    final tomorrow = DateTime(2026, 11, 14);
    await sync.sync([task(1, tomorrow), task(2, tomorrow)], 15, now);
    expect(platform.scheduled.keys, [2]); // 1 failed, 2 still scheduled
    await sync.sync([task(1, tomorrow), task(3, tomorrow)], 15, now);
    expect(platform.scheduled.keys.toSet(), {1, 3});
  });

  test('a reminder that fires tomorrow says "Today", not "Tomorrow"', () async {
    final platform = FakeReminderPlatform();
    await ReminderSync(
      platform,
    ).sync([task(1, DateTime(2026, 11, 14), const ClockTime(18, 0))], 15, now);
    expect(platform.scheduled[1]!.body, startsWith('Today, 6 pm'));
  });

  test(
    'a shown reminder leaves the tray once its task is done or deleted',
    () async {
      final platform = FakeReminderPlatform()..shown.addAll({1, 2, 3, 900001});
      final today = DateTime(2026, 11, 13);
      final done = TaskItem(
        id: 1,
        title: 'Done one',
        dueDate: today,
        reminder: true,
        done: true,
        createdAt: now,
      );
      // 1 is done, 2 still open, 3 deleted; 900001 is a water reminder.
      await ReminderSync(platform).sync([done, task(2, today)], 15, now);
      expect(platform.shown, {2, 900001});
    },
  );

  test('switching water reminders 2h -> Off quickly leaves none', () async {
    final platform = FakeReminderPlatform();
    final first = syncWaterReminders(platform, 2);
    final second = syncWaterReminders(platform, 0);
    await Future.wait([first, second]);
    expect(platform.daily, isEmpty);
  });
}
