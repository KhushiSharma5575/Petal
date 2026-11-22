import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_tokens.dart';
import '../../../data/models/habit.dart';
import '../state/habits_providers.dart';
import 'habit_style.dart';

/// Add a habit of your own, or rename / change the goal of [existing].
Future<void> showHabitEditor(BuildContext context, {Habit? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => HabitEditorSheet(existing: existing),
  );
}

/// Ideas shown as chips when adding, so starting is one tap.
const habitIdeas = [
  'Sleep by 11',
  'No sugar',
  'Skincare',
  'Journal',
  'Walk 10k steps',
  'Vitamins',
  'Practise coding',
];

class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({super.key, this.existing});
  final Habit? existing;

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late HabitType _type = widget.existing?.type ?? HabitType.check;
  late final _goal = TextEditingController(
    text: widget.existing == null || widget.existing!.type == HabitType.check
        ? ''
        : '${widget.existing!.goal}',
  );
  String? _nameError;
  String? _goalError;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  int? _parseGoal() {
    if (_type == HabitType.check) return 1;
    final n = int.tryParse(_goal.text.trim());
    final max = _type == HabitType.minutes ? 720 : 100;
    return n != null && n >= 1 && n <= max ? n : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final goal = _parseGoal();
    setState(() {
      _nameError = name.isEmpty ? 'Give it a name, like "Skincare"' : null;
      _goalError = goal == null
          ? (_type == HabitType.minutes
                ? 'Enter minutes from 1 to 720'
                : 'Enter a number from 1 to 100')
          : null;
    });
    if (_nameError != null || goal == null) return;
    _saving = true;
    final controller = ref.read(habitsControllerProvider);
    try {
      if (_isNew) {
        await controller.addHabit(name: name, type: _type, goal: goal);
      } else {
        await controller.updateHabit(widget.existing!, name: name, goal: goal);
      }
    } finally {
      _saving = false;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final habit = widget.existing!;
    final controller = ref.read(habitsControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await controller.hide(habit);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('Removed ${habit.name}. Its history is kept.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.bringBack(habit),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final existing = widget.existing;
    // Water powers its own card and the home-screen widget, so it stays.
    final canRemove = existing != null && existing.key != HabitKeys.water;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'New habit' : 'Edit habit', style: text.titleLarge),
            const SizedBox(height: PetalSpacing.lg),
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Skincare',
                errorText: _nameError,
                prefixIcon: Icon(
                  Habit(
                    id: existing?.id ?? 0,
                    key: existing?.key ?? 'custom',
                    name: _name.text,
                    type: _type,
                    goal: 1,
                  ).icon,
                ),
              ),
            ),
            if (_isNew) ...[
              const SizedBox(height: PetalSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final idea in habitIdeas)
                    ActionChip(
                      label: Text(idea),
                      onPressed: () => setState(() {
                        _name.text = idea;
                        if (idea.contains('steps')) _type = HabitType.check;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: PetalSpacing.lg),
              Text('How do you track it?', style: text.titleSmall),
              const SizedBox(height: PetalSpacing.sm),
              SegmentedButton<HabitType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: HabitType.check, label: Text('Tick')),
                  ButtonSegment(
                    value: HabitType.minutes,
                    label: Text('Minutes'),
                  ),
                  ButtonSegment(value: HabitType.count, label: Text('Count')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _goalError = null;
                  if (_goal.text.isEmpty && _type == HabitType.minutes) {
                    _goal.text = '30';
                  }
                  if (_goal.text.isEmpty && _type == HabitType.count) {
                    _goal.text = '3';
                  }
                }),
              ),
            ],
            if (_type != HabitType.check) ...[
              const SizedBox(height: PetalSpacing.lg),
              TextField(
                controller: _goal,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Daily goal',
                  suffixText: _type == HabitType.minutes ? 'min' : 'times',
                  errorText: _goalError,
                ),
              ),
            ],
            const SizedBox(height: PetalSpacing.xl),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: PetalColors.ink,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_isNew ? 'Add habit' : 'Save'),
            ),
            if (canRemove) ...[
              const SizedBox(height: PetalSpacing.sm),
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Remove habit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
