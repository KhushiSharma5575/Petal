import 'package:flutter_test/flutter_test.dart';
import 'package:petal/core/utils/dates.dart';
import 'package:petal/data/models/habit.dart';
import 'package:petal/data/repositories/expense_repository.dart';
import 'package:petal/data/repositories/habit_repository.dart';
import 'package:petal/data/repositories/mood_repository.dart';
import 'package:petal/data/repositories/settings_repository.dart';
import 'package:petal/data/repositories/task_repository.dart';
import 'package:petal/data/sample/demo_data.dart';
import 'package:petal/features/habits/logic/habit_logic.dart';
import 'package:petal/features/me/logic/insights.dart';
import 'package:petal/features/money/logic/money_logic.dart';

import '../helpers/test_db.dart';

void main() {
  test('demo data looks good on camera', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final now = DateTime(2026, 11, 22, 15);
    final today = dateOnly(now);
    await SettingsRepository(db).set(SettingKeys.userName, 'Khushi');
    await loadDemoData(db, now);
    await loadDemoData(db, now); // loading twice replaces, never doubles

    final habits = await HabitRepository(db).getHabits(today);
    expect(habits.map((h) => h.habit.name), containsAll(['Skincare', 'Journal']));
    expect(habits.where((h) => h.habit.name == 'Skincare'), hasLength(1));
    final meditate = habits.firstWhere((h) => h.habit.key == HabitKeys.meditate);
    expect(streakOf(meditate, today), greaterThanOrEqualTo(12));

    final expenses = await ExpenseRepository(db).getAll();
    final budgets = await ExpenseRepository(db).getBudgets();
    final usage = budgetUsage(expenses, budgets, today);
    expect(usage.any((u) => u.over), isTrue);
    expect(usage.any((u) => !u.nearLimit), isTrue);

    final moods = await MoodRepository(db).moodsBetween(
      addDays(today, -insightDays),
      today,
    );
    final insights = findInsights(
      habits: habits,
      moods: moods,
      expenses: expenses,
      today: today,
    );
    expect(insights, isNotEmpty);
    expect(
      insights,
      contains('You feel happier on days you work out.'),
    );

    final tasks = await TaskRepository(db).getAll();
    expect(tasks.where((t) => !t.done && t.dueDate == today), hasLength(3));
    expect(await SettingsRepository(db).get(SettingKeys.userName), 'Khushi');
  });
}
