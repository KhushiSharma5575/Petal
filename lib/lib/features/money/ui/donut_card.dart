import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/motion.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/expense.dart';
import '../state/money_providers.dart';
import 'category_style.dart';

/// Donut of spending by category for the selected period, with the total in
/// the middle, a legend with amounts, and a one-line insight.
class DonutCard extends ConsumerWidget {
  const DonutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(moneySummaryProvider);
    if (s == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    final spoken = s.total == 0
        ? 'No spending ${s.period.label.toLowerCase()}'
        : 'Spent ${formatRupees(s.total)} ${s.period.label.toLowerCase()}. '
              '${s.totals.entries.map((e) => '${e.key.label} ${formatRupees(e.value)}').join(', ')}';

    // With large system text the legend goes under the donut instead of
    // beside it, so amounts never get squeezed.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;

    final donut = SizedBox.square(
      dimension: 132,
      child: TweenAnimationBuilder<double>(
        // Sweep in when data changes (instant with reduce motion).
        key: ValueKey(s.totals.toString()),
        tween: Tween(begin: 0, end: 1),
        duration: motionDuration(context, const Duration(milliseconds: 500)),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _DonutPainter(
            totals: s.totals,
            progress: t,
            track: context.palette.soft,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRupees(s.total),
                      style: nunito(
                        FontWeight.w800,
                        size: 18,
                        color: PetalColors.text,
                      ),
                    ),
                    Text(
                      s.period.noun == 'week' ? 'this week' : 'this month',
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final legend = s.totals.isEmpty
        ? Text(
            'Spends you add will show up here by category.',
            style: text.bodySmall,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in s.totals.entries)
                _LegendRow(category: e.key, amount: e.value),
            ],
          );

    return PetalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: spoken,
            excludeSemantics: true,
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: donut),
                      const SizedBox(height: PetalSpacing.md),
                      legend,
                    ],
                  )
                : Row(
                    children: [
                      donut,
                      const SizedBox(width: PetalSpacing.lg),
                      Expanded(child: legend),
                    ],
                  ),
          ),
          const SizedBox(height: PetalSpacing.md),
          Text(
            s.insight,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.category, required this.amount});
  final ExpenseCategory category;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: PetalSpacing.sm),
          Expanded(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PetalColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: PetalSpacing.sm),
          // Last resort for very long amounts: shrink rather than overflow.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatRupees(amount),
                style: nunito(
                  FontWeight.w800,
                  size: 13,
                  color: PetalColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.totals,
    required this.progress,
    required this.track,
  });

  final Map<ExpenseCategory, int> totals;
  final double progress;
  final Color track;

  static const _stroke = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );
    final total = totals.values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    // A small gap between segments (none when there's only one).
    final gap = totals.length > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    final available = math.pi * 2 * progress;
    for (final e in totals.entries) {
      final sweep = available * e.value / total;
      if (sweep - gap > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..strokeCap = StrokeCap.butt
            ..color = e.key.color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.totals != totals || old.track != track;
}
