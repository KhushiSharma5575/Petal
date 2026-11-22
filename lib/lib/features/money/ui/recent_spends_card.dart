import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/expense.dart';
import '../../tasks/logic/due_label.dart';
import '../state/money_providers.dart';
import 'category_style.dart';
import 'expense_editor_sheet.dart';

/// The last five spends. Tap one to edit or delete it.
class RecentSpendsCard extends ConsumerWidget {
  const RecentSpendsCard({super.key});

  static const shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider).value;
    if (expenses == null || expenses.isEmpty) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final text = Theme.of(context).textTheme;

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Recent spends', style: text.titleMedium),
          ),
          const SizedBox(height: PetalSpacing.xs),
          for (final e in expenses.take(shown))
            _SpendRow(expense: e, today: today),
        ],
      ),
    );
  }
}

class _SpendRow extends StatelessWidget {
  const _SpendRow({required this.expense, required this.today});
  final Expense expense;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final title = e.note.isEmpty ? e.category.label : e.note;
    final when = dueLabel(e.date, null, today);
    final meta = e.note.isEmpty ? when : '$when · ${e.category.label}';
    void open() => showExpenseEditor(context, existing: e);

    return Semantics(
      button: true,
      label: '$title, ${formatRupees(e.amount)}, $meta',
      hint: 'Edit spend',
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: e.category.tile,
                  shape: BoxShape.circle,
                ),
                child: Icon(e.category.icon, size: 20, color: PetalColors.text),
              ),
              const SizedBox(width: PetalSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(meta, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: PetalSpacing.sm),
              // Shrinks only if a huge amount meets very large text.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatRupees(e.amount),
                    style: nunito(
                      FontWeight.w800,
                      size: 15,
                      color: PetalColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
