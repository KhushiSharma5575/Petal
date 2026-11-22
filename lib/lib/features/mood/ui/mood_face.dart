import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_tokens.dart';
import '../../../data/models/mood.dart';

extension MoodStyle on Mood {
  Color get color => switch (this) {
    Mood.great => PetalColors.moodGreat,
    Mood.good => PetalColors.moodGood,
    Mood.okay => PetalColors.moodOkay,
    Mood.low => PetalColors.moodLow,
    Mood.bad => PetalColors.moodBad,
  };
}

/// A hand-drawn mood face: coloured circle, two dot eyes, a mouth curve,
/// and pink cheeks on the happy ones. Pure vector, no emoji.
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.mood, this.size = 40});

  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _FacePainter(mood)),
    );
  }
}

/// Drawn on a 40x40 grid (same geometry as the prototype) and scaled.
class _FacePainter extends CustomPainter {
  _FacePainter(this.mood);
  final Mood mood;

  static const _ink = PetalColors.text;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);

    canvas.drawCircle(const Offset(20, 20), 18, Paint()..color = mood.color);

    final cheekAlpha = switch (mood) {
      Mood.great => 0.45,
      Mood.good => 0.35,
      _ => 0.0,
    };
    if (cheekAlpha > 0) {
      final cheek = Paint()
        ..color = const Color(0xFFFF7896).withValues(alpha: cheekAlpha);
      canvas.drawCircle(const Offset(10.5, 23), 2.6, cheek);
      canvas.drawCircle(const Offset(29.5, 23), 2.6, cheek);
    }

    final eye = Paint()..color = _ink;
    canvas.drawCircle(const Offset(14, 17), 2.2, eye);
    canvas.drawCircle(const Offset(26, 17), 2.2, eye);

    final mouth = Path();
    switch (mood) {
      case Mood.great:
        mouth
          ..moveTo(12, 23)
          ..quadraticBezierTo(20, 32, 28, 23);
      case Mood.good:
        mouth
          ..moveTo(13, 24)
          ..quadraticBezierTo(20, 29.5, 27, 24);
      case Mood.okay:
        mouth
          ..moveTo(14, 26)
          ..lineTo(26, 26);
      case Mood.low:
        mouth
          ..moveTo(14, 28)
          ..quadraticBezierTo(20, 24, 26, 28);
      case Mood.bad:
        mouth
          ..moveTo(13, 29.5)
          ..quadraticBezierTo(20, 22, 27, 29.5);
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.mood != mood;
}
