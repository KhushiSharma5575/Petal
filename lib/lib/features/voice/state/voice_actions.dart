import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../../data/providers.dart';
import '../../tasks/state/tasks_controller.dart';
import '../logic/voice_parser.dart';

/// Saves a confirmed voice command. Returns a function that undoes it, or
/// null if there was nothing to save.
class VoiceActions {
  VoiceActions(this._ref);
  final Ref _ref;

  Future<Future<void> Function()?> save(VoiceCommand command) async {
    final today = _ref.read(todayProvider);
    switch (command) {
      case AddTask(:final draft):
        final tasks = _ref.read(tasksControllerProvider);
        final id = await tasks.add(draft);
        if (draft.reminder) await tasks.ensureReminderPermission();
        return () async => tasks.delete(id);

      case AddExpense(:final draft):
        final money = _ref.read(expenseRepositoryProvider);
        final id = await money.add(draft);
        return () async => money.delete(id);

      case AddExpenses(:final drafts):
        final money = _ref.read(expenseRepositoryProvider);
        final ids = [for (final d in drafts) await money.add(d)];
        return () async {
          for (final id in ids) {
            await money.delete(id);
          }
        };

      case LogHabit(:final habitKey, :final amount):
        final repo = _ref.read(habitRepositoryProvider);
        final habit = (await repo.getHabits(today))
            .where((h) => h.habit.key == habitKey)
            .firstOrNull
            ?.habit;
        if (habit == null) return null;
        final before = await repo.getValue(habit.id, today);
        // An amount adds to today; no amount means "done" (at least the
        // goal, never lowering what's already logged).
        final after = amount == null
            ? (before > habit.goal ? before : habit.goal)
            : before + amount;
        await repo.setValue(habit.id, today, after);
        return () => repo.setValue(habit.id, today, before);

      case SetMood(:final mood):
        final repo = _ref.read(moodRepositoryProvider);
        final before = await repo.getMood(today);
        await repo.setMood(today, mood);
        return () => repo.setMood(today, before);

      case AskPetal() || NotUnderstood():
        return null;
    }
  }
}

final voiceActionsProvider = Provider<VoiceActions>(VoiceActions.new);
