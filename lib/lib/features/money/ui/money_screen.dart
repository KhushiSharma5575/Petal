import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/petal_page.dart';
import '../logic/money_logic.dart';
import '../state/money_providers.dart';
import 'budgets_card.dart';
import 'donut_card.dart';
import 'expense_editor_sheet.dart';
import 'recent_spends_card.dart';

/// Money: week/month switch, donut by category, budgets, recent spends.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider).value;
    final period = ref.watch(moneyPeriodProvider);

    Future<void> export() async {
      final messenger = ScaffoldMessenger.of(context);
      final result = await ref.read(moneyControllerProvider).exportCsv();
      final message = switch (result) {
        ExportSaved(:final location) => 'Saved to $location',
        ExportNothing() => 'Nothing to export yet',
        ExportCancelled() => 'Export cancelled',
        ExportFailed(:final message) => 'Couldn\'t export: $message',
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(persist: false, content: Text(message)));
    }

    final header = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Money',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Export to CSV',
          onPressed: export,
          icon: const Icon(LucideIcons.download),
        ),
        const SizedBox(width: PetalSpacing.xs),
        FilledButton.icon(
          onPressed: () => showExpenseEditor(context),
          style: FilledButton.styleFrom(backgroundColor: PetalColors.ink),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Add'),
        ),
      ],
    );

    if (expenses == null) {
      return PetalPage(header: header, children: const []);
    }

    if (expenses.isEmpty) {
      return PetalPage(
        header: header,
        children: const [
          EmptyState(
            icon: LucideIcons.piggyBank,
            tileColor: PetalColors.tileMint,
            title: 'No spends yet',
            message: 'Tap Add to log your first spend.',
          ),
          BudgetsCard(),
        ],
      );
    }

    return PetalPage(
      header: header,
      children: [
        SegmentedButton<MoneyPeriod>(
          showSelectedIcon: false,
          segments: [
            for (final p in MoneyPeriod.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {period},
          onSelectionChanged: (s) =>
              ref.read(moneyPeriodProvider.notifier).select(s.first),
        ),
        const DonutCard(),
        const BudgetsCard(),
        const RecentSpendsCard(),
      ],
    );
  }
}
