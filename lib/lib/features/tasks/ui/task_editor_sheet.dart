import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/clock_time.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/task.dart';
import '../logic/due_label.dart';
import '../logic/due_shortcuts.dart';
import '../logic/reminder_time.dart';
import '../state/tasks_controller.dart';
import '../state/tasks_providers.dart';

/// Opens the sheet to add a new task, or to view/edit [existing].
///
/// [initial] pre-fills a new task (e.g. the day picked in the week strip).
Future<void> showTaskEditor(
  BuildContext context, {
  TaskItem? existing,
  TaskDraft? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Swiping down would close the sheet without the "Discard changes?"
    // check. Back and tapping outside still close it (with the check).
    enableDrag: false,
    builder: (_) => TaskEditorSheet(existing: existing, initial: initial),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, this.existing, this.initial});

  final TaskItem? existing;
  final TaskDraft? initial;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TaskDraft _original;
  late TaskDraft _draft;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _newSubtask = TextEditingController();

  /// Message under the "Remind me" switch when reminders can't work fully.
  ReminderPermissionResult? _permission;

  /// Set right before we close the sheet ourselves, so the "discard
  /// changes?" check doesn't block it.
  bool _closing = false;

  bool get _isNew => widget.existing == null;
  bool get _dirty => _draft != _original;

  @override
  void initState() {
    super.initState();
    _original =
        widget.existing?.toDraft() ?? widget.initial ?? const TaskDraft();
    _draft = _original;
    _title = TextEditingController(text: _draft.title);
    _notes = TextEditingController(text: _draft.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _newSubtask.dispose();
    super.dispose();
  }

  void _update(TaskDraft d) => setState(() => _draft = d);

  void _close() {
    _closing = true;
    Navigator.of(context).pop();
  }

  // --- actions ---------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return; // a quick double tap must not add it twice
    _addSubtask(); // keep a subtask that was typed but not added yet
    if (!_draft.isValid) return;
    _saving = true;
    final controller = ref.read(tasksControllerProvider);
    try {
      if (_isNew) {
        await controller.add(_draft);
      } else if (_dirty) {
        await controller.save(widget.existing!.id, _draft);
      }
    } finally {
      _saving = false;
    }
    if (mounted) _close();
  }

  bool _saving = false;

  Future<void> _toggleDone() async {
    final existing = widget.existing!;
    final controller = ref.read(tasksControllerProvider);
    if (_dirty && _draft.isValid) await controller.save(existing.id, _draft);
    await controller.setDone(existing, !existing.done);
    if (mounted) _close();
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final controller = ref.read(tasksControllerProvider);
    // Grab the messenger before the sheet closes.
    final messenger = ScaffoldMessenger.of(context);
    _close();
    final deleted = await controller.delete(existing.id);
    if (deleted == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('Deleted "${deleted.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.undoDelete(deleted),
          ),
        ),
      );
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final initial = _draft.dueDate ?? today;
    var first = addDays(today, -365);
    var last = addDays(today, 365 * 5);
    // A very old (or far-off) due date must still fit the picker's range.
    if (initial.isBefore(first)) first = initial;
    if (initial.isAfter(last)) last = initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _update(_draft.copyWith(dueDate: dateOnly(picked)));
  }

  Future<void> _pickTime() async {
    final current = _draft.dueTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null) {
      _update(_draft.copyWith(dueTime: ClockTime(picked.hour, picked.minute)));
    }
  }

  Future<void> _setReminder(bool on) async {
    _update(_draft.copyWith(reminder: on));
    if (!on) {
      setState(() => _permission = null);
      return;
    }
    final result = await ref
        .read(tasksControllerProvider)
        .ensureReminderPermission();
    if (mounted) setState(() => _permission = result);
  }

  void _addSubtask() {
    final text = _newSubtask.text.trim();
    if (text.isEmpty) return;
    _update(
      _draft.copyWith(
        subtasks: [
          ..._draft.subtasks,
          SubtaskDraft(text: text),
        ],
      ),
    );
    _newSubtask.clear();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this task will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final lead = ref.watch(reminderLeadProvider).value ?? 15;
    final hasDate = _draft.dueDate != null;

    return PopScope(
      canPop: _closing || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) _close();
      },
      child: Padding(
        // Lift the sheet above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PetalSpacing.xl,
            0,
            PetalSpacing.xl,
            PetalSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isNew ? 'New task' : 'Edit task', style: text.titleLarge),
              const SizedBox(height: PetalSpacing.lg),
              TextField(
                controller: _title,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'What do you need to do?',
                  labelText: 'Title',
                ),
                onChanged: (v) => _update(_draft.copyWith(title: v)),
                onSubmitted: (_) => _isNew ? _save() : null,
              ),

              _Label('When'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in DueShortcut.values) _whenChip(s, today),
                ],
              ),

              _Label('Time'),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: hasDate ? _pickTime : null,
                    icon: const Icon(LucideIcons.clock, size: 18),
                    label: Text(_draft.dueTime?.format() ?? 'Add time'),
                  ),
                  if (_draft.dueTime != null)
                    IconButton(
                      tooltip: 'Remove time',
                      onPressed: () =>
                          _update(_draft.copyWith(clearDueTime: true)),
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                  if (!hasDate) ...[
                    const SizedBox(width: PetalSpacing.md),
                    Expanded(
                      child: Text('Pick a day first', style: text.bodySmall),
                    ),
                  ],
                ],
              ),

              _Label('Priority'),
              SegmentedButton<TaskPriority>(
                showSelectedIcon: false,
                segments: [
                  for (final p in TaskPriority.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_draft.priority},
                onSelectionChanged: (s) =>
                    _update(_draft.copyWith(priority: s.first)),
              ),

              _Label('List'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in TaskList.values)
                    ChoiceChip(
                      label: Text(l.label),
                      selected: _draft.list == l,
                      onSelected: (_) => _update(_draft.copyWith(list: l)),
                    ),
                ],
              ),

              const SizedBox(height: PetalSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Remind me', style: text.titleSmall),
                subtitle: Text(
                  hasDate
                      ? reminderHint(_draft.dueTime, lead)
                      : 'Pick a day to get a reminder',
                  style: text.bodySmall,
                ),
                secondary: const Icon(LucideIcons.bell),
                value: _draft.reminder,
                onChanged: hasDate ? _setReminder : null,
              ),
              if (_draft.reminder) _permissionNote(),

              if (!_isNew) ..._detailSections(text),

              const SizedBox(height: PetalSpacing.xl),
              _isNew
                  ? FilledButton(
                      onPressed: _draft.isValid ? _save : null,
                      child: const Text('Add task'),
                    )
                  : _detailActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whenChip(DueShortcut s, DateTime today) {
    final current = shortcutFor(_draft.dueDate, today);
    final selected = current == s;
    final label = s == DueShortcut.pick && selected
        ? shortDate(_draft.dueDate!)
        : s.label;
    return ChoiceChip(
      label: Text(label),
      avatar: s == DueShortcut.pick
          ? const Icon(LucideIcons.calendarDays, size: 16)
          : null,
      selected: selected,
      onSelected: (_) {
        switch (s) {
          case DueShortcut.pick:
            _pickDate();
          case DueShortcut.none:
            _update(_draft.copyWith(clearDueDate: true));
          default:
            _update(_draft.copyWith(dueDate: resolveShortcut(s, today)));
        }
      },
    );
  }

  Widget _permissionNote() {
    final text = Theme.of(context).textTheme;
    switch (_permission) {
      case ReminderPermissionResult.blocked:
        return Text(
          'Notifications are turned off for Petal. Turn them on in your '
          'phone\'s Settings > Apps > Petal > Notifications.',
          style: text.bodySmall,
        );
      case ReminderPermissionResult.inexact:
        return Row(
          children: [
            Expanded(
              child: Text(
                'Without the "Alarms & reminders" permission, Android may send reminders up to an hour late.',
                style: text.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(tasksControllerProvider).openExactTimingSettings(),
              child: const Text('Allow'),
            ),
          ],
        );
      case ReminderPermissionResult.ok:
      case null:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _detailSections(TextTheme text) {
    final palette = context.palette;
    return [
      _Label('Notes'),
      TextField(
        controller: _notes,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Add details'),
        onChanged: (v) => _update(_draft.copyWith(notes: v)),
      ),

      _Label('Subtasks'),
      for (final (i, s) in _draft.subtasks.indexed)
        Row(
          children: [
            Checkbox(
              value: s.done,
              semanticLabel: s.text,
              onChanged: (v) {
                final subs = [..._draft.subtasks];
                subs[i] = s.copyWith(done: v ?? false);
                _update(_draft.copyWith(subtasks: subs));
              },
            ),
            Expanded(
              child: Text(
                s.text,
                style: text.bodyMedium?.copyWith(
                  color: s.done ? PetalColors.textSecondary : null,
                  decoration: s.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove subtask: ${s.text}',
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => _update(
                _draft.copyWith(subtasks: [..._draft.subtasks]..removeAt(i)),
              ),
            ),
          ],
        ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newSubtask,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Add a subtask'),
              onSubmitted: (_) => _addSubtask(),
            ),
          ),
          const SizedBox(width: PetalSpacing.sm),
          IconButton.filledTonal(
            tooltip: 'Add subtask',
            style: IconButton.styleFrom(
              backgroundColor: palette.soft,
              foregroundColor: palette.deep,
            ),
            onPressed: _addSubtask,
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
    ];
  }

  Widget _detailActions() {
    final done = widget.existing!.done;
    return Row(
      children: [
        IconButton(
          tooltip: 'Delete task',
          onPressed: _delete,
          icon: const Icon(LucideIcons.trash2),
        ),
        const SizedBox(width: PetalSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleDone,
            icon: Icon(
              done ? LucideIcons.rotateCcw : LucideIcons.check,
              size: 18,
            ),
            label: Text(done ? 'Not done' : 'Mark done'),
          ),
        ),
        const SizedBox(width: PetalSpacing.sm),
        Expanded(
          child: FilledButton(
            onPressed: _draft.isValid ? _save : null,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: PetalSpacing.lg,
        bottom: PetalSpacing.sm,
      ),
      child: Text(
        text,
        style: nunito(
          FontWeight.w800,
          size: 13,
          color: PetalColors.textSecondary,
        ),
      ),
    );
  }
}
