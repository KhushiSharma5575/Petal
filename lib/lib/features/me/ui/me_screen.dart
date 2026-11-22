import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../core/widgets/petal_page.dart';
import '../../../core/widgets/text_dialogs.dart';
import '../../habits/ui/habit_week_grid.dart';
import '../../mood/ui/mood_calendar.dart';
import '../../mood/ui/mood_face.dart';
import '../logic/insights.dart';
import '../state/me_providers.dart';
import 'settings_section.dart';

/// Me: name + weekly snapshot, then Habits / Mood / Settings.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(meSectionProvider);
    return PetalPage(
      header: const _Header(),
      children: [
        const _SnapshotCard(),
        SegmentedButton<MeSection>(
          showSelectedIcon: false,
          segments: [
            for (final s in MeSection.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {section},
          onSelectionChanged: (s) =>
              ref.read(meSectionProvider.notifier).select(s.first),
        ),
        ...switch (section) {
          MeSection.habits => const [HabitWeekGrid(), WeeklyPlanCard()],
          MeSection.mood => const [MoodCalendar()],
          MeSection.settings => const [SettingsSection()],
        },
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userNameProvider).value ?? '';
    final palette = context.palette;

    Future<void> editName() async {
      final controller = ref.read(meControllerProvider);
      final r = await showTextFieldsDialog(
        context,
        title: 'Your name',
        fields: [(label: 'First name', initial: name, hint: null)],
      );
      if (r != null) await controller.setName(r.first);
    }

    return Row(
      children: [
        Semantics(
          button: true,
          label: name.isEmpty ? 'Add your name' : 'Change your name',
          onTap: editName,
          excludeSemantics: true,
          child: InkWell(
            onTap: editName,
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.soft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: name.isEmpty
                  ? Icon(LucideIcons.flower2, color: palette.deep, size: 26)
                  : Text(
                      name.characters.first.toUpperCase(),
                      style: nunito(
                        FontWeight.w800,
                        size: 24,
                        color: palette.deep,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: PetalSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Me' : 'Hi, $name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (name.isEmpty)
                TextButton(
                  onPressed: editName,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: const Text('Add your name'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnapshotCard extends ConsumerWidget {
  const _SnapshotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(weekSnapshotProvider);
    if (s == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final moods = ref.watch(recentMoodsProvider).value ?? const {};
    final mood = weekMood(moods, ref.watch(todayProvider));
    final insights = ref.watch(insightsProvider) ?? const [];

    return PetalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Your week so far', style: text.titleMedium),
                ),
              ),
              if (mood != null) ...[
                Text('Mostly ', style: text.bodySmall),
                MoodFace(mood: mood, size: 22),
                const SizedBox(width: 4),
                Text(
                  mood.label.toLowerCase(),
                  style: nunito(
                    FontWeight.w800,
                    size: 13,
                    color: PetalColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: PetalSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(value: '${s.tasksDone}', label: 'Tasks done'),
              ),
              Expanded(
                child: _Stat(
                  value: '${s.habitsKeptPercent}%',
                  label: 'Habits kept',
                ),
              ),
              Expanded(
                child: _Stat(value: formatRupees(s.spent), label: 'Spent'),
              ),
            ],
          ),
          const SizedBox(height: PetalSpacing.md),
          Text(
            s.insight,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: PetalSpacing.md),
            Container(
              padding: const EdgeInsets.all(PetalSpacing.md),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: PetalRadii.controlRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 16, color: palette.deep),
                      const SizedBox(width: 6),
                      Text(
                        'Petal noticed',
                        style: nunito(
                          FontWeight.w800,
                          size: 13,
                          color: palette.deep,
                        ),
                      ),
                    ],
                  ),
                  for (final i in insights.take(2)) ...[
                    const SizedBox(height: 6),
                    Text(i, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: nunito(FontWeight.w800, size: 20, color: PetalColors.text),
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
