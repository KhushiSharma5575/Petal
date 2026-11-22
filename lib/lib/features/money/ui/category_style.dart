import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_tokens.dart';
import '../../../data/models/expense.dart';

/// Icon, donut colour and pastel tile for each category.
extension CategoryStyle on ExpenseCategory {
  IconData get icon => switch (this) {
    ExpenseCategory.food => LucideIcons.utensils,
    ExpenseCategory.travel => LucideIcons.bus,
    ExpenseCategory.shopping => LucideIcons.shoppingBag,
    ExpenseCategory.bills => LucideIcons.receipt,
    ExpenseCategory.health => LucideIcons.heartPulse,
    ExpenseCategory.fun => LucideIcons.ticket,
    ExpenseCategory.other => LucideIcons.wallet,
  };

  /// Donut segment / legend dot. Mid-tone so segments are clearly visible
  /// on white (>= 3:1, checked in contrast_test.dart). Amounts are always
  /// shown as text too, so colour is never the only cue.
  Color get color => switch (this) {
    ExpenseCategory.food => const Color(0xFFD9653B),
    ExpenseCategory.travel => const Color(0xFF2F80BE),
    ExpenseCategory.shopping => const Color(0xFFC2457F),
    ExpenseCategory.bills => const Color(0xFF7A55D3),
    ExpenseCategory.health => const Color(0xFF23885A),
    ExpenseCategory.fun => const Color(0xFF9A7400),
    ExpenseCategory.other => const Color(0xFF6E6485),
  };

  Color get tile => switch (this) {
    ExpenseCategory.food => PetalColors.tilePeach,
    ExpenseCategory.travel => PetalColors.tileSky,
    ExpenseCategory.shopping => PetalColors.tilePink,
    ExpenseCategory.bills => PetalColors.tileLavender,
    ExpenseCategory.health => PetalColors.tileMint,
    ExpenseCategory.fun => PetalColors.tileButter,
    ExpenseCategory.other => PetalColors.divider,
  };
}

/// Budget bar colours.
abstract final class BudgetColors {
  /// Past 80% of a budget (spec: "turns peach"). A deeper peach so the bar
  /// still reads against its track.
  static const nearLimit = Color(0xFFE9895F);

  /// "Over by ₹500" text.
  static const overText = Color(0xFFA33A3A);
}
