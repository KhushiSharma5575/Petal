import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables. Only the repositories in lib/data/repositories use these directly.
// More tables (habits, moods, expenses...) are added in later phases with a
// schema migration.
// ---------------------------------------------------------------------------

@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Calendar day as "YYYY-MM-DD" (not a timestamp, so it never shifts with
  /// time zones). Null = no date.
  TextColumn get dueDate => text().nullable()();

  /// Minutes after midnight. Null = no time.
  IntColumn get dueTime => integer().nullable()();

  /// TaskPriority.name: high | medium | low.
  TextColumn get priority => text().withDefault(const Constant('medium'))();

  /// TaskList.name: work | personal | study | shopping.
  TextColumn get listName =>
      text().named('list').withDefault(const Constant('personal'))();
  BoolColumn get reminder => boolean().withDefault(const Constant(false))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get repeatRule => text().nullable()();
}

@DataClassName('SubtaskRow')
class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text().named('text')();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Simple key/value app settings.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// --- Added in schema version 2 (Phase 3) -----------------------------------

@DataClassName('HabitRow')
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable identifier used by code and voice ("water", "workout"...).
  TextColumn get key => text().unique()();
  TextColumn get name => text()();

  /// HabitType.name: check | count | minutes.
  TextColumn get type => text()();

  /// Target per day: 1 for check, glasses for count, minutes for minutes.
  IntColumn get goal => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();

  /// "YYYY-MM-DD"
  TextColumn get date => text()();

  /// 1/0 for check habits, glasses or minutes otherwise.
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {habitId, date};
}

@DataClassName('MoodRow')
class Moods extends Table {
  /// "YYYY-MM-DD"
  TextColumn get date => text()();

  /// Mood.name: great | good | okay | low | bad.
  TextColumn get mood => text()();

  @override
  Set<Column> get primaryKey => {date};
}

@DataClassName('WeeklyPlanRow')
class WeeklyPlan extends Table {
  /// 1 = Monday ... 7 = Sunday (DateTime.weekday).
  IntColumn get weekday => integer()();
  TextColumn get workout => text().withDefault(const Constant(''))();
  TextColumn get studyFocus => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {weekday};
}

// --- Added in schema version 3 (Phase 4) -----------------------------------

@DataClassName('ExpenseRow')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Amount in PAISE (₹250.50 = 25050). Whole numbers avoid rounding drift.
  IntColumn get amount => integer()();

  /// ExpenseCategory.name: food | travel | shopping | bills | health | fun | other.
  TextColumn get category => text()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// "YYYY-MM-DD"
  TextColumn get date => text()();

  /// When the row was added; orders spends within the same day.
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get category => text()();

  /// Monthly limit in paise.
  IntColumn get monthlyLimit => integer()();

  @override
  Set<Column> get primaryKey => {category};
}

@DriftDatabase(
  tables: [
    Tasks,
    Subtasks,
    Settings,
    Habits,
    HabitLogs,
    Moods,
    WeeklyPlan,
    Expenses,
    Budgets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database file (app-private storage, never uploaded).
  factory AppDatabase.onDevice() => AppDatabase(driftDatabase(name: 'petal'));

  /// History:
  /// 1. tasks, subtasks, settings (Phase 2)
  /// 2. habits, habit_logs, moods, weekly_plan (Phase 3)
  /// 3. expenses, budgets (Phase 4)
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _insertDefaultHabits();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(habits);
        await m.createTable(habitLogs);
        await m.createTable(moods);
        await m.createTable(weeklyPlan);
        await _insertDefaultHabits();
      }
      if (from < 3) {
        await m.createTable(expenses);
        await m.createTable(budgets);
      }
    },
    beforeOpen: (details) async {
      // SQLite doesn't enforce foreign keys unless asked. Needed so
      // deleting a task deletes its subtasks.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The five built-in habits. This is app setup, not sample data, so it
  /// runs in release builds too. Goals are editable later in Me > Settings.
  Future<void> _insertDefaultHabits() async {
    const defaults = [
      ('water', 'Water', 'count', 8),
      ('workout', 'Workout', 'check', 1),
      ('study', 'Study', 'minutes', 120),
      ('meditate', 'Meditate', 'check', 1),
      ('read', 'Read', 'check', 1),
    ];
    for (final (i, (key, name, type, goal)) in defaults.indexed) {
      await into(habits).insert(
        HabitsCompanion.insert(
          key: key,
          name: name,
          type: type,
          goal: goal,
          sortOrder: Value(i),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }
}
