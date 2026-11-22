import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../data/models/task.dart';
import '../logic/task_groups.dart';
import 'task_card.dart';
import 'task_style.dart';

/// A collapsible group ("TODAY · 3") and its task cards.
class TaskGroupSection extends StatelessWidget {
  const TaskGroupSection({
    super.key,
    required this.group,
    required this.tasks,
    required this.today,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onToggleDone,
    required this.onOpen,
    this.onMoveAllToToday,
  });

  final TaskGroup group;
  final List<TaskItem> tasks;
  final DateTime today;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<TaskItem> onToggleDone;
  final ValueChanged<TaskItem> onOpen;

  /// Only for the Overdue group.
  final VoidCallback? onMoveAllToToday;

  @override
  Widget build(BuildContext context) {
    final color = switch (group) {
      TaskGroup.overdue => TaskColors.overdue,
      TaskGroup.today => context.palette.deep,
      _ => PetalColors.textSecondary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          // Heading on the left, "Move all to today" pushed to the right.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Semantics(
                button: true,
                expanded: !collapsed,
                label:
                    '${group.label}, ${tasks.length} '
                    '${tasks.length == 1 ? 'task' : 'tasks'}',
                hint: collapsed ? 'Show' : 'Hide',
                onTap: onToggleCollapsed,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onToggleCollapsed,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: PetalSpacing.minTouch,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${group.label.toUpperCase()} · ${tasks.length}',
                              style: nunito(
                                FontWeight.w800,
                                size: 13,
                                color: color,
                              ).copyWith(letterSpacing: 0.8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            collapsed
                                ? LucideIcons.chevronRight
                                : LucideIcons.chevronDown,
                            size: 18,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: PetalSpacing.sm),
            if (onMoveAllToToday != null)
              Flexible(
                child: TextButton(
                  onPressed: onMoveAllToToday,
                  style: TextButton.styleFrom(
                    backgroundColor: TaskColors.overdueSoft,
                    foregroundColor: TaskColors.overdue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: nunito(FontWeight.w800, size: 12),
                  ),
                  child: const Text(
                    'Move all to today',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        if (!collapsed)
          for (final t in tasks) ...[
            const SizedBox(height: PetalSpacing.sm),
            TaskCard(
              key: ValueKey(t.id),
              task: t,
              today: today,
              overdue: group == TaskGroup.overdue,
              onToggle: () => onToggleDone(t),
              onOpen: () => onOpen(t),
            ),
          ],
      ],
    );
  }
}
