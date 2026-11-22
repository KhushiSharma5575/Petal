import '../../../core/widgets/number_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/motion.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/expense.dart';
import '../logic/money_logic.dart';
import '../state/money_providers.dart';
import 'category_style.dart';

/// "Monthly budgets": the three most-used budgets, with See all.
class BudgetsCard extends ConsumerWidget {
  const BudgetsCard({super.key});

  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(budgetUsageProvider);
    if (usage == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Monthly budgets', style: text.titleMedium),
                ),
              ),
              TextButton(
                onPressed: () => showBudgetsSheet(context),
                child: Text(
                  usage.isEmpty ? 'Set budgets' : 'See all',
                  semanticsLabel: usage.isEmpty
                      ? 'Set budgets'
                      : 'See all budgets',
                ),
              ),
            ],
          ),
          if (usage.isEmpty)
            Text(
              'Set a monthly limit for a category to see how you\'re doing.',
              style: text.bodySmall,
            ),
          for (final u in usage.take(shown)) BudgetRow(usage: u),
        ],
      ),
    );
  }
}

/// One budget: icon, "₹4,200 of ₹6,000", and a bar that turns peach past
/// 80%. Tap to change the limit.
class BudgetRow extends ConsumerWidget {
  const BudgetRow({super.key, required this.usage});
  final BudgetUsage usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = usage;
    final text = Theme.of(context).textTheme;
    final pct = (u.fraction * 100).round();
    final status = u.over
        ? 'Over by ${formatRupees(u.spent - u.limit)}'
        : '$pct% used';
    void edit() => editBudget(context, ref, u.category, u.limit);

    return Semantics(
      button: true,
      label:
          '${u.category.label} budget: ${formatRupees(u.spent)} of '
          '${formatRupees(u.limit)}, $status',
      hint: 'Change limit',
      onTap: edit,
      excludeSemantics: true,
      child: InkWell(
        onTap: edit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _CategoryTile(category: u.category),
              const SizedBox(width: PetalSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(u.category.label, style: text.titleSmall),
                        ),
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: nunito(
                              FontWeight.w800,
                              size: 12,
                              color: u.over
                                  ? BudgetColors.overText
                                  : PetalColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: u.fraction.clamp(0.0, 1.0)),
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 300),
                        ),
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: PetalColors.divider,
                          color: u.nearLimit
                              ? BudgetColors.nearLimit
                              : context.palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatRupees(u.spent)} of ${formatRupees(u.limit)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: category.tile, shape: BoxShape.circle),
      child: Icon(category.icon, size: 20, color: PetalColors.text),
    );
  }
}

/// Bottom sheet listing every category with its budget (or "No budget").
Future<void> showBudgetsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _BudgetsSheet(),
  );
}

class _BudgetsSheet extends ConsumerWidget {
  const _BudgetsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(budgetUsageProvider) ?? const [];
    final byCategory = {for (final u in usage) u.category: u};
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monthly budgets', style: text.titleLarge),
          const SizedBox(height: PetalSpacing.xs),
          Text(
            'Tap a category to set or change its limit.',
            style: text.bodySmall,
          ),
          const SizedBox(height: PetalSpacing.md),
          for (final c in ExpenseCategory.values)
            if (byCategory[c] case final u?)
              BudgetRow(usage: u)
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _CategoryTile(category: c),
                title: Text(c.label, style: text.titleSmall),
                subtitle: Text('No budget', style: text.bodySmall),
                trailing: const Icon(LucideIcons.plus, size: 20),
                onTap: () => editBudget(context, ref, c, null),
              ),
        ],
      ),
    );
  }
}

/// Dialog to set, change or remove a category's monthly limit.
Future<void> editBudget(
  BuildContext context,
  WidgetRef ref,
  ExpenseCategory category,
  int? current,
) async {
  // Read the controller now: the calling row may be rebuilt or removed
  // while the dialog is open.
  final controller = ref.read(moneyControllerProvider);
  final result = await showNumberDialog<int>(
    context,
    title: '${category.label} budget',
    label: 'Per month',
    prefixText: '₹ ',
    allowDecimal: true,
    initialText: current == null ? '' : rupeesPlain(current),
    parse: parseRupees,
    errorText: 'Enter an amount, like 5000',
    showRemove: current != null,
  );
  switch (result) {
    case NumberSaved(:final value):
      await controller.setBudget(category, value);
    case NumberRemoved():
      await controller.setBudget(category, null);
    case null:
      return;
  }
}
