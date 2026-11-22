import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/shell/nav_state.dart';
import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/task.dart';
import '../logic/due_label.dart';
import '../logic/task_groups.dart';
import '../state/tasks_controller.dart';
import '../state/tasks_providers.dart';
import 'task_card.dart';
import 'task_editor_sheet.dart';
import 'task_style.dart';

/// Today's and overdue tasks (max 5) on the Today screen.
class TodayTasksCard extends ConsumerWidget {
  const TodayTasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(todayTasksProvider);
    if (data == null) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    void seeAll() {
      ref.read(taskFilterProvider.notifier).clearAll();
      ref.read(navProvider.notifier).select(AppTab.tasks);
    }

    final open = data.total - data.doneCount;
    final summary = data.total == 0
        ? 'Nothing due'
        : open == 0
        ? 'All done'
        : '$open to do${data.doneCount > 0 ? ' · ${data.doneCount} done' : ''}';

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Today\'s tasks', style: text.titleMedium),
                    ),
                    Text(summary, style: text.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: seeAll,
                style: TextButton.styleFrom(
                  backgroundColor: palette.soft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(
                  'See all',
                  semanticsLabel: 'See all tasks',
                  style: nunito(FontWeight.w800, size: 13, color: palette.deep),
                ),
              ),
            ],
          ),
          const SizedBox(height: PetalSpacing.xs),
          if (data.shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PetalSpacing.sm),
              child: Text(
                'Nothing due today. Enjoy it, or add something below.',
                style: text.bodyMedium?.copyWith(
                  color: PetalColors.textSecondary,
                ),
              ),
            ),
          for (final t in data.shown) _TodayTaskRow(task: t, today: today),
          if (data.total > data.shown.length)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                '+${data.total - data.shown.length} more in Tasks',
                style: text.bodySmall,
              ),
            ),
          const SizedBox(height: PetalSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                showTaskEditor(context, initial: TaskDraft(dueDate: today)),
            style: OutlinedButton.styleFrom(
              foregroundColor: PetalColors.textSecondary,
              side: const BorderSide(color: PetalColors.divider, width: 2),
            ),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add a task'),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskRow extends ConsumerWidget {
  const _TodayTaskRow({required this.task, required this.today});
  final TaskItem task;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = groupOf(task, today) == TaskGroup.overdue;
    final when = overdue
        ? 'Overdue · ${dueLabel(task.dueDate, task.dueTime, today)}'
        : (task.dueTime?.format() ?? '');
    final meta = [when, task.list.label].where((s) => s.isNotEmpty).join(' · ');
    final controller = ref.read(tasksControllerProvider);
    void open() => showTaskEditor(context, existing: task);

    return Row(
      children: [
        TaskTickBox(
          task: task,
          onTap: () => controller.setDone(task, !task.done),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: '${task.title}, $meta${task.done ? ', done' : ''}',
            hint: 'Open task',
            onTap: open,
            excludeSemantics: true,
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          nunito(
                            FontWeight.w800,
                            size: 15,
                            color: task.done
                                ? PetalColors.textSecondary
                                : PetalColors.text,
                          ).copyWith(
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: nunito(
                          FontWeight.w700,
                          size: 12,
                          color: overdue
                              ? TaskColors.overdue
                              : PetalColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
