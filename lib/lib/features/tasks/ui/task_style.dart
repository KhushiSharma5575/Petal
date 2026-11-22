import 'package:material_ui/material_ui.dart';

import '../../../data/models/task.dart';

/// Colours used only by the task UI. Checked in contrast_test.dart.
abstract final class TaskColors {
  /// Overdue text/accents (6:1 on white).
  static const overdue = Color(0xFFA33A3A);
  static const overdueSoft = Color(0xFFFDE7E7);
  static const overdueBorder = Color(0xFFF6C9C9);

  /// "High" label.
  static const highBg = Color(0xFFFFE4D6);
  static const highFg = Color(0xFFA9471F);

  /// Tick-box border per priority. These are control boundaries, so they
  /// must reach 3:1 against white. Darker than the prototype's originals
  /// (#E0663A / #D9A21B / #9A93AC), which didn't.
  static Color priority(TaskPriority p) => switch (p) {
    TaskPriority.high => const Color(0xFFD0501F),
    TaskPriority.medium => const Color(0xFFA77A0A),
    TaskPriority.low => const Color(0xFF857D96),
  };

  /// List chip (background, text).
  static (Color, Color) list(TaskList l) => switch (l) {
    TaskList.work => (const Color(0xFFEFE8FD), const Color(0xFF5B3FA0)),
    TaskList.personal => (const Color(0xFFDDF5EA), const Color(0xFF1F6E48)),
    TaskList.study => (const Color(0xFFE3F3FC), const Color(0xFF22618C)),
    TaskList.shopping => (const Color(0xFFFFE6EF), const Color(0xFFA3365F)),
  };
}
