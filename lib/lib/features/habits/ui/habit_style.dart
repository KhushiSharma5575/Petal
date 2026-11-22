import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_tokens.dart';
import '../../../data/models/habit.dart';

/// Icon and pastel tile for each habit. Habits the user adds get an icon
/// that matches their name.
extension HabitStyle on Habit {
  IconData get icon => switch (key) {
    HabitKeys.water => LucideIcons.glassWater,
    HabitKeys.workout => LucideIcons.dumbbell,
    HabitKeys.study => LucideIcons.bookOpen,
    HabitKeys.meditate => LucideIcons.flower2,
    HabitKeys.read => LucideIcons.bookMarked,
    _ => _iconForName(name),
  };

  Color get tile => switch (key) {
    HabitKeys.water => PetalColors.tileSky,
    HabitKeys.workout => PetalColors.tilePeach,
    HabitKeys.study => PetalColors.tileLavender,
    HabitKeys.meditate => PetalColors.tileMint,
    HabitKeys.read => PetalColors.tilePink,
    _ => _customTiles[id % _customTiles.length],
  };
}

const _customTiles = [
  PetalColors.tileButter,
  PetalColors.tileMint,
  PetalColors.tileSky,
  PetalColors.tilePink,
  PetalColors.tilePeach,
  PetalColors.tileLavender,
];

/// A fitting icon for a habit the user named themselves.
IconData _iconForName(String name) {
  final n = name.toLowerCase();
  bool has(String words) => RegExp('\\b(?:$words)').hasMatch(n);
  if (has('sleep|bed|nap')) return LucideIcons.moon;
  if (has('walk|steps|run|jog')) return LucideIcons.footprints;
  if (has('cycl|bike')) return LucideIcons.bike;
  if (has('sugar|sweet|junk|chocolate')) return LucideIcons.candyOff;
  if (has('smok|cigarette')) return LucideIcons.cigaretteOff;
  if (has('alcohol|drink|beer|wine')) return LucideIcons.wineOff;
  if (has('phone|screen|social|insta|scroll')) return LucideIcons.phoneOff;
  if (has('journal|diary|writ|gratitude')) return LucideIcons.notebookPen;
  if (has('skin|face|hair|brush|teeth|floss')) return LucideIcons.sparkles;
  if (has('vitamin|medicine|pill|tablet')) return LucideIcons.pill;
  if (has('fruit|veg|salad|eat|diet|protein')) return LucideIcons.salad;
  if (has('music|guitar|piano|sing|practi')) return LucideIcons.music;
  if (has('code|coding|leetcode|dsa|program')) return LucideIcons.code;
  if (has('language|french|german|spanish|hindi|english')) {
    return LucideIcons.languages;
  }
  if (has('yoga|stretch')) return LucideIcons.flower2;
  if (has('pray|pooja|puja|gratitude')) return LucideIcons.hand;
  if (has('plant|garden|water the')) return LucideIcons.leaf;
  if (has('dog|pet|cat')) return LucideIcons.dog;
  if (has('sun|morning|early')) return LucideIcons.sun;
  return LucideIcons.heart;
}

/// Colours for the Water and Spent cards (checked in contrast_test.dart).
abstract final class TodayCardColors {
  /// Water card text on sky.
  static const waterText = Color(0xFF22618C);

  /// Glass outline on sky (a control boundary, so >= 3:1).
  static const glassOutline = Color(0xFF3B7FAE);
  static const glassFill = Color(0xFFA9D8F5);

  /// Spent card secondary text on butter.
  static const spentText = Color(0xFF6B5520);

  /// Streak label (flame) on white.
  static const streak = Color(0xFFA9471F);
}
