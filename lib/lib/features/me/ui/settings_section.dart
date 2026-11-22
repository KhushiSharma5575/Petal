import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/number_dialog.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../core/widgets/text_dialogs.dart';
import '../../../data/models/habit.dart';
import '../../habits/logic/habit_logic.dart';
import '../../habits/state/habits_providers.dart';
import '../../habits/ui/habit_editor_sheet.dart';
import '../../habits/ui/habit_style.dart';
import '../../money/state/money_providers.dart';
import '../../tasks/state/tasks_providers.dart';
import '../../welcome/welcome_screen.dart';
import '../state/me_providers.dart';

/// Settings: theme, name, habit goals, reminders, backup/export, about.
class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userNameProvider).value ?? '';
    final habits = ref.watch(habitsProvider).value ?? const [];
    Habit? habit(String key) =>
        habits.where((h) => h.habit.key == key).firstOrNull?.habit;
    final water = habit(HabitKeys.water);
    final study = habit(HabitKeys.study);
    final lead = ref.watch(reminderLeadProvider).value ?? 15;
    final waterEvery = ref.watch(waterReminderHoursProvider).value ?? 0;
    final me = ref.read(meControllerProvider);
    final earn = ref.watch(earnStreaksProvider).value ?? true;
    final steps = ref.watch(workoutStepsProvider).value ?? 1000;

    // Looked up now, not after a backup/restore finishes: by then this
    // section may be gone (e.g. switched to Habits).
    final messenger = ScaffoldMessenger.of(context);
    void snack(String message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(persist: false, content: Text(message)));
    }

    String exportMessage(ExportResult r, String what) => switch (r) {
      ExportSaved(:final location) => 'Saved to $location',
      ExportNothing() => 'Nothing to export yet',
      ExportCancelled() => '$what cancelled',
      ExportFailed(:final message) => 'Couldn\'t save: $message',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(title: 'Look', children: [const _ThemePicker()]),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'You',
          children: [
            _Tile(
              icon: LucideIcons.userRound,
              title: 'Your name',
              value: name.isEmpty ? 'Not set' : name,
              onTap: () async {
                final r = await showTextFieldsDialog(
                  context,
                  title: 'Your name',
                  fields: [(label: 'First name', initial: name, hint: null)],
                );
                if (r != null) await me.setName(r.first);
              },
            ),
            _Tile(
              icon: LucideIcons.sparkles,
              title: 'Show welcome screen',
              value: 'See the intro slides again',
              onTap: () => setWelcomeSeen(ref, false),
            ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'Habit goals',
          children: [
            if (water != null)
              _Tile(
                icon: LucideIcons.glassWater,
                title: 'Water',
                value: '${water.goal} glasses · ${litresText(water.goal)}',
                onTap: () async {
                  final r = await showNumberDialog<int>(
                    context,
                    title: 'Daily water goal',
                    label: 'Glasses',
                    suffixText: 'glasses',
                    initialText: '${water.goal}',
                    parse: (t) {
                      final n = int.tryParse(t);
                      return n != null && n >= 1 && n <= 16 ? n : null;
                    },
                    errorText: 'Choose 1 to 16 glasses',
                  );
                  if (r case NumberSaved(:final value)) {
                    await me.setHabitGoal(HabitKeys.water, value);
                  }
                },
              ),
            if (study != null)
              _Tile(
                icon: LucideIcons.bookOpen,
                title: 'Study',
                value: '${study.goal} min a day',
                onTap: () async {
                  final r = await showNumberDialog<int>(
                    context,
                    title: 'Daily study goal',
                    label: 'Minutes',
                    suffixText: 'min',
                    initialText: '${study.goal}',
                    parse: (t) {
                      final n = int.tryParse(t);
                      return n != null && n >= 10 && n <= 720 ? n : null;
                    },
                    errorText: 'Choose 10 to 720 minutes',
                  );
                  if (r case NumberSaved(:final value)) {
                    await me.setHabitGoal(HabitKeys.study, value);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'Earn your streaks',
          children: [
            SwitchListTile(
              secondary: const Icon(LucideIcons.flame),
              title: Text(
                'Prove it with your phone',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                'Workout counts steps, Study uses a face-down focus timer',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: earn,
              onChanged: (v) =>
                  ref.read(habitsControllerProvider).setEarnStreaks(v),
            ),
            if (earn)
              _Tile(
                icon: LucideIcons.footprints,
                title: 'Workout steps',
                value: '$steps steps, or a 20-min gym session',
                onTap: () async {
                  final r = await showNumberDialog<int>(
                    context,
                    title: 'Steps for a workout',
                    label: 'Steps',
                    suffixText: 'steps',
                    initialText: '$steps',
                    parse: (t) {
                      final n = int.tryParse(t);
                      return n != null && n >= 200 && n <= 30000 ? n : null;
                    },
                    errorText: 'Choose 200 to 30,000 steps',
                  );
                  if (r case NumberSaved(:final value)) {
                    await ref
                        .read(habitsControllerProvider)
                        .setWorkoutSteps(value);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'Your habits',
          children: [
            for (final h in habits)
              _Tile(
                icon: h.habit.icon,
                title: h.habit.name,
                value: switch (h.habit.type) {
                  HabitType.check => 'Tick once a day',
                  HabitType.minutes => '${h.habit.goal} min a day',
                  HabitType.count => '${h.habit.goal} times a day',
                },
                onTap: () => showHabitEditor(context, existing: h.habit),
              ),
            _Tile(
              icon: LucideIcons.plus,
              title: 'Add a habit',
              value: 'Skincare, journal, sleep on time...',
              onTap: () => showHabitEditor(context),
            ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'Reminders',
          children: [
            _Tile(
              icon: LucideIcons.bell,
              title: 'Task reminders',
              value: lead == 0 ? 'At the due time' : '$lead min before',
              onTap: () async {
                final r = await showChoiceDialog<int>(
                  context,
                  title: 'Remind me',
                  current: lead,
                  options: const [
                    (0, 'At the due time'),
                    (5, '5 minutes before'),
                    (10, '10 minutes before'),
                    (15, '15 minutes before'),
                    (30, '30 minutes before'),
                    (60, '1 hour before'),
                  ],
                );
                if (r != null) await me.setReminderLead(r);
              },
            ),
            _Tile(
              icon: LucideIcons.glassWater,
              title: 'Water reminders',
              value: waterEvery == 0
                  ? 'Off'
                  : 'Every $waterEvery hours, 9 am to 9 pm',
              onTap: () async {
                final r = await showChoiceDialog<int>(
                  context,
                  title: 'Water reminders',
                  current: waterEvery,
                  options: const [
                    (0, 'Off'),
                    (2, 'Every 2 hours'),
                    (3, 'Every 3 hours'),
                    (4, 'Every 4 hours'),
                  ],
                );
                if (r == null) return;
                final ok = await me.setWaterReminder(r);
                if (!ok) {
                  snack(
                    'Notifications are off for Petal. Turn them on in '
                    'Settings > Apps > Petal > Notifications.',
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'Your data',
          children: [
            // Test builds only: realistic data for demos and screenshots.
            if (kDebugMode)
              _Tile(
                icon: LucideIcons.clapperboard,
                title: 'Load demo data',
                value: 'For videos. Replaces tasks, habits, moods and spends',
                onTap: () async {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Load demo data?'),
                      content: const Text(
                        'This replaces your tasks, habits, moods, spends and '
                        'budgets with two months of example data. Your name '
                        'and theme stay. Back up first if you want to keep '
                        'what you have.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Load demo data'),
                        ),
                      ],
                    ),
                  );
                  if (sure != true) return;
                  await me.loadDemo();
                  snack('Demo data loaded');
                },
              ),
            _Tile(
              icon: LucideIcons.archive,
              title: 'Back up everything',
              value: 'Saves a file to Downloads',
              onTap: () async {
                final r = await me.backup();
                snack(exportMessage(r, 'Backup'));
              },
            ),
            _Tile(
              icon: LucideIcons.archiveRestore,
              title: 'Restore from a backup',
              value: 'Replaces everything in Petal',
              onTap: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Restore from a backup?'),
                    content: const Text(
                      'Everything in Petal now (tasks, habits, moods, spends '
                      'and settings) will be replaced by the backup you pick. '
                      'This can\'t be undone, so back up first if unsure.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Choose backup file'),
                      ),
                    ],
                  ),
                );
                if (sure != true) return;
                final message = await me.restore();
                if (message != null) snack(message);
              },
            ),
            _Tile(
              icon: LucideIcons.download,
              title: 'Export spends (CSV)',
              value: 'Opens in Excel or Sheets',
              onTap: () async {
                final r = await ref.read(moneyControllerProvider).exportCsv();
                snack(exportMessage(r, 'Export'));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Everything stays on this phone. Petal has no account and '
                'sends nothing anywhere.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: PetalSpacing.lg),
        _Group(
          title: 'About',
          children: [
            _Tile(
              icon: LucideIcons.info,
              title: 'Licences',
              value: 'Fonts and open-source packages',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Petal',
                applicationVersion: '0.1.0',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: nunito(
                FontWeight.w800,
                size: 12,
                color: PetalColors.textSecondary,
              ).copyWith(letterSpacing: 0.8),
            ),
          ),
        ),
        PetalCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon, color: context.palette.deep),
      title: Text(title, style: text.titleSmall),
      subtitle: Text(value, style: text.bodySmall),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: PetalColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// Lavender / Peach / Mint swatches.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(accentProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: PetalSpacing.sm),
          Row(
            children: [
              for (final a in PetalAccent.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: a == current,
                    label: '${a.label} theme',
                    onTap: () => setAccent(ref, a),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => setAccent(ref, a),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: a.palette.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: a == current
                                      ? a.palette.deep
                                      : a.palette.soft,
                                  width: a == current ? 4 : 6,
                                ),
                              ),
                              child: a == current
                                  ? const Icon(
                                      LucideIcons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a.label,
                              style: nunito(
                                FontWeight.w700,
                                size: 12,
                                color: a == current
                                    ? a.palette.deep
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
          ),
        ],
      ),
    );
  }
}
