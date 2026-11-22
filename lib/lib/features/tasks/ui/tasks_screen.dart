import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/petal_page.dart';
import '../../../data/models/task.dart';
import '../logic/due_label.dart';
import '../logic/task_groups.dart';
import '../state/tasks_controller.dart';
import '../state/tasks_providers.dart';
import 'task_editor_sheet.dart';
import 'task_group_section.dart';
import 'week_strip.dart';

/// Tasks: header (title, list filter, Add), week strip, then task groups.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(visibleGroupsProvider);
    final allTasks = ref.watch(tasksProvider).value ?? const <TaskItem>[];
    final filter = ref.watch(taskFilterProvider);
    final collapsed = ref.watch(collapsedGroupsProvider);
    final today = ref.watch(todayProvider);
    final controller = ref.read(tasksControllerProvider);

    Future<void> moveOverdue(List<TaskItem> overdue) async {
      final messenger = ScaffoldMessenger.of(context);
      final previous = await controller.moveOverdueToToday(overdue);
      final n = previous.length;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            content: Text('Moved $n ${n == 1 ? 'task' : 'tasks'} to today'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => controller.undoMove(previous),
            ),
          ),
        );
    }

    final List<Widget> body;
    if (groups == null) {
      body = const []; // first load, only takes a moment
    } else if (allTasks.isEmpty) {
      body = const [
        EmptyState(
          icon: LucideIcons.listChecks,
          tileColor: PetalColors.tileLavender,
          title: 'No tasks yet',
          message: 'Tap Add to plan something, or tap the mic and say it.',
        ),
      ];
    } else if (groups.isEmpty) {
      body = [
        EmptyState(
          icon: LucideIcons.coffee,
          tileColor: PetalColors.tileMint,
          title: 'Nothing here',
          message: _emptyFilterMessage(filter.list, filter.day, today),
          action: TextButton(
            onPressed: ref.read(taskFilterProvider.notifier).clearAll,
            child: const Text('Show all tasks'),
          ),
        ),
      ];
    } else {
      body = [
        for (final MapEntry(key: group, value: tasks) in groups.entries)
          TaskGroupSection(
            key: ValueKey(group),
            group: group,
            tasks: tasks,
            today: today,
            collapsed: collapsed.contains(group),
            onToggleCollapsed: () =>
                ref.read(collapsedGroupsProvider.notifier).toggle(group),
            onToggleDone: (t) => controller.setDone(t, !t.done),
            onOpen: (t) => showTaskEditor(context, existing: t),
            onMoveAllToToday: group == TaskGroup.overdue
                ? () => moveOverdue(tasks)
                : null,
          ),
      ];
    }

    return PetalPage(
      header: _Header(
        onAdd: () => showTaskEditor(
          context,
          // Adding while a day is selected pre-fills that day.
          initial: filter.day == null ? null : TaskDraft(dueDate: filter.day),
        ),
      ),
      children: [const WeekStrip(), ...body],
    );
  }

  static String _emptyFilterMessage(
    TaskList? list,
    DateTime? day,
    DateTime today,
  ) {
    final what = list == null ? 'No tasks' : 'No ${list.label} tasks';
    if (day == null) return '$what yet.';
    // "No Work tasks for today." / "...for Tuesday." / "...for Mon 23 Nov."
    final dayText = dueLabel(day, null, today);
    const relative = {'Today', 'Tomorrow', 'Yesterday'};
    return '$what for ${relative.contains(dayText) ? dayText.toLowerCase() : dayText}.';
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'My tasks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const _ListFilterButton(),
            ],
          ),
        ),
        const SizedBox(width: PetalSpacing.md),
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(backgroundColor: PetalColors.ink),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

/// "All lists ▾" dropdown.
class _ListFilterButton extends ConsumerWidget {
  const _ListFilterButton();

  // PopupMenuButton treats a null value as "cancelled", so "All" uses -1.
  static const _all = -1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(taskFilterProvider.select((f) => f.list));
    final deep = context.palette.deep;
    final label = list?.label ?? 'All lists';
    return PopupMenuButton<int>(
      tooltip: 'Filter by list, showing $label',
      initialValue: list?.index ?? _all,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(
        borderRadius: PetalRadii.controlRadius,
      ),
      color: PetalColors.surface,
      onSelected: (i) => ref
          .read(taskFilterProvider.notifier)
          .setList(i == _all ? null : TaskList.values[i]),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _all, child: Text('All lists')),
        for (final l in TaskList.values)
          PopupMenuItem(value: l.index, child: Text(l.label)),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PetalSpacing.minTouch),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(FontWeight.w800, size: 14, color: deep),
              ),
            ),
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronDown, size: 18, color: deep),
          ],
        ),
      ),
    );
  }
}
