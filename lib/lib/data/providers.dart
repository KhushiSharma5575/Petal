import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/clock.dart';
import 'db/app_database.dart';
import 'repositories/backup_repository.dart';
import 'repositories/expense_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/mood_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/task_repository.dart';

/// The single database for the app. Tests override this with an in-memory
/// database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.onDevice();
  ref.onDispose(db.close);
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(databaseProvider));
});

final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  return MoodRepository(ref.watch(databaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});
