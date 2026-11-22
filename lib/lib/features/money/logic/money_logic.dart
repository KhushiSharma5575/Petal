import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';

/// The "This week / This month" switch.
enum MoneyPeriod {
  week('This week', 'week'),
  month('This month', 'month');

  const MoneyPeriod(this.label, this.noun);
  final String label;
  final String noun;
}

/// First and last calendar day (inclusive) of [period] around [today].
/// Weeks run Monday to Sunday.
(DateTime, DateTime) rangeFor(MoneyPeriod period, DateTime today) {
  final t = dateOnly(today);
  switch (period) {
    case MoneyPeriod.week:
      final start = startOfWeek(t);
      return (start, addDays(start, 6));
    case MoneyPeriod.month:
      final start = DateTime(t.year, t.month, 1);
      return (start, DateTime(t.year, t.month + 1, 0));
  }
}

bool _within(DateTime d, (DateTime, DateTime) range) =>
    !d.isBefore(range.$1) && !d.isAfter(range.$2);

/// Paise spent per category within [range]. Categories with no spend are
/// left out. Sorted biggest first.
Map<ExpenseCategory, int> totalsByCategory(
  Iterable<Expense> expenses,
  (DateTime, DateTime) range,
) {
  final totals = <ExpenseCategory, int>{};
  for (final e in expenses) {
    if (_within(e.date, range)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in sorted) e.key: e.value};
}

/// Paise spent on one calendar [day].
int spentOn(Iterable<Expense> expenses, DateTime day) => expenses
    .where((e) => isSameDay(e.date, day))
    .fold(0, (sum, e) => sum + e.amount);

/// One friendly sentence about where the money went.
/// "Most of your month went on food: ₹6,200 (38%)"
String insightFor(MoneyPeriod period, Map<ExpenseCategory, int> totals) {
  final total = totals.values.fold(0, (a, b) => a + b);
  if (total == 0) return 'No spends yet this ${period.noun}.';
  final top = totals.entries.reduce((a, b) => b.value > a.value ? b : a);
  final pct = (top.value * 100 / total).round();
  if (totals.length == 1) {
    return 'All of your ${period.noun} went on '
        '${top.key.label.toLowerCase()}: ${formatRupees(top.value)}';
  }
  return 'Most of your ${period.noun} went on ${top.key.label.toLowerCase()}: '
      '${formatRupees(top.value)} ($pct%)';
}

/// How a category is doing against its monthly budget.
class BudgetUsage {
  const BudgetUsage({
    required this.category,
    required this.spent,
    required this.limit,
  });

  final ExpenseCategory category;
  final int spent;
  final int limit;

  /// 0..n (can go above 1 when over budget).
  double get fraction => limit <= 0 ? 0 : spent / limit;

  /// Past 80%: the bar turns peach.
  bool get nearLimit => fraction > 0.8;

  bool get over => spent > limit;
}

/// Budget use this month for every category that has a budget, most used
/// first.
List<BudgetUsage> budgetUsage(
  Iterable<Expense> expenses,
  Map<ExpenseCategory, int> budgets,
  DateTime today,
) {
  final month = totalsByCategory(expenses, rangeFor(MoneyPeriod.month, today));
  final list = [
    for (final MapEntry(key: c, value: limit) in budgets.entries)
      BudgetUsage(category: c, spent: month[c] ?? 0, limit: limit),
  ];
  list.sort((a, b) => b.fraction.compareTo(a.fraction));
  return list;
}

/// Share of the total monthly budget used so far (for "Spent today").
/// Null when no budgets are set.
double? monthBudgetFraction(
  Iterable<Expense> expenses,
  Map<ExpenseCategory, int> budgets,
  DateTime today,
) {
  final limit = budgets.values.fold(0, (a, b) => a + b);
  if (limit <= 0) return null;
  final spent = totalsByCategory(
    expenses,
    rangeFor(MoneyPeriod.month, today),
  ).values.fold(0, (a, b) => a + b);
  return spent / limit;
}

/// A gentle heads-up after adding [added], or null when every budget is
/// still fine. Only this month's spends count. The most serious one wins:
/// "Careful: this puts Shopping over budget by ₹400." beats
/// "Heads up: Food is at 85% of its budget."
String? budgetWarning({
  required Iterable<Expense> before,
  required Iterable<ExpenseDraft> added,
  required Map<ExpenseCategory, int> budgets,
  required DateTime today,
}) {
  final month = rangeFor(MoneyPeriod.month, today);
  final spentBefore = totalsByCategory(before, month);
  final addedBy = <ExpenseCategory, int>{};
  for (final d in added) {
    if (_within(d.date, month)) {
      addedBy[d.category] = (addedBy[d.category] ?? 0) + d.amount;
    }
  }
  String? near;
  for (final MapEntry(key: c, value: plus) in addedBy.entries) {
    final limit = budgets[c];
    if (limit == null || limit <= 0) continue;
    final was = spentBefore[c] ?? 0;
    final now = was + plus;
    final name = c.label;
    if (now > limit) {
      final over = formatRupees(now - limit);
      return was > limit
          ? 'Careful: $name is now over budget by $over.'
          : 'Careful: this puts $name over budget by $over.';
    }
    if (now > limit * 0.8 && near == null) {
      near =
          'Heads up: $name is at ${(now * 100 / limit).round()}% of its '
          'budget.';
    }
  }
  return near;
}
