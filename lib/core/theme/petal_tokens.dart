import 'package:material_ui/material_ui.dart';

/// Raw design tokens for Petal. Every colour, radius and spacing value in the
/// app should come from here (or from [PetalPalette] via the theme) so the look
/// stays consistent and themes can be swapped in one place.
abstract final class PetalColors {
  // Base surfaces & text.
  static const background = Color(0xFFFFF7F2); // warm cream
  static const surface = Color(0xFFFFFFFF); // cards
  static const text = Color(0xFF3B3355);
  static const textSecondary = Color(0xFF6E6485);
  static const divider = Color(0xFFF1ECFA);

  /// Dark ink used for the raised mic button (matches the prototype).
  static const ink = Color(0xFF3B3355);

  // Pastel tiles (backgrounds only; never for text).
  static const tilePeach = Color(0xFFFFE4D6);
  static const tileLavender = Color(0xFFEFE8FD);
  static const tileMint = Color(0xFFDDF5EA);
  static const tilePink = Color(0xFFFFE6EF);
  static const tileSky = Color(0xFFE3F3FC);
  static const tileButter = Color(0xFFFFF1D6);

  // Mood faces.
  static const moodGreat = Color(0xFFFFD966);
  static const moodGood = Color(0xFFAEE5A4);
  static const moodOkay = Color(0xFFA9D8F5);
  static const moodLow = Color(0xFFCDBDF5);
  static const moodBad = Color(0xFFFFAFAF);

  /// Soft purple tint used in every shadow.
  static const shadowTint = Color(0xFF5B3FA0);
}

abstract final class PetalRadii {
  static const double card = 24;
  static const double control = 16; // buttons & inputs
  static const double chip = 999; // fully rounded
  static const double navTop = 28;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const controlRadius = BorderRadius.all(Radius.circular(control));
}

abstract final class PetalSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double page = 18;

  /// Minimum touch target (Material / accessibility guideline).
  static const double minTouch = 48;
}

abstract final class PetalShadows {
  /// Very soft, purple-tinted card shadow: 0 4px 16px rgba(91,63,160,0.08).
  static const card = [
    BoxShadow(
      color: Color(0x145B3FA0), // 8% alpha
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Shadow cast upward by the bottom navigation bar.
  static const nav = [
    BoxShadow(
      color: Color(0x1A5B3FA0), // 10% alpha
      offset: Offset(0, -6),
      blurRadius: 20,
    ),
  ];

  /// Deeper shadow under the raised mic button.
  static const mic = [
    BoxShadow(
      color: Color(0x4D3B3355), // 30% alpha
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];
}
