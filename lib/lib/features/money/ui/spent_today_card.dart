import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/shell/nav_state.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/money.dart';
import '../../habits/ui/habit_style.dart';
import '../state/money_providers.dart';
import 'category_style.dart';

/// "Spent today" on the Today screen: today's total and how much of the
/// monthly budget is used. Tapping opens Money.
class SpentTodayCard extends ConsumerWidget {
  const SpentTodayCard({super.key});

  /// Bar fill on the butter card (normal use).
  static const _barColor = Color(0xFFE0A32E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:spent, :monthFraction) = ref.watch(spentTodayProvider);
    void open() => ref.read(navProvider.notifier).select(AppTab.money);
    final pct = monthFraction == null ? null : (monthFraction * 100).round();
    final note = pct == null
        ? 'No monthly budget set'
        : '$pct% of monthly budget used';

    return Semantics(
      button: true,
      label: 'Spent today, ${formatRupees(spent)}. $note. Open Money.',
      onTap: open,
      excludeSemantics: true,
      child: Material(
        color: PetalColors.tileButter,
        borderRadius: PetalRadii.cardRadius,
        child: InkWell(
          onTap: open,
          borderRadius: PetalRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spent today',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: TodayCardColors.spentText,
                    ),
                  ],
                ),
                const SizedBox(height: PetalSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupees(spent),
                    style: nunito(
                      FontWeight.w800,
                      size: 28,
                      color: PetalColors.text,
                    ),
                  ),
                ),
                const Spacer(),
                if (monthFraction != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: monthFraction.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.85),
                      color: monthFraction > 0.8
                          ? BudgetColors.nearLimit
                          : _barColor,
                    ),
                  ),
                  const SizedBox(height: PetalSpacing.xs),
                ],
                Text(
                  note,
                  style: nunito(
                    FontWeight.w700,
                    size: 12,
                    color: TodayCardColors.spentText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
