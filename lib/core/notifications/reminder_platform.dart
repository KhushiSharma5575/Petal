import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// What the app needs from the phone's notification system. The real
/// implementation is [LocalReminderPlatform]; tests use a fake.
abstract class ReminderPlatform {
  /// Schedules (or replaces) notification [id] for [when].
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Schedules (or replaces) notification [id] to repeat every day at
  /// [hour]:[minute] (used for water reminders).
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  /// Ids of notifications that are scheduled but haven't fired yet.
  Future<Set<int>> pendingIds();

  /// Ids of notifications that already fired and are still in the
  /// notification tray.
  Future<Set<int>> shownIds();

  /// Asks for permission to post notifications (Android 13+). Returns
  /// whether notifications are allowed.
  Future<bool> requestPermission();

  /// Whether reminders can fire at the exact minute.
  Future<bool> canUseExactTiming();

  /// Opens the system screen where the user can allow exact alarms.
  Future<void> requestExactTiming();
}

/// [ReminderPlatform] backed by flutter_local_notifications. Everything runs
/// on the phone; nothing is sent anywhere.
class LocalReminderPlatform implements ReminderPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    channelDescription:
        'Reminders for tasks you asked Petal to remind you about.',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_petal',
    color: Color(0xFF5B3FA0),
    category: AndroidNotificationCategory.reminder,
  );

  Future<void> _ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown zone: keep the default. Scheduling still fires at the right
      // instant because we convert from an absolute DateTime.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_petal'),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    await _ensureReady();
    final exact = await canUseExactTiming();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(android: _channel),
      // Without the exact-alarm permission Android may delay by a few
      // minutes; better late than never.
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'task:$id',
    );
  }

  static const _waterChannel = AndroidNotificationDetails(
    'water_reminders',
    'Water reminders',
    channelDescription: 'Gentle nudges to drink water during the day.',
    importance: Importance.defaultImportance,
    icon: 'ic_stat_petal',
    color: Color(0xFF5B3FA0),
    category: AndroidNotificationCategory.reminder,
  );

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _ensureReady();
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: first,
      notificationDetails: const NotificationDetails(android: _waterChannel),
      // A water nudge a few minutes late is fine, so never ask for exact
      // alarms here.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'water',
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureReady();
    await _plugin.cancel(id: id);
  }

  @override
  Future<Set<int>> pendingIds() async {
    await _ensureReady();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toSet();
  }

  @override
  Future<Set<int>> shownIds() async {
    await _ensureReady();
    final shown = await _plugin.getActiveNotifications();
    return {for (final n in shown) ?n.id};
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> canUseExactTiming() async {
    await _ensureReady();
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestExactTiming() async {
    await _ensureReady();
    await _android?.requestExactAlarmsPermission();
  }
}
