import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/home_widget_bridge.dart';
import '../../../core/utils/clock.dart';
import '../../../data/models/habit.dart';
import '../../../data/providers.dart';
import '../../habits/state/habits_providers.dart';
import '../../tasks/state/tasks_providers.dart';

/// The widget's data, derived from today's tasks and water. Null while
/// loading.
final homeWidgetDataProvider = Provider<HomeWidgetData?>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  final habits = ref.watch(habitsProvider).value;
  if (tasks == null || habits == null) return null;
  final today = ref.watch(todayProvider);
  final water = habits.where((h) => h.habit.key == HabitKeys.water).firstOrNull;
  final open = tasks.shown.where((t) => !t.done).toList();
  return HomeWidgetData(
    date: today,
    tasks: [for (final t in open.take(3)) t.title],
    openCount: tasks.total - tasks.doneCount,
    water: water?.valueOn(today) ?? 0,
    waterGoal: water?.habit.goal ?? 8,
  );
});

/// Watched by the app root: pushes fresh data to the widget whenever it
/// changes.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final data = ref.watch(homeWidgetDataProvider);
  if (data != null) ref.read(homeWidgetBridgeProvider).update(data);
});

/// Adds glasses tapped on the widget (while Petal was closed) to today's
/// water, never past the goal. Called on start and whenever Petal returns
/// to the foreground.
Future<void> mergeWidgetGlasses(WidgetRef ref) async {
  final today = ref.read(todayProvider);
  final pending =
      (await ref.read(homeWidgetBridgeProvider).takePendingGlasses())
          .where((p) => !p.day.isAfter(today))
          .toList();
  if (pending.isEmpty) return;
  final repo = ref.read(habitRepositoryProvider);
  final water = (await repo.getHabits(today))
      .where((h) => h.habit.key == HabitKeys.water)
      .firstOrNull
      ?.habit;
  if (water == null) return;
  // Each logged on the day it was tapped, never past the goal.
  for (final p in pending) {
    await repo.changeValue(
      water.id,
      p.day,
      (v) => v >= water.goal ? v : (v + p.glasses).clamp(0, water.goal),
    );
  }
}
