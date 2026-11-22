import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/core/theme/petal_palette.dart';
import 'package:petal/core/theme/petal_tokens.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/models/task.dart';
import 'package:petal/features/money/ui/category_style.dart';
import 'package:petal/features/habits/ui/habit_style.dart';
import 'package:petal/features/tasks/ui/task_style.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Text must be at least 4.5:1 (WCAG AA for normal text).
  const textMin = 4.5;
  // Icons/graphics need 3:1 (WCAG non-text contrast).
  const iconMin = 3.0;

  group('base text contrast', () {
    for (final (name, fg, bg) in const [
      ('text on cream', PetalColors.text, PetalColors.background),
      ('text on white', PetalColors.text, PetalColors.surface),
      ('secondary on cream', PetalColors.textSecondary, PetalColors.background),
      (
        'secondary on white (inactive nav)',
        PetalColors.textSecondary,
        PetalColors.surface,
      ),
      ('white on mic ink', Colors.white, PetalColors.ink),
    ]) {
      test(name, () => expect(contrast(fg, bg), greaterThanOrEqualTo(textMin)));
    }
  });

  group('task colours', () {
    test('overdue text on white and on its soft chip', () {
      expect(
        contrast(TaskColors.overdue, PetalColors.surface),
        greaterThanOrEqualTo(textMin),
      );
      expect(
        contrast(TaskColors.overdue, TaskColors.overdueSoft),
        greaterThanOrEqualTo(textMin),
      );
    });
    test('High label', () {
      expect(
        contrast(TaskColors.highFg, TaskColors.highBg),
        greaterThanOrEqualTo(textMin),
      );
    });
    for (final p in TaskPriority.values) {
      test('${p.label} priority tick border on white', () {
        expect(
          contrast(TaskColors.priority(p), PetalColors.surface),
          greaterThanOrEqualTo(iconMin),
        );
      });
    }
    for (final l in TaskList.values) {
      test('${l.label} list chip', () {
        final (bg, fg) = TaskColors.list(l);
        expect(contrast(fg, bg), greaterThanOrEqualTo(textMin));
      });
    }
  });

  group('Money colours', () {
    for (final c in ExpenseCategory.values) {
      test('${c.label} donut colour on white', () {
        expect(
          contrast(c.color, PetalColors.surface),
          greaterThanOrEqualTo(iconMin),
        );
      });
    }
    test('"Over by" text on white', () {
      expect(
        contrast(BudgetColors.overText, PetalColors.surface),
        greaterThanOrEqualTo(textMin),
      );
    });
  });

  group('Today card colours', () {
    test('water text and glass outline on sky', () {
      expect(
        contrast(TodayCardColors.waterText, PetalColors.tileSky),
        greaterThanOrEqualTo(textMin),
      );
      expect(
        contrast(TodayCardColors.glassOutline, PetalColors.tileSky),
        greaterThanOrEqualTo(iconMin),
      );
    });
    test('spent text on butter', () {
      expect(
        contrast(TodayCardColors.spentText, PetalColors.tileButter),
        greaterThanOrEqualTo(textMin),
      );
    });
    test('streak label on white', () {
      expect(
        contrast(TodayCardColors.streak, PetalColors.surface),
        greaterThanOrEqualTo(textMin),
      );
    });
    test('mood face ink on every mood colour', () {
      for (final c in const [
        PetalColors.moodGreat,
        PetalColors.moodGood,
        PetalColors.moodOkay,
        PetalColors.moodLow,
        PetalColors.moodBad,
      ]) {
        expect(contrast(PetalColors.text, c), greaterThanOrEqualTo(iconMin));
      }
    });
  });

  for (final accent in PetalAccent.values) {
    final p = accent.palette;
    group('${accent.label} palette', () {
      test('deep text on white', () {
        expect(
          contrast(p.deep, PetalColors.surface),
          greaterThanOrEqualTo(textMin),
        );
      });
      test('deep text on cream', () {
        expect(
          contrast(p.deep, PetalColors.background),
          greaterThanOrEqualTo(textMin),
        );
      });
      test('deep text on soft (chips, active nav pill)', () {
        expect(contrast(p.deep, p.soft), greaterThanOrEqualTo(textMin));
      });
      test('white text on deep (filled buttons)', () {
        expect(contrast(Colors.white, p.deep), greaterThanOrEqualTo(textMin));
      });
      test('deep icons on every pastel tile', () {
        for (final tile in const [
          PetalColors.tilePeach,
          PetalColors.tileLavender,
          PetalColors.tileMint,
          PetalColors.tilePink,
          PetalColors.tileSky,
          PetalColors.tileButter,
        ]) {
          expect(contrast(p.deep, tile), greaterThanOrEqualTo(iconMin));
        }
      });
    });
  }
}
