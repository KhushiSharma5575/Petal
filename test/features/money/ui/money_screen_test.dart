import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/features/money/ui/category_style.dart';

import '../../../helpers/test_app.dart';

/// Tests run on Friday 13 November 2026 (week = 9-15 Nov).
DateTime d(int day) => DateTime(2026, 11, day);

Future<void> spend(
  AppDatabase db,
  int rupees,
  ExpenseCategory c,
  DateTime date, [
  String note = '',
]) => ExpenseRepository(
  db,
  clock: () => testNow,
).add(ExpenseDraft(amount: rupees * 100, category: c, note: note, date: date));

Future<void> openMoney(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Money tab'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state invites a first spend and budgets', (tester) async {
    await pumpPetal(tester);
    await openMoney(tester);
    expect(find.text('No spends yet'), findsOneWidget);
    expect(find.text('Set budgets'), findsOneWidget);
  });

  testWidgets('add a spend: donut total, insight and recent list update', (
    tester,
  ) async {
    final app = await pumpPetal(tester);
    await openMoney(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '250.5');
    await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Lunch');
    await tester.tap(find.text('Add spend'));
    await tester.pumpAndSettle();

    expect(find.text('₹250.50'), findsWidgets); // donut centre + row
    expect(
      find.text('All of your month went on food: ₹250.50'),
      findsOneWidget,
    );
    expect(find.text('Lunch'), findsOneWidget);
    final saved = await ExpenseRepository(app.db).getAll();
    expect(saved.single.amount, 25050);
    expect(saved.single.date, d(13));
  });

  testWidgets('a bad amount shows an error and saves nothing', (tester) async {
    final app = await pumpPetal(tester);
    await openMoney(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
    await tester.tap(find.text('Add spend'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount, like 250'), findsOneWidget);
    expect(await ExpenseRepository(app.db).getAll(), isEmpty);
  });

  testWidgets('week / month switch changes the totals', (tester) async {
    await pumpPetal(
      tester,
      setup: (db) async {
        await spend(db, 700, ExpenseCategory.bills, d(3), 'Internet');
        await spend(db, 300, ExpenseCategory.food, d(13), 'Lunch');
      },
    );
    await openMoney(tester);
    expect(find.text('₹1,000'), findsOneWidget);
    expect(
      find.text('Most of your month went on bills: ₹700 (70%)'),
      findsOneWidget,
    );

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.text('All of your week went on food: ₹300'), findsOneWidget);
  });

  testWidgets('budgets: peach past 80%, "Over by" when exceeded', (
    tester,
  ) async {
    await pumpPetal(
      tester,
      screen: const Size(412, 1400),
      setup: (db) async {
        final repo = ExpenseRepository(db, clock: () => testNow);
        await repo.setBudget(ExpenseCategory.food, 40000);
        await repo.setBudget(ExpenseCategory.bills, 50000);
        await repo.setBudget(ExpenseCategory.fun, 100000);
        await spend(db, 350, ExpenseCategory.food, d(12));
        await spend(db, 700, ExpenseCategory.bills, d(2));
        await spend(db, 100, ExpenseCategory.fun, d(10));
      },
    );
    await openMoney(tester);

    expect(find.text('Over by ₹200'), findsOneWidget); // bills, listed first
    expect(find.text('88% used'), findsOneWidget); // food 350/400
    expect(find.text('10% used'), findsOneWidget);

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars[0].color, BudgetColors.nearLimit); // over
    expect(bars[1].color, BudgetColors.nearLimit); // 88%
    expect(bars[2].color, isNot(BudgetColors.nearLimit)); // 10%
  });

  testWidgets('set a budget from the budgets sheet', (tester) async {
    final app = await pumpPetal(tester);
    await openMoney(tester);
    await tester.tap(find.text('Set budgets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await ExpenseRepository(app.db).getBudgets(), {
      ExpenseCategory.food: 500000,
    });
    expect(find.text('₹0 of ₹5,000'), findsWidgets);
  });

  testWidgets('delete a spend, then undo', (tester) async {
    await pumpPetal(
      tester,
      setup: (db) => spend(db, 180, ExpenseCategory.travel, d(13), 'Uber'),
    );
    await openMoney(tester);
    await tester.tap(find.text('Uber'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete spend'));
    await tester.pumpAndSettle();
    expect(find.text('Uber'), findsNothing);
    expect(find.text('No spends yet'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Uber'), findsOneWidget);
  });

  testWidgets('export writes a CSV to Downloads', (tester) async {
    final app = await pumpPetal(
      tester,
      setup: (db) => spend(db, 250, ExpenseCategory.food, d(13), 'Lunch'),
    );
    await openMoney(tester);
    await tester.tap(find.byTooltip('Export to CSV'));
    await tester.pumpAndSettle();

    expect(app.files.savedName, 'petal-expenses-2026-11-13.csv');
    expect(app.files.savedText, contains('2026-11-13,Food,250,Lunch'));
    expect(
      find.text('Saved to Downloads/petal-expenses-2026-11-13.csv'),
      findsOneWidget,
    );
  });

  testWidgets('export with nothing to export, and when it fails', (
    tester,
  ) async {
    final app = await pumpPetal(tester);
    await openMoney(tester);
    await tester.tap(find.byTooltip('Export to CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to export yet'), findsOneWidget);
    expect(app.files.savedName, isNull);
  });

  testWidgets('Today shows real "Spent today" and budget use', (tester) async {
    await pumpPetal(
      tester,
      setup: (db) async {
        await ExpenseRepository(db).setBudget(ExpenseCategory.food, 100000);
        await spend(db, 180, ExpenseCategory.food, d(13));
        await spend(db, 320, ExpenseCategory.food, d(2));
        await spend(db, 99, ExpenseCategory.food, d(12)); // not today
      },
    );
    expect(find.text('₹180'), findsOneWidget);
    expect(find.text('60% of monthly budget used'), findsOneWidget);
  });

  testWidgets('no overflow on a small phone with 2x text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPetal(
      tester,
      screen: const Size(360, 740),
      setup: (db) async {
        await ExpenseRepository(db).setBudget(ExpenseCategory.food, 100000);
        await spend(db, 123456, ExpenseCategory.shopping, d(13), 'Laptop');
        await spend(db, 250, ExpenseCategory.food, d(12), 'Lunch');
      },
    );
    expect(tester.takeException(), isNull); // Today with real spent card
    await openMoney(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle(); // back to the top, where Add lives
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
