import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/motion.dart';
import '../../../core/widgets/number_dialog.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/habit.dart';
import '../logic/habit_logic.dart';
import '../state/habits_providers.dart';
import 'earn_sessions.dart';
import 'habit_editor_sheet.dart';
import 'habit_style.dart';

/// One compact card with a row per habit (everything except Water, which
/// has its own card).
class HabitsCard extends ConsumerWidget {
  const HabitsCard({super.key, required this.habits});

  final List<HabitWithLogs> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = habits.where((h) => h.habit.key != HabitKeys.water).toList();
    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Habits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (i, h) in rows.indexed) ...[
            if (i > 0) const Divider(indent: 52, endIndent: 8),
            _HabitRow(h: h),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showHabitEditor(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add a habit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.h});
  final HabitWithLogs h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final habit = h.habit;
    final value = h.valueOn(today);
    final done = isDone(habit, value);
    final streak = streakOf(h, today);
    final controller = ref.read(habitsControllerProvider);
    final text = Theme.of(context).textTheme;
    // "Earn your streaks": Workout needs a step session, Study a focus timer.
    final earn = ref.watch(earnStreaksProvider).value ?? true;
    final isWorkout = habit.key == HabitKeys.workout;
    final isStudy = habit.key == HabitKeys.study;
    final session = isWorkout ? ref.watch(workoutSessionProvider).value : null;

    final String subtitle;
    switch (habit.key) {
      case HabitKeys.workout:
        final plan = ref.watch(todayPlanProvider).value?.workout ?? '';
        subtitle = done
            ? (plan.isEmpty ? 'Done today' : 'Done today · $plan')
            : session != null && earn
            ? 'Session running · tap to continue'
            : (plan.isEmpty ? 'No workout planned' : plan);
      case HabitKeys.study:
        final focus = ref.watch(todayPlanProvider).value?.studyFocus ?? '';
        subtitle = [
          minutesText(value, habit.goal),
          if (focus.isNotEmpty) focus,
        ].join(' · ');
      default:
        subtitle = switch (habit.type) {
          HabitType.check => done ? 'Done today' : 'Not yet today',
          HabitType.minutes => minutesText(value, habit.goal),
          HabitType.count => '$value / ${habit.goal} today',
        };
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Edit ${habit.name}',
            excludeSemantics: true,
            onTap: () => showHabitEditor(context, existing: habit),
            child: InkResponse(
              onTap: () => showHabitEditor(context, existing: habit),
              radius: 24,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: habit.tile,
                  shape: BoxShape.circle,
                ),
                child: Icon(habit.icon, size: 20, color: PetalColors.text),
              ),
            ),
          ),
          const SizedBox(width: PetalSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(habit.name, style: text.titleSmall),
                    if (streak > 0) _Streak(days: streak),
                  ],
                ),
                const SizedBox(height: 2),
                habit.type == HabitType.minutes && !(earn && isStudy)
                    ? _MinutesLine(
                        text: subtitle,
                        onTap: () => _editMinutes(context, ref, habit, value),
                      )
                    : Text(subtitle, style: text.bodySmall),
                if (habit.type == HabitType.minutes) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progressOf(habit, value)),
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 300),
                      ),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: PetalColors.divider,
                        color: context.palette.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: PetalSpacing.sm),
          if (isWorkout && earn && !done)
            _PlusButton(
              label: session == null ? 'Start' : 'Open',
              semanticsLabel: session == null
                  ? 'Start a ${habit.name.toLowerCase()} session'
                  : 'Open the ${habit.name.toLowerCase()} session',
              done: false,
              onTap: () => showWorkoutSession(context, habit),
            )
          else if (isStudy && earn)
            _PlusButton(
              label: 'Focus',
              semanticsLabel: 'Start a focus timer for ${habit.name}',
              done: done,
              onTap: () => showFocusSession(context, habit),
            )
          else if (habit.type == HabitType.check)
            _CheckButton(
              done: done,
              label: habit.name,
              onTap: () => controller.toggle(h),
            )
          else
            habit.type == HabitType.count
                ? _PlusButton(
                    label: '+1',
                    semanticsLabel: 'Add one to ${habit.name.toLowerCase()}',
                    done: done,
                    onTap: () => controller.addToday(habit, 1),
                  )
                : _PlusButton(
                    label: '+${_step(habit.goal)}',
                    semanticsLabel:
                        'Add ${_step(habit.goal)} minutes of '
                        '${habit.name.toLowerCase()}',
                    done: done,
                    onTap: () => controller.addToday(habit, _step(habit.goal)),
                  ),
        ],
      ),
    );
  }

  /// "+30" for most minute habits, "+10" / "+15" for short ones.
  static int _step(int goal) => goal <= 20
      ? 5
      : goal <= 45
      ? 15
      : 30;

  Future<void> _editMinutes(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    int value,
  ) async {
    final controller = ref.read(habitsControllerProvider);
    final result = await showNumberDialog<int>(
      context,
      title: '${habit.name} today',
      label: 'Minutes',
      suffixText: 'min',
      initialText: value == 0 ? '' : '$value',
      // Empty means 0 (clears today's minutes). Max one day.
      parse: (t) {
        final n = t.isEmpty ? 0 : int.tryParse(t);
        return n != null && n <= 1440 ? n : null;
      },
      errorText: 'Enter minutes from 0 to 1440',
    );
    if (result case NumberSaved(:final value)) {
      await controller.setToday(habit, value);
    }
  }
}

/// "45 / 120 min" that can be tapped to type an exact number.
class _MinutesLine extends StatelessWidget {
  const _MinutesLine({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$text. Edit minutes',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.pencil,
                size: 12,
                color: PetalColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Streak extends StatelessWidget {
  const _Streak({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$days-day streak',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.flame,
            size: 13,
            color: TodayCardColors.streak,
          ),
          const SizedBox(width: 2),
          Text(
            '$days ${days == 1 ? 'day' : 'days'}',
            style: nunito(
              FontWeight.w800,
              size: 12,
              color: TodayCardColors.streak,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round tick button for check habits. 48dp target.
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: done,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: PetalSpacing.minTouch,
          child: Center(
            child: AnimatedContainer(
              duration: motionDuration(
                context,
                const Duration(milliseconds: 180),
              ),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? palette.deep : PetalColors.surface,
                border: Border.all(
                  color: done ? palette.deep : PetalColors.textSecondary,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({
    required this.label,
    required this.semanticsLabel,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: done ? palette.deep : palette.soft,
        foregroundColor: done ? Colors.white : palette.deep,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(56, PetalSpacing.minTouch),
      ),
      child: Text(
        label,
        semanticsLabel: semanticsLabel,
        style: nunito(FontWeight.w800, size: 14),
      ),
    );
  }
}
