import 'package:material_ui/material_ui.dart';

/// The three user-selectable accent themes.
enum PetalAccent {
  lavender('Lavender'),
  peach('Peach'),
  mint('Mint');

  const PetalAccent(this.label);
  final String label;

  PetalPalette get palette => switch (this) {
    PetalAccent.lavender => PetalPalette.lavender,
    PetalAccent.peach => PetalPalette.peach,
    PetalAccent.mint => PetalPalette.mint,
  };
}

/// Accent colours for the active theme, exposed as a [ThemeExtension] so any
/// widget can read them with `context.palette`.
///
/// Contrast rules (checked in test/core/theme/contrast_test.dart):
/// - [deep] is safe for text/icons on white, cream and [soft] (>= 4.5:1).
/// - [accent] is decorative only (rings, dots, fills); never use it for text.
@immutable
class PetalPalette extends ThemeExtension<PetalPalette> {
  const PetalPalette({
    required this.accent,
    required this.deep,
    required this.soft,
  });

  final Color accent;
  final Color deep;
  final Color soft;

  static const lavender = PetalPalette(
    accent: Color(0xFF9B7FE0),
    deep: Color(0xFF5B3FA0),
    soft: Color(0xFFEFE8FD),
  );
  static const peach = PetalPalette(
    accent: Color(0xFFF29B76),
    deep: Color(0xFFA9471F),
    soft: Color(0xFFFFE7DA),
  );
  static const mint = PetalPalette(
    accent: Color(0xFF5CC08F),
    deep: Color(0xFF1F6E48),
    soft: Color(0xFFDDF5EA),
  );

  @override
  PetalPalette copyWith({Color? accent, Color? deep, Color? soft}) =>
      PetalPalette(
        accent: accent ?? this.accent,
        deep: deep ?? this.deep,
        soft: soft ?? this.soft,
      );

  @override
  PetalPalette lerp(PetalPalette? other, double t) {
    if (other == null) return this;
    return PetalPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      deep: Color.lerp(deep, other.deep, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

extension PetalPaletteContext on BuildContext {
  /// The active accent palette. Always present because [buildPetalTheme]
  /// registers it.
  PetalPalette get palette => Theme.of(this).extension<PetalPalette>()!;
}
