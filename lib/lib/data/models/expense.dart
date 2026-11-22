/// Spending categories. Stored by [name].
enum ExpenseCategory {
  food('Food'),
  travel('Travel'),
  shopping('Shopping'),
  bills('Bills'),
  health('Health'),
  fun('Fun'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;

  static ExpenseCategory parse(String s) =>
      values.firstWhere((c) => c.name == s, orElse: () => other);
}

/// A saved expense. [amount] is in paise (₹1 = 100).
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
    required this.createdAt,
  });

  final int id;
  final int amount;
  final ExpenseCategory category;
  final String note;

  /// Calendar day of the spend (midnight).
  final DateTime date;
  final DateTime createdAt;

  ExpenseDraft toDraft() =>
      ExpenseDraft(amount: amount, category: category, note: note, date: date);
}

/// What the add/edit sheet produces.
class ExpenseDraft {
  const ExpenseDraft({
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
  });

  final int amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;

  bool get isValid => amount > 0;

  @override
  bool operator ==(Object other) =>
      other is ExpenseDraft &&
      other.amount == amount &&
      other.category == category &&
      other.note == note &&
      other.date == date;

  @override
  int get hashCode => Object.hash(amount, category, note, date);
}
