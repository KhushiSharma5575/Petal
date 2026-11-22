import '../db/app_database.dart';

/// Keys for the `settings` table, in one place so they can't be mistyped.
abstract final class SettingKeys {
  /// Minutes before a task's due time to send its reminder.
  static const reminderLeadMinutes = 'reminder_lead_minutes';

  /// Set once debug sample data has been added, so it's never added twice.
  static const sampleDataSeeded = 'sample_data_seeded';

  /// Same, for the habit/mood/plan samples added in Phase 3.
  static const sampleHabitsSeeded = 'sample_habits_seeded';

  /// Same, for the expense/budget samples added in Phase 4.
  static const sampleMoneySeeded = 'sample_money_seeded';

  /// The user's first name, shown on Me. Empty if not set.
  static const userName = 'user_name';

  /// PetalAccent.name: lavender | peach | mint.
  static const themeAccent = 'theme_accent';

  /// Water reminder interval in hours (0 = off). Reminders run 9am-9pm.
  static const waterReminderHours = 'water_reminder_hours';

  /// 'true' once the first-launch welcome slides were finished.
  static const welcomeSeen = 'welcome_seen';

  /// 'false' turns off "earn your streaks" (Workout needs a step session,
  /// Study a face-down focus timer). On unless switched off.
  static const earnStreaks = 'earn_streaks';

  /// Steps a workout session needs (walk).
  static const workoutSteps = 'workout_steps';

  /// The workout session in progress: `start ISO|base steps (or empty)`.
  static const workoutSession = 'workout_session';
}

/// Defaults used when a setting has never been saved.
abstract final class SettingDefaults {
  static const reminderLeadMinutes = 15;
  static const waterReminderHours = 0;
  static const workoutSteps = 1000;
}

/// Simple key/value settings stored on the device.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) {
    return (_db.select(_db.settings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> set(String key, String value) {
    return _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  Stream<int> watchInt(String key, int fallback) =>
      watch(key).map((v) => int.tryParse(v ?? '') ?? fallback);

  Future<int> getInt(String key, int fallback) async =>
      int.tryParse(await get(key) ?? '') ?? fallback;

  Future<bool> getFlag(String key) async => await get(key) == 'true';

  Future<void> setFlag(String key, bool value) => set(key, value.toString());
}
