import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../core/widgets/text_dialogs.dart';
import '../../../data/models/habit.dart';
import '../../me/state/me_providers.dart';
import '../logic/habit_logic.dart';
import '../state/habits_providers.dart';
import 'habit_style.dart';

/// Mon-Sun grid of every habit. Tap today or a past day to fix a tick.
class HabitWeekGrid extends ConsumerWidget {
  const HabitWeekGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value;
    if (habits == null) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final monday = startOfWeek(today);
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final pct = ref.watch(weekSnapshotProvider)?.habitsKeptPercent ?? 0;
    final text = Theme.of(context).textTheme;

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('This week', style: text.titleMedium),
                ),
              ),
              Text(
                '$pct% kept',
                style: nunito(
                  FontWeight.w800,
                  size: 13,
                  color: context.palette.deep,
                ),
              ),
            ],
          ),
          const SizedBox(height: PetalSpacing.sm),
          Row(
            children: [
              const SizedBox(width: 72),
              for (final d in days)
                Expanded(
                  child: Text(
                    DateText.weekdays[d.weekday - 1].substring(0, 2),
                    textAlign: TextAlign.center,
                    style: nunito(
                      FontWeight.w800,
                      size: 11,
                      color: isSameDay(d, today)
                          ? context.palette.deep
                          : PetalColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          for (final h in habits)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      h.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: PetalColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final d in days)
                    Expanded(
                      child: _Cell(h: h, day: d, today: today),
                    ),
                ],
              ),
            ),
          const SizedBox(height: PetalSpacing.sm),
          Text(
            'Tap today or an earlier day to fix a tick.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Cell extends ConsumerWidget {
  const _Cell({required this.h, required this.day, required this.today});
  final HabitWithLogs h;
  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = day.isAfter(today);
    final done = isDone(h.habit, h.valueOn(day));
    final isToday = isSameDay(day, today);
    void toggle() => ref.read(meControllerProvider).toggleHabitDay(h, day);
    final dayName = DateText.weekdays[day.weekday - 1];
    final state = future ? 'upcoming' : (done ? 'done' : 'not done');

    return Semantics(
      container: true,
      label: '${h.habit.name} on $dayName, $state',
      button: !future,
      checked: future ? null : done,
      onTap: future ? null : toggle,
      excludeSemantics: true,
      child: InkResponse(
        onTap: future ? null : toggle,
        radius: 20,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? h.habit.tile : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: done
                    ? (isToday
                          ? Border.all(color: context.palette.accent, width: 2)
                          : null)
                    : Border.all(
                        color: isToday
                            ? context.palette.accent
                            : future
                            ? PetalColors.divider
                            : const Color(0xFFD9D1E8),
                        width: 2,
                      ),
              ),
              child: done
                  ? const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: PetalColors.text,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The weekly workout / study plan. Tap a day to edit it.
class WeeklyPlanCard extends ConsumerWidget {
  const WeeklyPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weeklyPlanProvider).value;
    if (plan == null) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final text = Theme.of(context).textTheme;

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Weekly plan', style: text.titleMedium),
          ),
          const SizedBox(height: PetalSpacing.xs),
          for (var d = 1; d <= 7; d++)
            _PlanRow(day: plan[d]!, isToday: today.weekday == d),
        ],
      ),
    );
  }
}

class _PlanRow extends ConsumerWidget {
  const _PlanRow({required this.day, required this.isToday});
  final PlanDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = DateText.weekdays[day.weekday - 1];
    final text = Theme.of(context).textTheme;
    final summary = [
      day.workout.isEmpty ? 'No workout' : day.workout,
      if (day.studyFocus.isNotEmpty) 'Study: ${day.studyFocus}',
    ].join(' · ');

    Future<void> edit() async {
      final controller = ref.read(meControllerProvider);
      final result = await showTextFieldsDialog(
        context,
        title: name,
        fields: [
          (
            label: 'Workout',
            initial: day.workout,
            hint: 'Legs, yoga, rest day',
          ),
          (
            label: 'Study focus',
            initial: day.studyFocus,
            hint: 'Maths, revision',
          ),
        ],
      );
      if (result == null) return;
      await controller.setPlan(
        PlanDay(
          weekday: day.weekday,
          workout: result[0],
          studyFocus: result[1],
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$name: $summary',
      hint: 'Edit plan',
      onTap: edit,
      excludeSemantics: true,
      child: InkWell(
        onTap: edit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  name.substring(0, 3),
                  style: nunito(
                    FontWeight.w800,
                    size: 13,
                    color: isToday ? context.palette.deep : PetalColors.text,
                  ),
                ),
              ),
              Expanded(child: Text(summary, style: text.bodyMedium)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  LucideIcons.pencil,
                  size: 16,
                  color: PetalColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
