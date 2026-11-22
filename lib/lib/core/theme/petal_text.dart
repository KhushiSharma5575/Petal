import 'package:material_ui/material_ui.dart';

import 'petal_tokens.dart';

/// Font family names, matching pubspec.yaml.
abstract final class PetalFonts {
  static const body = 'Nunito';
  static const heading = 'Pacifico';
}

/// A Nunito style at [weight].
///
/// Nunito is bundled as a *variable* font, so besides `fontWeight` we also set
/// the `wght` variation axis. Without it some Android versions draw every
/// weight as the font's default (Regular).
TextStyle nunito(
  FontWeight weight, {
  double? size,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontFamily: PetalFonts.body,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    fontSize: size,
    color: color,
    height: height,
  );
}

/// Pacifico heading style. Pacifico has a single weight, so we always ask for
/// w400 to avoid synthetic bolding.
TextStyle pacifico({double? size, Color? color}) {
  return TextStyle(
    fontFamily: PetalFonts.heading,
    fontWeight: FontWeight.w400,
    fontSize: size,
    color: color ?? PetalColors.text,
    height: 1.3,
  );
}

/// The app's [TextTheme]: Pacifico for display/headline, Nunito 600 to 800
/// for everything else. Sizes follow the prototype (title 30, body 14/15).
TextTheme buildPetalTextTheme() {
  const text = PetalColors.text;
  const secondary = PetalColors.textSecondary;
  return TextTheme(
    displaySmall: pacifico(size: 34),
    headlineMedium: pacifico(size: 30),
    headlineSmall: pacifico(size: 24),
    titleLarge: nunito(FontWeight.w800, size: 20, color: text),
    titleMedium: nunito(FontWeight.w800, size: 16, color: text),
    titleSmall: nunito(FontWeight.w700, size: 14, color: text),
    bodyLarge: nunito(FontWeight.w600, size: 16, color: text, height: 1.4),
    bodyMedium: nunito(FontWeight.w600, size: 14, color: text, height: 1.4),
    bodySmall: nunito(
      FontWeight.w600,
      size: 13,
      color: secondary,
      height: 1.35,
    ),
    labelLarge: nunito(FontWeight.w800, size: 15, color: text),
    labelMedium: nunito(FontWeight.w700, size: 13, color: secondary),
    labelSmall: nunito(FontWeight.w800, size: 11, color: secondary),
  );
}
