import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../../data/models/habit.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../logic/earn_logic.dart';
import '../logic/habit_logic.dart';

/// Active habits with their recent history, live.
final habitsProvider = StreamProvider<List<HabitWithLogs>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(habitRepositoryProvider).watchHabits(today);
});

/// Today's row of the weekly plan (workout / study focus).
final todayPlanProvider = StreamProvider<PlanDay>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(habitRepositoryProvider).watchPlanFor(today.weekday);
});

/// (done, total) habits today, or null while loading.
final todayHabitProgressProvider = Provider<(int, int)?>((ref) {
  final habits = ref.watch(habitsProvider).value;
  if (habits == null) return null;
  return dayProgress(habits, ref.watch(todayProvider));
});

/// True when every active habit is done today (drives the celebration).
final allHabitsDoneProvider = Provider<bool>((ref) {
  final p = ref.watch(todayHabitProgressProvider);
  return p != null && p.$2 > 0 && p.$1 == p.$2;
});

/// "Earn your streaks" (on unless switched off in Settings).
final earnStreaksProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.earnStreaks)
      .map((v) => v != 'false');
});

/// Steps a workout session needs.
final workoutStepsProvider = StreamProvider<int>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchInt(SettingKeys.workoutSteps, SettingDefaults.workoutSteps);
});

/// The workout session in progress, if any.
final workoutSessionProvider = StreamProvider<WorkoutSession?>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.workoutSession)
      .map(WorkoutSession.decode);
});

/// Habit actions for the UI.
class HabitsController {
  HabitsController(this._ref);
  final Ref _ref;

  HabitRepository get _repo => _ref.read(habitRepositoryProvider);
  DateTime get _today => _ref.read(todayProvider);

  /// Ticks or unticks a check habit (Workout, Meditate, Read) for today.
  /// Reads the saved value (not the one on screen), so a quick second tap
  /// unticks instead of ticking again.
  Future<void> toggle(HabitWithLogs h) {
    return _repo.changeValue(
      h.habit.id,
      _today,
      (v) => isDone(h.habit, v) ? 0 : h.habit.goal,
    );
  }

  Future<void> setToday(Habit habit, int value) =>
      _repo.setValue(habit.id, _today, value);

  Future<void> addToday(Habit habit, int amount) =>
      _repo.addValue(habit.id, _today, amount);

  Future<int> addHabit({
    required String name,
    required HabitType type,
    required int goal,
  }) => _repo.addHabit(name: name, type: type, goal: goal);

  Future<void> updateHabit(
    Habit habit, {
    required String name,
    required int goal,
  }) => _repo.updateHabit(habit.id, name: name, goal: goal);

  /// Hides a habit (history kept); [bringBack] undoes it.
  Future<void> hide(Habit habit) => _repo.setActive(habit.id, false);
  Future<void> bringBack(Habit habit) => _repo.setActive(habit.id, true);

  SettingsRepository get _settings => _ref.read(settingsRepositoryProvider);

  Future<void> saveWorkoutSession(WorkoutSession? s) =>
      _settings.set(SettingKeys.workoutSession, s?.encode() ?? '');

  /// Marks a check habit done today (e.g. after an earned workout).
  Future<void> markDone(Habit habit) => _repo.changeValue(
    habit.id,
    _today,
    (v) => v >= habit.goal ? v : habit.goal,
  );

  Future<void> setEarnStreaks(bool on) =>
      _settings.set(SettingKeys.earnStreaks, on.toString());

  Future<void> setWorkoutSteps(int steps) =>
      _settings.set(SettingKeys.workoutSteps, '$steps');
}

final habitsControllerProvider = Provider<HabitsController>(
  HabitsController.new,
);
