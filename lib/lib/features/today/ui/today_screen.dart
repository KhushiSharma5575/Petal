import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/petal_page.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/habit.dart';
import '../../habits/state/habits_providers.dart';
import '../../habits/ui/habits_card.dart';
import '../../habits/ui/water_card.dart';
import '../../money/ui/spent_today_card.dart';
import '../../mood/ui/mood_checkin.dart';
import '../../tasks/ui/today_tasks_card.dart';
import '../logic/greeting.dart';

/// Today: greeting + progress ring, mood check-in, water & spent, habits,
/// today's tasks. A gentle celebration when every habit is done.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Bumped each time the last habit gets ticked, to replay the confetti.
  int _burst = 0;
  bool _showConfetti = false;

  @override
  Widget build(BuildContext context) {
    // Celebrate only on the moment all habits become done, not every time
    // the screen opens.
    ref.listen<bool>(allHabitsDoneProvider, (was, now) {
      if (was == false && now) {
        setState(() {
          _burst++;
          _showConfetti = true;
        });
      }
    });

    final greeting = ref.watch(greetingProvider);
    final today = ref.watch(todayProvider);
    final habits = ref.watch(habitsProvider).value;
    final progress = ref.watch(todayHabitProgressProvider);
    final allDone = ref.watch(allHabitsDoneProvider);
    final water = habits
        ?.where((h) => h.habit.key == HabitKeys.water)
        .firstOrNull;

    return Stack(
      children: [
        PetalPage(
          header: PetalPageHeader(
            overline: DateText.longDay(today),
            title: greeting,
            trailing: progress == null
                ? null
                : ProgressRing(done: progress.$1, total: progress.$2),
          ),
          children: [
            if (allDone) const _CelebrationBanner(),
            const MoodCheckIn(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: water == null
                        ? const SizedBox.shrink()
                        : WaterCard(water: water),
                  ),
                  const SizedBox(width: PetalSpacing.md),
                  const Expanded(child: SpentTodayCard()),
                ],
              ),
            ),
            if (habits != null) HabitsCard(habits: habits),
            const TodayTasksCard(),
          ],
        ),
        if (_showConfetti)
          Positioned.fill(
            child: ConfettiBurst(
              key: ValueKey(_burst),
              onDone: () {
                if (mounted) setState(() => _showConfetti = false);
              },
            ),
          ),
      ],
    );
  }
}

/// Shown while every habit is done today. A friendly message, no points.
class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.trophy, size: 30, color: palette.deep),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All habits done today!',
                    style: text.titleSmall?.copyWith(
                      color: palette.deep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Proud of you. Rest well tonight.',
                    style: text.bodySmall?.copyWith(color: PetalColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
