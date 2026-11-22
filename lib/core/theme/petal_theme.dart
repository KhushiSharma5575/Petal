import 'package:material_ui/material_ui.dart';

import 'petal_palette.dart';
import 'petal_text.dart';
import 'petal_tokens.dart';

/// Builds the Material 3 theme for the chosen [accent].
///
/// Material widgets (buttons, inputs, switches, sheets) are pre-styled here so
/// feature screens rarely need to set colours or shapes themselves.
ThemeData buildPetalTheme(PetalAccent accent) {
  final p = accent.palette;
  final textTheme = buildPetalTextTheme();

  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: p.deep, // deep, not accent: text/icons on it must pass contrast
    onPrimary: Colors.white,
    primaryContainer: p.soft,
    onPrimaryContainer: p.deep,
    secondary: p.accent,
    onSecondary: PetalColors.text,
    secondaryContainer: p.soft,
    onSecondaryContainer: p.deep,
    error: const Color(0xFFC0392B),
    onError: Colors.white,
    surface: PetalColors.surface,
    onSurface: PetalColors.text,
    onSurfaceVariant: PetalColors.textSecondary,
    outline: const Color(0xFFD9D1E8),
    outlineVariant: PetalColors.divider,
    surfaceContainerLowest: PetalColors.surface,
    surfaceContainerLow: PetalColors.surface,
    surfaceContainer: PetalColors.surface,
    surfaceContainerHigh: PetalColors.surface,
    surfaceContainerHighest: p.soft,
    shadow: PetalColors.shadowTint,
  );

  const controlShape = RoundedRectangleBorder(
    borderRadius: PetalRadii.controlRadius,
  );
  const minButton = Size(PetalSpacing.minTouch, PetalSpacing.minTouch);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PetalColors.background,
    canvasColor: PetalColors.background,
    fontFamily: PetalFonts.body,
    textTheme: textTheme,
    // Keep touch targets at 48dp even on compact widgets.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    extensions: [p],
    iconTheme: const IconThemeData(color: PetalColors.text, size: 22),
    dividerTheme: const DividerThemeData(
      color: PetalColors.divider,
      thickness: 1,
      space: 1,
    ),
    cardTheme: const CardThemeData(
      color: PetalColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: PetalRadii.cardRadius),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.deep,
        foregroundColor: Colors.white,
        minimumSize: minButton,
        shape: controlShape,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.deep,
        minimumSize: minButton,
        shape: controlShape,
        side: BorderSide(color: p.soft, width: 2),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.deep,
        minimumSize: minButton,
        shape: controlShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: minButton,
        foregroundColor: PetalColors.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PetalColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: PetalColors.textSecondary,
      ),
      border: const OutlineInputBorder(
        borderRadius: PetalRadii.controlRadius,
        borderSide: BorderSide(color: PetalColors.divider, width: 1.5),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: PetalRadii.controlRadius,
        borderSide: BorderSide(color: PetalColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PetalRadii.controlRadius,
        borderSide: BorderSide(color: p.deep, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.soft,
      selectedColor: p.deep,
      // Selected chips have a deep background, so their label and checkmark
      // must turn white (otherwise the text is invisible).
      labelStyle: textTheme.labelMedium?.copyWith(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.deep,
        ),
      ),
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PetalColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PetalColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      actionTextColor: p.soft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.deep : p.soft,
      ),
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
