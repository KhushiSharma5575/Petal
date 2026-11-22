import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/money.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/features/money/logic/csv_export.dart';
import 'package:petal/features/money/logic/money_logic.dart';

/// Saturday 14 November 2026.
final today = DateTime(2026, 11, 14);
DateTime d(int day, [int month = 11]) => DateTime(2026, month, day);

var _id = 1;
Expense e(int rupees, ExpenseCategory c, DateTime date, [String note = '']) =>
    Expense(
      id: _id++,
      amount: rupees * 100,
      category: c,
      note: note,
      date: date,
      createdAt: date,
    );

void main() {
  group('formatRupees', () {
    test('Indian grouping', () {
      expect(formatRupees(0), '₹0');
      expect(formatRupees(25000), '₹250');
      expect(formatRupees(620000), '₹6,200');
      expect(formatRupees(12345600), '₹1,23,456');
      expect(formatRupees(1234567800), '₹1,23,45,678');
    });
    test('paise only when non-zero', () {
      expect(formatRupees(25050), '₹250.50');
      expect(formatRupees(25005), '₹250.05');
      expect(formatRupees(-1500), '-₹15');
    });
  });

  group('parseRupees', () {
    test('accepts what people type', () {
      expect(parseRupees('250'), 25000);
      expect(parseRupees('250.5'), 25050);
      expect(parseRupees('250.05'), 25005);
      expect(parseRupees('1,200'), 120000);
      expect(parseRupees(' ₹ 99.99 '), 9999);
      expect(parseRupees('7.'), 700);
    });
    test('rejects junk, zero and too many decimals', () {
      for (final bad in ['', 'abc', '0', '0.00', '-5', '1.234', '1.2.3']) {
        expect(parseRupees(bad), isNull, reason: bad);
      }
    });
    test('rupeesPlain round-trips', () {
      expect(rupeesPlain(25050), '250.50');
      expect(rupeesPlain(25000), '250');
      expect(parseRupees(rupeesPlain(123456)), 123456);
    });
  });

  group('periods', () {
    test('week runs Monday to Sunday', () {
      expect(rangeFor(MoneyPeriod.week, today), (d(9), d(15)));
    });
    test('month is the calendar month', () {
      expect(rangeFor(MoneyPeriod.month, today), (d(1), d(30)));
      expect(rangeFor(MoneyPeriod.month, DateTime(2028, 2, 10)), (
        DateTime(2028, 2, 1),
        DateTime(2028, 2, 29),
      )); // leap year
    });
  });

  final expenses = [
    e(300, ExpenseCategory.food, d(14)),
    e(200, ExpenseCategory.food, d(9)),
    e(700, ExpenseCategory.bills, d(3)),
    e(100, ExpenseCategory.travel, d(13)),
    e(999, ExpenseCategory.fun, d(31, 10)), // last month
  ];

  test('totalsByCategory only counts the range, biggest first', () {
    final week = totalsByCategory(expenses, rangeFor(MoneyPeriod.week, today));
    expect(week, {ExpenseCategory.food: 50000, ExpenseCategory.travel: 10000});
    final month = totalsByCategory(
      expenses,
      rangeFor(MoneyPeriod.month, today),
    );
    expect(month.keys.toList(), [
      ExpenseCategory.bills,
      ExpenseCategory.food,
      ExpenseCategory.travel,
    ]);
  });

  test('spentOn', () {
    expect(spentOn(expenses, today), 30000);
    expect(spentOn(expenses, d(10)), 0);
  });

  group('insightFor', () {
    test('names the biggest category with amount and share', () {
      final month = totalsByCategory(
        expenses,
        rangeFor(MoneyPeriod.month, today),
      );
      expect(
        insightFor(MoneyPeriod.month, month),
        'Most of your month went on bills: ₹700 (54%)',
      );
    });
    test('single category and empty', () {
      expect(
        insightFor(MoneyPeriod.week, {ExpenseCategory.food: 5000}),
        'All of your week went on food: ₹50',
      );
      expect(insightFor(MoneyPeriod.week, {}), 'No spends yet this week.');
    });
  });

  group('budgets', () {
    final budgets = {
      ExpenseCategory.food: 60000, // 500/600 = 83% -> near limit
      ExpenseCategory.bills: 50000, // 700/500 -> over
      ExpenseCategory.health: 20000, // 0%
    };

    test('usage is this month only, most used first', () {
      final usage = budgetUsage(expenses, budgets, today);
      expect(usage.map((u) => u.category).toList(), [
        ExpenseCategory.bills,
        ExpenseCategory.food,
        ExpenseCategory.health,
      ]);
      expect(usage[0].over, isTrue);
      expect(usage[1].nearLimit, isTrue);
      expect(usage[1].over, isFalse);
      expect(usage[2].nearLimit, isFalse);
    });

    test('80% exactly is not yet "near"', () {
      const u = BudgetUsage(
        category: ExpenseCategory.fun,
        spent: 800,
        limit: 1000,
      );
      expect(u.nearLimit, isFalse);
    });

    test('monthBudgetFraction', () {
      expect(
        monthBudgetFraction(expenses, budgets, today),
        closeTo(1300 / 1300, 1e-9),
      );
      expect(monthBudgetFraction(expenses, {}, today), isNull);
    });
  });

  group('CSV', () {
    test('header, oldest first, BOM and CRLF', () {
      final bytes = buildExpensesCsv([
        e(250, ExpenseCategory.food, d(14), 'Lunch'),
        e(700, ExpenseCategory.bills, d(3), 'Internet'),
      ]);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.skip(3).toList());
      expect(
        text,
        'Date,Category,Amount (INR),Note\r\n'
        '2026-11-03,Bills,700,Internet\r\n'
        '2026-11-14,Food,250,Lunch\r\n',
      );
    });

    test('quotes commas/quotes/newlines and defuses formulas', () {
      final text = utf8.decode(
        buildExpensesCsv([
          e(1, ExpenseCategory.fun, d(1), 'Movie, popcorn'),
          e(1, ExpenseCategory.fun, d(2), 'He said "hi"'),
          e(1, ExpenseCategory.fun, d(3), '=HYPERLINK("x")'),
          e(1, ExpenseCategory.fun, d(4), 'line1\nline2'),
        ]).skip(3).toList(),
      );
      expect(text, contains('"Movie, popcorn"'));
      expect(text, contains('"He said ""hi"""'));
      expect(text, contains('"\'=HYPERLINK(""x"")"'));
      expect(text, contains('"line1\nline2"'));
    });

    test('file name', () {
      expect(csvFileName(today), 'petal-expenses-2026-11-14.csv');
    });
  });

  group('budget warning after a spend', () {
    ExpenseDraft spend(int rupees, ExpenseCategory c, [DateTime? on]) =>
        ExpenseDraft(amount: rupees * 100, category: c, date: on ?? today);
    final budgets = {
      ExpenseCategory.shopping: 200000,
      ExpenseCategory.food: 100000,
    };
    final before = [
      e(1700, ExpenseCategory.shopping, d(3)),
      e(500, ExpenseCategory.food, d(4)),
      e(5000, ExpenseCategory.shopping, d(20, 10)), // last month: ignored
    ];
    String? warn(List<ExpenseDraft> added) => budgetWarning(
      before: before,
      added: added,
      budgets: budgets,
      today: today,
    );

    test('crossing the limit', () {
      expect(
        warn([spend(400, ExpenseCategory.shopping)]),
        'Careful: this puts Shopping over budget by ₹100.',
      );
    });
    test('already over', () {
      expect(
        budgetWarning(
          before: [...before, e(500, ExpenseCategory.shopping, d(5))],
          added: [spend(50, ExpenseCategory.shopping)],
          budgets: budgets,
          today: today,
        ),
        'Careful: Shopping is now over budget by ₹250.',
      );
    });
    test('past 80%', () {
      expect(
        warn([spend(350, ExpenseCategory.food)]),
        'Heads up: Food is at 85% of its budget.',
      );
    });
    test('fine, no budget, or last month', () {
      expect(warn([spend(100, ExpenseCategory.food)]), isNull);
      expect(warn([spend(9000, ExpenseCategory.travel)]), isNull);
      expect(warn([spend(900, ExpenseCategory.shopping, d(30, 10))]), isNull);
    });
    test('over beats near when several are added', () {
      expect(
        warn([
          spend(350, ExpenseCategory.food),
          spend(400, ExpenseCategory.shopping),
        ]),
        startsWith('Careful: this puts Shopping'),
      );
    });
  });
}
