import 'package:petal/core/notifications/reminder_platform.dart';

/// In-memory stand-in for the phone's notification system.
class FakeReminderPlatform implements ReminderPlatform {
  /// id -> (when, title, body)
  final scheduled = <int, ({DateTime when, String title, String body})>{};
  bool permissionGranted = true;
  bool exactAllowed = true;
  int permissionRequests = 0;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    scheduled[id] = (when: when, title: title, body: body);
  }

  /// id -> (hour, minute) for daily repeating reminders.
  final daily = <int, (int, int)>{};

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    daily[id] = (hour, minute);
  }

  /// Notifications that already fired and sit in the tray.
  final shown = <int>{};

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    daily.remove(id);
    shown.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async => {...scheduled.keys, ...daily.keys};

  @override
  Future<Set<int>> shownIds() async => {...shown};

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> canUseExactTiming() async => exactAllowed;

  @override
  Future<void> requestExactTiming() async {}
}
