import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';
import '../../tasks/logic/due_label.dart';
import '../state/money_providers.dart';
import 'category_style.dart';

/// Opens the sheet to add a spend, or edit/delete [existing].
Future<void> showExpenseEditor(BuildContext context, {Expense? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExpenseEditorSheet(existing: existing),
  );
}

class ExpenseEditorSheet extends ConsumerStatefulWidget {
  const ExpenseEditorSheet({super.key, this.existing});
  final Expense? existing;

  @override
  ConsumerState<ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends ConsumerState<ExpenseEditorSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late ExpenseCategory _category;
  late DateTime _date;
  String? _amountError;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
      text: e == null ? '' : rupeesPlain(e.amount),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? ExpenseCategory.food;
    _date = e?.date ?? ref.read(todayProvider);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return; // a quick double tap must not add it twice
    final paise = parseRupees(_amount.text);
    if (paise == null) {
      setState(() => _amountError = 'Enter an amount, like 250');
      return;
    }
    _saving = true;
    final draft = ExpenseDraft(
      amount: paise,
      category: _category,
      note: _note.text,
      date: _date,
    );
    final controller = ref.read(moneyControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    String? warning;
    try {
      if (_isNew) {
        warning = await controller.warningFor([draft]);
        await controller.add(draft);
      } else {
        await controller.save(widget.existing!.id, draft);
      }
    } finally {
      _saving = false;
    }
    if (mounted) Navigator.of(context).pop();
    if (warning != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 6),
            content: Text(warning),
          ),
        );
    }
  }

  Future<void> _delete() async {
    final controller = ref.read(moneyControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final deleted = await controller.delete(widget.existing!.id);
    if (deleted == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text('Deleted ${formatRupees(deleted.amount)} spend'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.undoDelete(deleted),
          ),
        ),
      );
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    var first = addDays(today, -365 * 3);
    var last = today; // spends can't be in the future...
    // ...but an old or odd date from a backup must still fit the picker.
    if (_date.isBefore(first)) first = _date;
    if (_date.isAfter(last)) last = _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final yesterday = addDays(today, -1);
    final isToday = isSameDay(_date, today);
    final isYesterday = isSameDay(_date, yesterday);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'Add a spend' : 'Edit spend', style: text.titleLarge),
            const SizedBox(height: PetalSpacing.lg),
            TextField(
              controller: _amount,
              autofocus: _isNew,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: nunito(FontWeight.w800, size: 28, color: PetalColors.text),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                prefixStyle: nunito(
                  FontWeight.w800,
                  size: 28,
                  color: PetalColors.textSecondary,
                ),
                errorText: _amountError,
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
            const SizedBox(height: PetalSpacing.md),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Lunch, internet bill...',
              ),
              onSubmitted: (_) => _save(),
            ),
            _Label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            _Label('When'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: isToday,
                  onSelected: (_) => setState(() => _date = today),
                ),
                ChoiceChip(
                  label: const Text('Yesterday'),
                  selected: isYesterday,
                  onSelected: (_) => setState(() => _date = yesterday),
                ),
                ChoiceChip(
                  avatar: const Icon(LucideIcons.calendarDays, size: 16),
                  label: Text(
                    isToday || isYesterday ? 'Pick a date' : shortDate(_date),
                  ),
                  selected: !isToday && !isYesterday,
                  onSelected: (_) => _pickDate(),
                ),
              ],
            ),
            const SizedBox(height: PetalSpacing.xl),
            if (_isNew)
              FilledButton(onPressed: _save, child: const Text('Add spend'))
            else
              Row(
                children: [
                  IconButton(
                    tooltip: 'Delete spend',
                    onPressed: _delete,
                    icon: const Icon(LucideIcons.trash2),
                  ),
                  const SizedBox(width: PetalSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
