import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/db/app_database.dart';
import 'package:petal/data/models/expense.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  final now = DateTime(2026, 11, 14, 13, 0);
  late AppDatabase db;
  late ExpenseRepository repo;

  setUp(() {
    db = newTestDatabase();
    repo = ExpenseRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  ExpenseDraft draft(int paise, {DateTime? date, String note = ''}) =>
      ExpenseDraft(
        amount: paise,
        category: ExpenseCategory.food,
        note: note,
        date: date ?? DateTime(2026, 11, 14),
      );

  test('add, read back newest first, update', () async {
    await repo.add(draft(25000, date: DateTime(2026, 11, 13), note: ' Lunch '));
    final id = await repo.add(draft(18000));
    final all = await repo.getAll();
    expect(all.map((e) => e.amount), [18000, 25000]);
    expect(all.last.note, 'Lunch'); // trimmed

    await repo.update(
      id,
      ExpenseDraft(
        amount: 19900,
        category: ExpenseCategory.travel,
        note: 'Uber',
        date: DateTime(2026, 11, 14),
      ),
    );
    final updated = (await repo.getAll()).first;
    expect(updated.category, ExpenseCategory.travel);
    expect(updated.amount, 19900);
  });

  test('delete and restore keep the same id', () async {
    final id = await repo.add(draft(5000));
    final deleted = await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
    await repo.restore(deleted!);
    expect((await repo.getAll()).single.id, id);
  });

  test('budgets: set, replace, remove', () async {
    await repo.setBudget(ExpenseCategory.food, 800000);
    await repo.setBudget(ExpenseCategory.food, 600000);
    await repo.setBudget(ExpenseCategory.fun, 250000);
    expect(await repo.watchBudgets().first, {
      ExpenseCategory.food: 600000,
      ExpenseCategory.fun: 250000,
    });
    await repo.setBudget(ExpenseCategory.fun, null);
    expect(await repo.watchBudgets().first, {ExpenseCategory.food: 600000});
  });

  test(
    'upgrading a version-2 database adds money tables, keeps data',
    () async {
      // A version-2 database (no money tables) that already holds a habit.
      // Opening it must add the money tables without touching the habit.
      final upgraded = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(
            setup: (raw) {
              raw.execute(
                "CREATE TABLE habits (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,"
                " key TEXT NOT NULL UNIQUE, name TEXT NOT NULL, type TEXT NOT NULL,"
                " goal INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0,"
                " active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)))",
              );
              raw.execute(
                "INSERT INTO habits (key, name, type, goal) VALUES ('water', 'Water', 'count', 8)",
              );
              raw.execute(
                'CREATE TABLE habit_logs (habit_id INTEGER NOT NULL '
                'REFERENCES habits (id) ON DELETE CASCADE, date TEXT NOT NULL, '
                'value INTEGER NOT NULL, PRIMARY KEY (habit_id, date))',
              );
              raw.execute('PRAGMA user_version = 2');
            },
          ),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(upgraded.close);
      final money = ExpenseRepository(upgraded, clock: () => now);
      await money.add(draft(1000));
      await money.setBudget(ExpenseCategory.food, 5000);
      expect((await money.getAll()).single.amount, 1000);
      final kept = await HabitRepository(upgraded).getHabits(now);
      expect(kept.single.habit.key, 'water');
    },
  );
}
