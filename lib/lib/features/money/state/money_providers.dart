import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/file_saver.dart';
import '../../../core/utils/clock.dart';
import '../../../data/models/expense.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/expense_repository.dart';
import '../logic/csv_export.dart';
import '../logic/money_logic.dart';

/// Every expense, newest first, live.
final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});

/// Monthly budget per category (paise), live.
final budgetsProvider = StreamProvider<Map<ExpenseCategory, int>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchBudgets();
});

/// This week / This month.
class MoneyPeriodNotifier extends Notifier<MoneyPeriod> {
  @override
  MoneyPeriod build() => MoneyPeriod.month;

  void select(MoneyPeriod p) => state = p;
}

final moneyPeriodProvider = NotifierProvider<MoneyPeriodNotifier, MoneyPeriod>(
  MoneyPeriodNotifier.new,
);

class MoneySummary {
  const MoneySummary({
    required this.period,
    required this.totals,
    required this.total,
    required this.insight,
  });
  final MoneyPeriod period;
  final Map<ExpenseCategory, int> totals;
  final int total;
  final String insight;
}

/// Donut data for the selected period. Null while loading.
final moneySummaryProvider = Provider<MoneySummary?>((ref) {
  final expenses = ref.watch(expensesProvider).value;
  if (expenses == null) return null;
  final period = ref.watch(moneyPeriodProvider);
  final totals = totalsByCategory(
    expenses,
    rangeFor(period, ref.watch(todayProvider)),
  );
  return MoneySummary(
    period: period,
    totals: totals,
    total: totals.values.fold(0, (a, b) => a + b),
    insight: insightFor(period, totals),
  );
});

/// Budget usage this month, most used first. Null while loading.
final budgetUsageProvider = Provider<List<BudgetUsage>?>((ref) {
  final expenses = ref.watch(expensesProvider).value;
  final budgets = ref.watch(budgetsProvider).value;
  if (expenses == null || budgets == null) return null;
  return budgetUsage(expenses, budgets, ref.watch(todayProvider));
});

/// For the Today screen: spent today and share of the monthly budget used.
final spentTodayProvider = Provider<({int spent, double? monthFraction})>((
  ref,
) {
  final expenses = ref.watch(expensesProvider).value ?? const [];
  final budgets = ref.watch(budgetsProvider).value ?? const {};
  final today = ref.watch(todayProvider);
  return (
    spent: spentOn(expenses, today),
    monthFraction: monthBudgetFraction(expenses, budgets, today),
  );
});

/// Outcome of a CSV export, for the snackbar.
sealed class ExportResult {
  const ExportResult();
}

class ExportSaved extends ExportResult {
  const ExportSaved(this.location);
  final String location;
}

class ExportNothing extends ExportResult {
  const ExportNothing();
}

class ExportCancelled extends ExportResult {
  const ExportCancelled();
}

class ExportFailed extends ExportResult {
  const ExportFailed(this.message);
  final String message;
}

class MoneyController {
  MoneyController(this._ref);
  final Ref _ref;

  ExpenseRepository get _repo => _ref.read(expenseRepositoryProvider);

  Future<int> add(ExpenseDraft d) => _repo.add(d);
  Future<void> save(int id, ExpenseDraft d) => _repo.update(id, d);
  Future<Expense?> delete(int id) => _repo.delete(id);
  Future<void> undoDelete(Expense e) => _repo.restore(e);
  Future<void> setBudget(ExpenseCategory c, int? limit) =>
      _repo.setBudget(c, limit);

  /// What adding [drafts] would do to this month's budgets (call before
  /// saving). Null when all is fine.
  Future<String?> warningFor(Iterable<ExpenseDraft> drafts) async =>
      budgetWarning(
        before: await _repo.getAll(),
        added: drafts,
        budgets: await _repo.getBudgets(),
        today: _ref.read(todayProvider),
      );

  /// Writes every expense to a CSV in Downloads.
  Future<ExportResult> exportCsv() async {
    final all = await _repo.getAll();
    if (all.isEmpty) return const ExportNothing();
    try {
      final where = await _ref
          .read(fileSaverProvider)
          .saveToDownloads(
            name: csvFileName(_ref.read(todayProvider)),
            mimeType: 'text/csv',
            bytes: buildExpensesCsv(all),
          );
      return where == null ? const ExportCancelled() : ExportSaved(where);
    } on FileSaveException catch (e) {
      return ExportFailed(e.message);
    }
  }
}

final moneyControllerProvider = Provider<MoneyController>(MoneyController.new);
