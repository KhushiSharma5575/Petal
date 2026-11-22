import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../data/models/task.dart';
import '../logic/due_label.dart';
import 'task_style.dart';

/// One task in a list: tick box, title, and a line of details.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.today,
    required this.overdue,
    required this.onToggle,
    required this.onOpen,
  });

  final TaskItem task;
  final DateTime today;
  final bool overdue;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final when = dueLabel(task.dueDate, task.dueTime, today);
    final (listBg, listFg) = TaskColors.list(task.list);
    final showHigh = task.priority == TaskPriority.high && !task.done;
    final hasSubs = task.subtasks.isNotEmpty;

    // One spoken summary for TalkBack instead of many small pieces.
    final summary = [
      task.title,
      if (task.done) 'done',
      if (when.isNotEmpty) (overdue ? 'overdue, $when' : when),
      task.list.label,
      if (showHigh) 'high priority',
      if (task.reminder) 'reminder on',
      if (hasSubs)
        '${task.subtasksDone} of ${task.subtasks.length} subtasks done',
    ].join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PetalColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overdue ? TaskColors.overdueBorder : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5B3FA0),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        // The tick box and the "open" area are siblings (not nested) so
        // TalkBack treats them as two separate controls.
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TaskTickBox(task: task, onTap: onToggle),
            ),
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                label: summary,
                hint: 'Open task',
                onTap: onOpen,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              nunito(
                                FontWeight.w800,
                                size: 15,
                                height: 1.3,
                                color: task.done
                                    ? PetalColors.textSecondary
                                    : PetalColors.text,
                              ).copyWith(
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (when.isNotEmpty)
                              _When(text: when, overdue: overdue),
                            _Chip(
                              text: task.list.label,
                              bg: listBg,
                              fg: listFg,
                            ),
                            if (showHigh)
                              const _Chip(
                                text: 'High',
                                bg: TaskColors.highBg,
                                fg: TaskColors.highFg,
                              ),
                            if (task.reminder && !task.done)
                              const Icon(
                                LucideIcons.bell,
                                size: 14,
                                color: PetalColors.textSecondary,
                              ),
                          ],
                        ),
                        if (hasSubs) ...[
                          const SizedBox(height: 8),
                          _SubtaskBar(task: task),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded tick box. 28px visual, 48dp touch target. Border colour shows
/// priority; filled when done.
class TaskTickBox extends StatelessWidget {
  const TaskTickBox({super.key, required this.task, required this.onTap});

  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = task.done;
    return Semantics(
      container: true,
      checked: done,
      label: done ? 'Mark not done: ${task.title}' : 'Mark done: ${task.title}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: PetalSpacing.minTouch,
          height: PetalSpacing.minTouch,
          child: Center(
            child: AnimatedContainer(
              duration: motionDuration(
                context,
                const Duration(milliseconds: 180),
              ),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? palette.deep : PetalColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: done
                      ? palette.deep
                      : TaskColors.priority(task.priority),
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

class _When extends StatelessWidget {
  const _When({required this.text, required this.overdue});
  final String text;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? TaskColors.overdue : PetalColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.clock, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: nunito(FontWeight.w700, size: 12, color: color)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PetalRadii.chip),
      ),
      child: Text(text, style: nunito(FontWeight.w800, size: 11, color: fg)),
    );
  }
}

class _SubtaskBar extends StatelessWidget {
  const _SubtaskBar({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final total = task.subtasks.length;
    final done = task.subtasksDone;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 6,
              backgroundColor: PetalColors.divider,
              color: context.palette.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$done/$total subtasks',
          style: nunito(
            FontWeight.w800,
            size: 11,
            color: PetalColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
