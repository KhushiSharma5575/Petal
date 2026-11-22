import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/file_saver.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/habit.dart';
import '../../../data/models/mood.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/backup_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/sample/demo_data.dart';
import '../../habits/logic/habit_logic.dart';
import '../../habits/state/habits_providers.dart';
import '../../money/state/money_providers.dart';
import '../../tasks/state/reminder_sync.dart';
import '../../tasks/state/tasks_providers.dart';
import '../logic/insights.dart';
import '../logic/week_snapshot.dart';

/// The user's name ('' when not set).
final userNameProvider = StreamProvider<String>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.userName)
      .map((v) => v ?? '');
});

/// Water reminder interval in hours (0 = off).
final waterReminderHoursProvider = StreamProvider<int>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchInt(
        SettingKeys.waterReminderHours,
        SettingDefaults.waterReminderHours,
      );
});

/// Watched by the app root: keeps the daily water reminders in line with the
/// setting.
final waterReminderRunnerProvider = Provider<void>((ref) {
  final hours = ref.watch(waterReminderHoursProvider).value;
  if (hours == null) return;
  syncWaterReminders(ref.read(reminderPlatformProvider), hours);
});

/// Mon-Sun workout / study plan.
final weeklyPlanProvider = StreamProvider<Map<int, PlanDay>>((ref) {
  return ref.watch(habitRepositoryProvider).watchPlan();
});

/// "This week so far" numbers for the Me header. Null while loading.
final weekSnapshotProvider = Provider<WeekSnapshot?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  final habits = ref.watch(habitsProvider).value;
  final expenses = ref.watch(expensesProvider).value;
  if (tasks == null || habits == null || expenses == null) return null;
  return weekSnapshot(
    tasks: tasks,
    habits: habits,
    expenses: expenses,
    today: ref.watch(todayProvider),
  );
});

/// Moods of the last [insightDays] days, live (for insights and the week).
final recentMoodsProvider = StreamProvider<Map<DateTime, Mood>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(moodRepositoryProvider)
      .watchBetween(addDays(today, -insightDays), today);
});

/// What Petal noticed in your data, strongest first. Null while loading.
final insightsProvider = Provider<List<String>?>((ref) {
  final habits = ref.watch(habitsProvider).value;
  final moods = ref.watch(recentMoodsProvider).value;
  final expenses = ref.watch(expensesProvider).value;
  if (habits == null || moods == null || expenses == null) return null;
  return findInsights(
    habits: habits,
    moods: moods,
    expenses: expenses,
    today: ref.watch(todayProvider),
  );
});

/// Which of the three Me sections is showing.
enum MeSection {
  habits('Habits'),
  mood('Mood'),
  settings('Settings');

  const MeSection(this.label);
  final String label;
}

class MeSectionNotifier extends Notifier<MeSection> {
  @override
  MeSection build() => MeSection.habits;
  void select(MeSection s) => state = s;
}

final meSectionProvider = NotifierProvider<MeSectionNotifier, MeSection>(
  MeSectionNotifier.new,
);

/// First day of the month shown in the mood calendar.
class MoodMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final t = ref.watch(todayProvider);
    return DateTime(t.year, t.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  /// Never past the current month.
  void next() {
    final t = ref.read(todayProvider);
    final n = DateTime(state.year, state.month + 1);
    if (!n.isAfter(DateTime(t.year, t.month))) state = n;
  }
}

final moodMonthProvider = NotifierProvider<MoodMonthNotifier, DateTime>(
  MoodMonthNotifier.new,
);

final moodsInMonthProvider = StreamProvider<Map<DateTime, Mood>>((ref) {
  final m = ref.watch(moodMonthProvider);
  return ref
      .watch(moodRepositoryProvider)
      .watchBetween(m, DateTime(m.year, m.month + 1, 0));
});

/// Actions for the Me screen.
class MeController {
  MeController(this._ref);
  final Ref _ref;

  SettingsRepository get _settings => _ref.read(settingsRepositoryProvider);

  /// Test builds only: replaces data with the demo set (see demo_data).
  Future<void> loadDemo() =>
      loadDemoData(_ref.read(databaseProvider), _ref.read(clockProvider)());

  Future<void> setName(String name) =>
      _settings.set(SettingKeys.userName, name.trim());

  Future<void> setPlan(PlanDay day) =>
      _ref.read(habitRepositoryProvider).setPlan(day);

  Future<void> setHabitGoal(String key, int goal) =>
      _ref.read(habitRepositoryProvider).setGoal(key, goal);

  Future<void> setReminderLead(int minutes) =>
      _settings.set(SettingKeys.reminderLeadMinutes, '$minutes');

  /// Returns false if notifications are blocked (so the UI can explain).
  Future<bool> setWaterReminder(int everyHours) async {
    if (everyHours > 0) {
      final allowed = await _ref
          .read(reminderPlatformProvider)
          .requestPermission();
      if (!allowed) return false;
    }
    await _settings.set(SettingKeys.waterReminderHours, '$everyHours');
    return true;
  }

  Future<void> setMood(DateTime day, Mood? mood) =>
      _ref.read(moodRepositoryProvider).setMood(day, mood);

  /// Ticks or unticks a habit on a past day (or today) from the week grid.
  /// Count/minute habits flip between 0 and their goal.
  Future<void> toggleHabitDay(HabitWithLogs h, DateTime day) {
    final d = dateOnly(day);
    final done = isDone(h.habit, h.valueOn(d));
    return _ref
        .read(habitRepositoryProvider)
        .setValue(h.habit.id, d, done ? 0 : h.habit.goal);
  }

  /// Writes a full JSON backup to Downloads.
  Future<ExportResult> backup() async {
    try {
      final bytes = await _ref.read(backupRepositoryProvider).buildJson();
      final where = await _ref
          .read(fileSaverProvider)
          .saveToDownloads(
            name: 'petal-backup-${toIsoDate(_ref.read(todayProvider))}.json',
            mimeType: 'application/json',
            bytes: bytes,
          );
      return where == null ? const ExportCancelled() : ExportSaved(where);
    } on FileSaveException catch (e) {
      return ExportFailed(e.message);
    }
  }

  /// Lets the user pick a backup file and replaces all data with it.
  /// Returns a message for the snackbar, or null if they cancelled.
  Future<String?> restore() async {
    try {
      final bytes = await _ref.read(fileSaverProvider).pickFile();
      if (bytes == null) return null;
      final s = await _ref.read(backupRepositoryProvider).restore(bytes);
      final when = s.createdAt == null
          ? ''
          : ' from ${toIsoDate(s.createdAt!.toLocal())}';
      return 'Restored$when: ${s.tasks} tasks, ${s.expenses} spends, '
          '${s.moods} moods.';
    } on FileSaveException catch (e) {
      return 'Couldn\'t open the file: ${e.message}';
    } on BackupFormatException catch (e) {
      return e.message;
    } catch (_) {
      // E.g. a hand-edited file whose parts don't fit together. The restore
      // runs in one transaction, so nothing was changed.
      return 'That backup file is damaged, so nothing was changed.';
    }
  }
}

final meControllerProvider = Provider<MeController>(MeController.new);
