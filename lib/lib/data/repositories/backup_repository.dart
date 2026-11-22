import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// A backup file that can't be restored, with a message for the user.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a restore brought back, for the confirmation message.
class RestoreSummary {
  const RestoreSummary({
    required this.tasks,
    required this.expenses,
    required this.moods,
    required this.createdAt,
  });
  final int tasks;
  final int expenses;
  final int moods;

  /// When the backup was made (null if the file didn't say).
  final DateTime? createdAt;
}

/// Full backup and restore of every table as JSON.
///
/// Files stay on the phone unless the user moves them.
class BackupRepository {
  BackupRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static const formatVersion = 1;

  Future<List<int>> buildJson() async {
    List<Map<String, dynamic>> rows(List<dynamic> data) => [
      for (final r in data) (r as dynamic).toJson() as Map<String, dynamic>,
    ];
    final backup = {
      'app': 'Petal',
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'createdAt': _now().toIso8601String(),
      'tables': {
        'tasks': rows(await _db.select(_db.tasks).get()),
        'subtasks': rows(await _db.select(_db.subtasks).get()),
        'habits': rows(await _db.select(_db.habits).get()),
        'habit_logs': rows(await _db.select(_db.habitLogs).get()),
        'moods': rows(await _db.select(_db.moods).get()),
        'weekly_plan': rows(await _db.select(_db.weeklyPlan).get()),
        'expenses': rows(await _db.select(_db.expenses).get()),
        'budgets': rows(await _db.select(_db.budgets).get()),
        'settings': rows(await _db.select(_db.settings).get()),
      },
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(backup));
  }

  /// Replaces ALL data with the backup in [bytes].
  ///
  /// The whole file is read and checked first; only if every row is valid
  /// does anything change, and then in one transaction (all or nothing).
  /// A table missing from an older backup is left as it is.
  Future<RestoreSummary> restore(List<int> bytes) async {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw BackupFormatException('That file isn\'t a Petal backup.');
    }
    if (json['app'] != 'Petal' || json['tables'] is! Map) {
      throw BackupFormatException('That file isn\'t a Petal backup.');
    }
    final fileFormat = json['formatVersion'];
    final fileSchema = json['schemaVersion'];
    if (fileFormat is! int ||
        fileFormat > formatVersion ||
        (fileSchema is int && fileSchema > _db.schemaVersion)) {
      throw BackupFormatException(
        'This backup was made by a newer version of Petal. Update Petal, '
        'then try again.',
      );
    }
    final tables = json['tables'] as Map<String, dynamic>;

    List<T>? parse<T>(String name, T Function(Map<String, dynamic>) fromJson) {
      final list = tables[name];
      if (list == null) return null;
      if (list is! List) throw BackupFormatException('The backup is damaged.');
      return [
        for (final r in list) fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    }

    // Parse everything up front so a broken file can't half-restore.
    final List<TaskRow>? tasks;
    final List<SubtaskRow>? subtasks;
    final List<HabitRow>? habits;
    final List<HabitLogRow>? logs;
    final List<MoodRow>? moods;
    final List<WeeklyPlanRow>? plan;
    final List<ExpenseRow>? expenses;
    final List<BudgetRow>? budgets;
    final List<SettingRow>? settings;
    try {
      tasks = parse('tasks', TaskRow.fromJson);
      subtasks = parse('subtasks', SubtaskRow.fromJson);
      habits = parse('habits', HabitRow.fromJson);
      logs = parse('habit_logs', HabitLogRow.fromJson);
      moods = parse('moods', MoodRow.fromJson);
      plan = parse('weekly_plan', WeeklyPlanRow.fromJson);
      expenses = parse('expenses', ExpenseRow.fromJson);
      budgets = parse('budgets', BudgetRow.fromJson);
      settings = parse('settings', SettingRow.fromJson);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw BackupFormatException('The backup is damaged.');
    }

    await _db.transaction(() async {
      // Children before parents when deleting, parents first when inserting.
      Future<void> clear(TableInfo table, bool replace) async {
        if (replace) await _db.delete(table).go();
      }

      await clear(_db.subtasks, subtasks != null);
      await clear(_db.tasks, tasks != null);
      await clear(_db.habitLogs, logs != null);
      await clear(_db.habits, habits != null);
      await clear(_db.moods, moods != null);
      await clear(_db.weeklyPlan, plan != null);
      await clear(_db.expenses, expenses != null);
      await clear(_db.budgets, budgets != null);
      await clear(_db.settings, settings != null);

      await _db.batch((b) {
        if (tasks != null) b.insertAll(_db.tasks, tasks);
        if (subtasks != null) b.insertAll(_db.subtasks, subtasks);
        if (habits != null) b.insertAll(_db.habits, habits);
        if (logs != null) b.insertAll(_db.habitLogs, logs);
        if (moods != null) b.insertAll(_db.moods, moods);
        if (plan != null) b.insertAll(_db.weeklyPlan, plan);
        if (expenses != null) b.insertAll(_db.expenses, expenses);
        if (budgets != null) b.insertAll(_db.budgets, budgets);
        if (settings != null) b.insertAll(_db.settings, settings);
        // Restoring is never a first launch: don't show the welcome again.
        b.insert(
          _db.settings,
          SettingsCompanion.insert(key: 'welcome_seen', value: 'true'),
          mode: InsertMode.insertOrReplace,
        );
      });
    });

    return RestoreSummary(
      tasks: tasks?.length ?? 0,
      expenses: expenses?.length ?? 0,
      moods: moods?.length ?? 0,
      createdAt: DateTime.tryParse('${json['createdAt']}'),
    );
  }
}
