import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/petal_palette.dart';
import '../theme/petal_text.dart';
import '../theme/petal_tokens.dart';
import '../utils/motion.dart';

/// Small circular "3/5 habits" ring for the Today header.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.done,
    required this.total,
    this.caption = 'habits',
    this.size = 64,
  });

  final int done;
  final int total;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fraction = total == 0 ? 0.0 : done / total;
    return Semantics(
      container: true,
      label: '$done of $total $caption done today',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: motionDuration(context, const Duration(milliseconds: 400)),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _RingPainter(
              fraction: value,
              track: palette.soft,
              // Deep, not accent: the arc must stand out (3:1) on the track.
              color: palette.deep,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$done/$total',
                        style: nunito(
                          FontWeight.w800,
                          size: 16,
                          height: 1,
                          color: PetalColors.text,
                        ),
                      ),
                      Text(
                        caption,
                        style: nunito(
                          FontWeight.w700,
                          size: 9,
                          color: PetalColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.color,
  });

  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (fraction <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.color != color;
}
