import 'package:drift/drift.dart';

import '../../core/utils/dates.dart';
import '../db/app_database.dart';
import '../models/expense.dart';

/// Expenses and monthly budgets.
class ExpenseRepository {
  ExpenseRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  SimpleSelectStatement<$ExpensesTable, ExpenseRow> _newestFirst() =>
      _db.select(_db.expenses)..orderBy([
        (e) => OrderingTerm.desc(e.date),
        (e) => OrderingTerm.desc(e.createdAt),
        (e) => OrderingTerm.desc(e.id),
      ]);

  /// Every expense, newest first, live. (A personal log stays small enough
  /// to keep in memory: years of daily spends are a few thousand rows.)
  Stream<List<Expense>> watchAll() =>
      _newestFirst().watch().map((rows) => rows.map(_toExpense).toList());

  Future<List<Expense>> getAll() async =>
      (await _newestFirst().get()).map(_toExpense).toList();

  Future<int> add(ExpenseDraft d) => _db
      .into(_db.expenses)
      .insert(
        ExpensesCompanion.insert(
          amount: d.amount,
          category: d.category.name,
          note: Value(d.note.trim()),
          date: toIsoDate(d.date),
          createdAt: _now(),
        ),
      );

  Future<void> update(int id, ExpenseDraft d) =>
      (_db.update(_db.expenses)..where((e) => e.id.equals(id))).write(
        ExpensesCompanion(
          amount: Value(d.amount),
          category: Value(d.category.name),
          note: Value(d.note.trim()),
          date: Value(toIsoDate(d.date)),
        ),
      );

  /// Deletes and returns the expense so it can be restored (Undo).
  Future<Expense?> delete(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.expenses,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
    return _toExpense(row);
  });

  Future<void> restore(Expense e) => _db
      .into(_db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: Value(e.id),
          amount: e.amount,
          category: e.category.name,
          note: Value(e.note),
          date: toIsoDate(e.date),
          createdAt: e.createdAt,
        ),
      );

  // --- budgets ---------------------------------------------------------------

  /// Monthly limits in paise, only for categories that have one.
  Stream<Map<ExpenseCategory, int>> watchBudgets() =>
      _db.select(_db.budgets).watch().map(_toBudgets);

  Future<Map<ExpenseCategory, int>> getBudgets() async =>
      _toBudgets(await _db.select(_db.budgets).get());

  static Map<ExpenseCategory, int> _toBudgets(List<BudgetRow> rows) => {
    for (final r in rows) ExpenseCategory.parse(r.category): r.monthlyLimit,
  };

  /// Sets a category's monthly limit; null or 0 removes it.
  Future<void> setBudget(ExpenseCategory c, int? limit) {
    if (limit == null || limit <= 0) {
      return (_db.delete(
        _db.budgets,
      )..where((b) => b.category.equals(c.name))).go();
    }
    return _db
        .into(_db.budgets)
        .insertOnConflictUpdate(
          BudgetsCompanion.insert(category: c.name, monthlyLimit: limit),
        );
  }

  static Expense _toExpense(ExpenseRow r) => Expense(
    id: r.id,
    amount: r.amount,
    category: ExpenseCategory.parse(r.category),
    note: r.note,
    date: fromIsoDate(r.date),
    createdAt: r.createdAt,
  );
}
