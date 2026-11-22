import 'package:drift/drift.dart';

import '../../core/utils/dates.dart';
import '../db/app_database.dart';
import '../models/habit.dart';

/// Habits, their daily logs, and the weekly workout/study plan.
class HabitRepository {
  HabitRepository(this._db);

  final AppDatabase _db;

  /// How far back logs are loaded (enough for streaks and the Me grid).
  /// Enough for the longest streak shown (2 years).
  static const historyDays = 731;

  /// Active habits in display order, each with recent logs. Emits again on
  /// any change to habits or logs.
  Stream<List<HabitWithLogs>> watchHabits(DateTime today) {
    return _db
        .customSelect("SELECT 'habits'", readsFrom: {_db.habits, _db.habitLogs})
        .watch()
        .asyncMap((_) => getHabits(today));
  }

  Future<List<HabitWithLogs>> getHabits(DateTime today) async {
    final habitRows =
        await (_db.select(_db.habits)
              ..where((h) => h.active.equals(true))
              ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
            .get();
    final since = toIsoDate(addDays(today, -historyDays));
    final logRows = await (_db.select(
      _db.habitLogs,
    )..where((l) => l.date.isBiggerOrEqualValue(since))).get();
    final byHabit = <int, Map<DateTime, int>>{};
    for (final l in logRows) {
      (byHabit[l.habitId] ??= {})[fromIsoDate(l.date)] = l.value;
    }
    return [
      for (final h in habitRows)
        HabitWithLogs(_toHabit(h), byHabit[h.id] ?? const {}),
    ];
  }

  /// Sets the value for [habitId] on [day]. 0 removes the log.
  Future<void> setValue(int habitId, DateTime day, int value) async {
    final date = toIsoDate(day);
    if (value <= 0) {
      await (_db.delete(
        _db.habitLogs,
      )..where((l) => l.habitId.equals(habitId) & l.date.equals(date))).go();
      return;
    }
    await _db
        .into(_db.habitLogs)
        .insertOnConflictUpdate(
          HabitLogsCompanion.insert(habitId: habitId, date: date, value: value),
        );
  }

  Future<int> getValue(int habitId, DateTime day) async {
    final row =
        await (_db.select(_db.habitLogs)..where(
              (l) => l.habitId.equals(habitId) & l.date.equals(toIsoDate(day)),
            ))
            .getSingleOrNull();
    return row?.value ?? 0;
  }

  /// Adds [amount] to today's value (e.g. Study +30, "drank 2 glasses").
  Future<void> addValue(int habitId, DateTime day, int amount) =>
      changeValue(habitId, day, (v) => v + amount);

  /// Reads and writes in one transaction, so two quick taps ("+30", "+30")
  /// both count instead of one overwriting the other. Kept between 0 and
  /// 1440 (minutes in a day, more than any habit needs).
  Future<void> changeValue(
    int habitId,
    DateTime day,
    int Function(int current) change,
  ) {
    return _db.transaction(() async {
      final current = await getValue(habitId, day);
      await setValue(habitId, day, change(current).clamp(0, 1440));
    });
  }

  /// Changes a habit's daily goal (e.g. water glasses, study minutes).
  Future<void> setGoal(String key, int goal) => (_db.update(
    _db.habits,
  )..where((h) => h.key.equals(key))).write(HabitsCompanion(goal: Value(goal)));

  // --- your own habits -------------------------------------------------------

  /// Adds a habit of the user's own ("Skincare", "No sugar"...), shown
  /// after the others. Returns its id.
  Future<int> addHabit({
    required String name,
    required HabitType type,
    required int goal,
  }) async {
    final last =
        await (_db.select(_db.habits)
              ..orderBy([(h) => OrderingTerm.desc(h.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return _db
        .into(_db.habits)
        .insert(
          HabitsCompanion.insert(
            key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
            name: name.trim(),
            type: type.name,
            goal: type == HabitType.check ? 1 : goal,
            sortOrder: Value((last?.sortOrder ?? 0) + 1),
          ),
        );
  }

  /// Renames a habit and/or changes its daily goal.
  Future<void> updateHabit(int id, {required String name, required int goal}) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(name: Value(name.trim()), goal: Value(goal)),
      );

  /// Hides (false) or brings back (true) a habit. Its history is kept, so
  /// Undo and bringing it back lose nothing.
  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(active: Value(active)),
      );

  // --- weekly plan -----------------------------------------------------------

  /// All seven days of the plan (days never edited are empty).
  Stream<Map<int, PlanDay>> watchPlan() => _db
      .select(_db.weeklyPlan)
      .watch()
      .map(
        (rows) => {
          for (var d = 1; d <= 7; d++) d: PlanDay(weekday: d),
          for (final r in rows)
            r.weekday: PlanDay(
              weekday: r.weekday,
              workout: r.workout,
              studyFocus: r.studyFocus,
            ),
        },
      );

  Stream<PlanDay> watchPlanFor(int weekday) {
    return (_db.select(
      _db.weeklyPlan,
    )..where((p) => p.weekday.equals(weekday))).watchSingleOrNull().map(
      (r) => r == null
          ? PlanDay(weekday: weekday)
          : PlanDay(
              weekday: r.weekday,
              workout: r.workout,
              studyFocus: r.studyFocus,
            ),
    );
  }

  Future<void> setPlan(PlanDay day) {
    return _db
        .into(_db.weeklyPlan)
        .insertOnConflictUpdate(
          WeeklyPlanCompanion.insert(
            weekday: Value(day.weekday),
            workout: Value(day.workout),
            studyFocus: Value(day.studyFocus),
          ),
        );
  }

  static Habit _toHabit(HabitRow h) => Habit(
    id: h.id,
    key: h.key,
    name: h.name,
    type: HabitType.parse(h.type),
    goal: h.goal,
    sortOrder: h.sortOrder,
    active: h.active,
  );
}
