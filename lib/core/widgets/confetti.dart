import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/petal_palette.dart';
import '../utils/motion.dart';

/// A short, gentle burst of falling pastel confetti, played once.
///
/// Draws nothing at all when the user has "Remove animations" on, and never
/// blocks taps or TalkBack.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.onDone});

  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 3200);

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ConfettiBurst.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (reduceMotion(context)) {
      // Skip the animation entirely, but still report completion.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onDone?.call(),
      );
      return;
    }
    _controller.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    final accent = context.palette.accent;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_controller.value, accent),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.accent);

  final double t;
  final Color accent;

  static const _count = 28;
  static const _colors = [
    Color(0xFFFFD966),
    Color(0xFFFFBFD3),
    Color(0xFFA9D8F5),
    Color(0xFFAEE5C8),
    Color(0xFFCDBDF5),
    Color(0xFFFFC4A8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _count; i++) {
      // Deterministic spread (like the prototype): no randomness needed.
      final delay = (i % 7) * 0.04;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutQuad.transform(local);
      final x =
          size.width * (((i * 37) % 100) / 100) +
          math.sin(local * math.pi * 2 + i) * 12;
      final y = -24 + (size.height + 48) * eased;
      final angle = (i * 23 + local * 560) * math.pi / 180;
      final opacity = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      final color = i % 7 == 6 ? accent : _colors[i % _colors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4.5, -7.5, 9, 15),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
