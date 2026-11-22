import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/motion.dart';
import '../../../data/models/habit.dart';
import '../logic/habit_logic.dart';
import '../state/habits_providers.dart';
import 'habit_style.dart';

/// Water: tappable glasses (8 = 3 litres by default).
///
/// For TalkBack the glasses act as one adjustable control: swipe up/down to
/// add or remove a glass.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.water});

  final HabitWithLogs water;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final goal = water.habit.goal;
    final value = water.valueOn(today);
    final controller = ref.read(habitsControllerProvider);
    void set(int v) => controller.setToday(water.habit, v.clamp(0, goal));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: PetalColors.tileSky,
        borderRadius: PetalRadii.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Water',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '$value/$goal',
                style: nunito(
                  FontWeight.w800,
                  size: 12,
                  color: TodayCardColors.waterText,
                ),
              ),
            ],
          ),
          const SizedBox(height: PetalSpacing.sm),
          Semantics(
            label: 'Water',
            value: '$value of $goal glasses, ${litresText(value)}',
            increasedValue: '${(value + 1).clamp(0, goal)} of $goal glasses',
            decreasedValue: '${(value - 1).clamp(0, goal)} of $goal glasses',
            onIncrease: value < goal ? () => set(value + 1) : null,
            onDecrease: value > 0 ? () => set(value - 1) : null,
            excludeSemantics: true,
            // Rows of 4 equal cells. Plain Rows (not LayoutBuilder) so the
            // card can sit inside the IntrinsicHeight row on Today.
            child: Column(
              children: [
                for (var row = 0; row * _perRow < goal; row++)
                  Row(
                    children: [
                      for (var col = 0; col < _perRow; col++)
                        Expanded(
                          child: row * _perRow + col < goal
                              ? SizedBox(
                                  height: 44,
                                  child: InkResponse(
                                    onTap: () => set(
                                      waterAfterTap(value, row * _perRow + col),
                                    ),
                                    radius: 20,
                                    child: Center(
                                      child: _Glass(
                                        full: row * _perRow + col < value,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: PetalSpacing.xs),
          Text(
            '${litresText(value)} of ${litresText(goal)}',
            style: nunito(
              FontWeight.w700,
              size: 12,
              color: TodayCardColors.waterText,
            ),
          ),
        ],
      ),
    );
  }
}

const _perRow = 4;

class _Glass extends StatelessWidget {
  const _Glass({required this.full});
  final bool full;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: full ? 1 : 0),
      duration: motionDuration(context, const Duration(milliseconds: 220)),
      builder: (context, fill, _) =>
          CustomPaint(size: const Size(22, 30), painter: _GlassPainter(fill)),
    );
  }
}

/// A tumbler drawn on the prototype's 30x40 grid; [fill] 0..1 animates the
/// water level.
class _GlassPainter extends CustomPainter {
  _GlassPainter(this.fill);
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 30, size.height / 40);
    final glass = Path()
      ..moveTo(4, 4)
      ..lineTo(26, 4)
      ..lineTo(23, 36)
      ..quadraticBezierTo(22.6, 38, 20.5, 38)
      ..lineTo(9.5, 38)
      ..quadraticBezierTo(7.4, 38, 7, 36)
      ..close();

    if (fill > 0) {
      canvas.save();
      canvas.clipPath(glass);
      final top = 38 - 34 * fill;
      canvas.drawRect(
        Rect.fromLTRB(0, top, 30, 40),
        Paint()..color = TodayCardColors.glassFill,
      );
      canvas.restore();
    }
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = TodayCardColors.glassOutline,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.fill != fill;
}
