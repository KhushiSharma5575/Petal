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
import '../../../data/models/mood.dart';
import '../../me/state/me_providers.dart';
import 'mood_face.dart';

/// A month of moods as faces. Tap today or a past day to set or change it.
class MoodCalendar extends ConsumerWidget {
  const MoodCalendar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(moodMonthProvider);
    final moods = ref.watch(moodsInMonthProvider).value ?? const {};
    final today = ref.watch(todayProvider);
    final nav = ref.read(moodMonthProvider.notifier);
    final text = Theme.of(context).textTheme;
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - 1; // weeks start Monday
    final cells = [
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: nav.previous,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '${DateText.months[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: isCurrentMonth ? null : nav.next,
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final w in DateText.weekdays)
                  Expanded(
                    child: Text(
                      w.substring(0, 2),
                      textAlign: TextAlign.center,
                      style: nunito(
                        FontWeight.w800,
                        size: 11,
                        color: PetalColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                for (var row = 0; row * 7 < cells.length; row++)
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child:
                              row * 7 + col < cells.length &&
                                  cells[row * 7 + col] != null
                              ? _DayCell(
                                  day: cells[row * 7 + col]!,
                                  mood: moods[cells[row * 7 + col]!],
                                  today: today,
                                )
                              : const SizedBox(height: 44),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: PetalSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_summary(moods), style: text.bodySmall),
          ),
        ],
      ),
    );
  }

  static String _summary(Map<DateTime, Mood> moods) {
    if (moods.isEmpty) return 'No check-ins this month yet.';
    final counts = <Mood, int>{};
    for (final m in moods.values) {
      counts[m] = (counts[m] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return 'Mostly ${top.key.label.toLowerCase()} this month · '
        '${moods.length} check-in${moods.length == 1 ? '' : 's'}';
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({required this.day, required this.mood, required this.today});
  final DateTime day;
  final Mood? mood;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = day.isAfter(today);
    final isToday = isSameDay(day, today);
    final label = [
      '${day.day} ${DateText.months[day.month - 1]}',
      if (isToday) 'today',
      if (mood != null)
        'felt ${mood!.label.toLowerCase()}'
      else if (!future)
        'no check-in',
    ].join(', ');
    void pick() => _pickMood(context, ref, day, mood);

    return Semantics(
      container: true,
      label: label,
      button: !future,
      onTap: future ? null : pick,
      excludeSemantics: true,
      child: InkResponse(
        onTap: future ? null : pick,
        radius: 22,
        child: SizedBox(
          height: 44,
          child: Center(
            child: mood != null
                ? Container(
                    decoration: isToday
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.palette.deep,
                              width: 2,
                            ),
                          )
                        : null,
                    child: MoodFace(mood: mood!, size: 30),
                  )
                : Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.palette.deep,
                              width: 2,
                            ),
                          )
                        : null,
                    child: Text(
                      '${day.day}',
                      style: nunito(
                        FontWeight.w700,
                        size: 12,
                        color: future
                            ? PetalColors.textSecondary.withValues(alpha: 0.6)
                            : PetalColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pickMood(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  Mood? current,
) async {
  final controller = ref.read(meControllerProvider);
  // Sentinel for "Clear": showModalBottomSheet's null means dismissed.
  const clear = 'clear';
  final picked = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How did you feel on ${DateText.longDay(day)}?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PetalSpacing.md),
          Row(
            children: [
              for (final m in Mood.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: m == current,
                    label: 'Felt ${m.label.toLowerCase()}',
                    onTap: () => Navigator.of(context).pop(m),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            MoodFace(mood: m, size: 40),
                            const SizedBox(height: 4),
                            Text(
                              m.label,
                              style: nunito(
                                FontWeight.w700,
                                size: 11,
                                color: PetalColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: PetalSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(clear),
              child: const Text('Clear this day'),
            ),
          ],
        ],
      ),
    ),
  );
  if (picked is Mood) await controller.setMood(dateOnly(day), picked);
  if (picked == clear) await controller.setMood(dateOnly(day), null);
}
