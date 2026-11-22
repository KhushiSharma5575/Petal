import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/petal_card.dart';
import '../logic/due_label.dart';
import '../logic/task_filter.dart';
import '../state/tasks_providers.dart';

/// Mon to Sun for this week. A dot marks days with open tasks. Tapping a day
/// shows only that day; tapping it again shows everything.
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final selected = ref.watch(taskFilterProvider.select((f) => f.day));
    final dots = ref.watch(weekDotsProvider);
    final filter = ref.read(taskFilterProvider.notifier);

    return PetalCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in weekOf(today))
                Expanded(
                  child: _Day(
                    day: day,
                    isToday: isSameDay(day, today),
                    isSelected: selected != null && isSameDay(day, selected),
                    openCount: dots[day] ?? 0,
                    onTap: () => filter.toggleDay(day),
                  ),
                ),
            ],
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${dueLabel(selected, null, today)}',
                      style: nunito(
                        FontWeight.w800,
                        size: 13,
                        color: context.palette.deep,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: filter.clearDay,
                    child: const Text('Show all'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.openCount,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final int openCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color bg, fg, dowColor;
    if (isSelected) {
      (bg, fg, dowColor) = (palette.deep, Colors.white, Colors.white);
    } else if (isToday) {
      (bg, fg, dowColor) = (palette.soft, palette.deep, palette.deep);
    } else {
      (bg, fg, dowColor) = (
        Colors.transparent,
        PetalColors.text,
        PetalColors.textSecondary,
      );
    }
    final dotColor = openCount == 0
        ? Colors.transparent
        : (isSelected ? Colors.white : palette.accent);

    final weekday = DateText.weekdays[day.weekday - 1];
    final label = [
      '$weekday ${day.day} ${DateText.months[day.month - 1]}',
      if (isToday) 'today',
      openCount == 0
          ? 'no open tasks'
          : '$openCount open ${openCount == 1 ? 'task' : 'tasks'}',
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday.substring(0, 2),
                    style: nunito(FontWeight.w800, size: 11, color: dowColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: nunito(
                      FontWeight.w800,
                      size: 17,
                      color: fg,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
