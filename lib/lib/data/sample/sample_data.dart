import '../../core/config/app_config.dart';
import '../../core/utils/clock_time.dart';
import '../../core/utils/dates.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/mood.dart';
import '../models/task.dart';
import '../repositories/expense_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/mood_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/task_repository.dart';

/// DEBUG ONLY: about a month of spends across categories, and budgets that
/// show a mix of states (one near its limit, one over). Runs once, never in
/// release.
Future<void> seedSampleMoneyIfNeeded({
  required ExpenseRepository money,
  required SettingsRepository settings,
  required DateTime today,
}) async {
  if (!AppConfig.useSampleData) return;
  if (await settings.getFlag(SettingKeys.sampleMoneySeeded)) return;
  await settings.setFlag(SettingKeys.sampleMoneySeeded, true);

  final t = dateOnly(today);
  // (days ago, rupees, category, note)
  const spends = [
    (0, 180, ExpenseCategory.food, 'Lunch'),
    (0, 120, ExpenseCategory.travel, 'Auto'),
    (1, 650, ExpenseCategory.food, 'Groceries'),
    (1, 250, ExpenseCategory.fun, 'Movie'),
    (2, 700, ExpenseCategory.bills, 'Internet bill'),
    (3, 90, ExpenseCategory.food, 'Chai and snacks'),
    (4, 1499, ExpenseCategory.shopping, 'Running shoes'),
    (5, 320, ExpenseCategory.health, 'Pharmacy'),
    (6, 220, ExpenseCategory.travel, 'Uber'),
    (8, 1200, ExpenseCategory.food, 'Dinner out'),
    (9, 1850, ExpenseCategory.bills, 'Electricity bill'),
    (11, 540, ExpenseCategory.food, 'Groceries'),
    (12, 899, ExpenseCategory.shopping, 'T-shirt'),
    (14, 150, ExpenseCategory.travel, 'Metro card'),
    (16, 400, ExpenseCategory.fun, 'Bowling'),
    (18, 760, ExpenseCategory.food, 'Groceries'),
    (21, 500, ExpenseCategory.health, 'Gym day pass'),
    (24, 300, ExpenseCategory.food, 'Pizza'),
  ];
  for (final (ago, rupees, category, note) in spends) {
    await money.add(
      ExpenseDraft(
        amount: rupees * 100,
        category: category,
        note: note,
        date: addDays(t, -ago),
      ),
    );
  }
  const budgets = {
    ExpenseCategory.food: 5000,
    ExpenseCategory.bills: 2500,
    ExpenseCategory.shopping: 2000,
    ExpenseCategory.travel: 1500,
    ExpenseCategory.fun: 1000,
  };
  for (final MapEntry(key: c, value: rupees) in budgets.entries) {
    await money.setBudget(c, rupees * 100);
  }
}

/// DEBUG ONLY: a week of habit history (so streaks show), a weekly plan,
/// past moods and a few glasses of water today. Today's other habits and
/// mood are left for you to tick. Runs once, never in release.
Future<void> seedSampleHabitsIfNeeded({
  required HabitRepository habits,
  required MoodRepository moods,
  required SettingsRepository settings,
  required DateTime today,
}) async {
  if (!AppConfig.useSampleData) return;
  if (await settings.getFlag(SettingKeys.sampleHabitsSeeded)) return;
  await settings.setFlag(SettingKeys.sampleHabitsSeeded, true);

  final t = dateOnly(today);
  final byKey = {
    for (final h in await habits.getHabits(t)) h.habit.key: h.habit,
  };

  // Past 6 days: water and reading every day (6-day streaks), workout most
  // days, study and meditation with gaps.
  for (var i = 1; i <= 6; i++) {
    final day = addDays(t, -i);
    await habits.setValue(byKey[HabitKeys.water]!.id, day, 8);
    await habits.setValue(byKey[HabitKeys.read]!.id, day, 1);
    if (i != 4) await habits.setValue(byKey[HabitKeys.workout]!.id, day, 1);
    if (i.isOdd) await habits.setValue(byKey[HabitKeys.study]!.id, day, 120);
    if (i <= 2) await habits.setValue(byKey[HabitKeys.meditate]!.id, day, 1);
  }
  await habits.setValue(byKey[HabitKeys.water]!.id, t, 3);
  await habits.setValue(byKey[HabitKeys.study]!.id, t, 45);

  const plan = [
    ('Legs', 'Maths'),
    ('Upper body', 'Physics'),
    ('Yoga', 'Revision'),
    ('Cardio 30 min', 'Maths'),
    ('Full body', 'Chemistry'),
    ('Long walk', ''),
    ('Rest day', ''),
  ];
  for (final (i, (workout, focus)) in plan.indexed) {
    await habits.setPlan(
      PlanDay(weekday: i + 1, workout: workout, studyFocus: focus),
    );
  }

  const pastMoods = [Mood.good, Mood.great, Mood.okay, Mood.good, Mood.low];
  for (final (i, m) in pastMoods.indexed) {
    await moods.setMood(addDays(t, -(i + 1)), m);
  }
}

/// Adds a handful of example tasks the first time a DEBUG build runs, so
/// there's something to look at. Never runs in release builds
/// ([AppConfig.useSampleData] is compile-time false there), and only once:
/// deleting the samples won't bring them back.
Future<void> seedSampleDataIfNeeded({
  required TaskRepository tasks,
  required SettingsRepository settings,
  required DateTime today,
}) async {
  if (!AppConfig.useSampleData) return;
  if (await settings.getFlag(SettingKeys.sampleDataSeeded)) return;
  await settings.setFlag(SettingKeys.sampleDataSeeded, true);
  if (await tasks.count() > 0) return;

  final t = dateOnly(today);
  final samples = [
    TaskDraft(
      title: 'Pay electricity bill',
      dueDate: addDays(t, -2),
      priority: TaskPriority.high,
      list: TaskList.personal,
    ),
    TaskDraft(
      title: 'Send weekly report to client',
      dueDate: t,
      dueTime: const ClockTime(17, 0),
      priority: TaskPriority.high,
      list: TaskList.work,
      reminder: true,
    ),
    TaskDraft(
      title: 'Revise chapter 4 notes',
      dueDate: t,
      list: TaskList.study,
      subtasks: const [
        SubtaskDraft(text: 'Read summary', done: true),
        SubtaskDraft(text: 'Make flashcards'),
        SubtaskDraft(text: 'Practice questions'),
      ],
    ),
    TaskDraft(
      title: 'Buy groceries',
      dueDate: addDays(t, 1),
      dueTime: const ClockTime(18, 30),
      priority: TaskPriority.low,
      list: TaskList.shopping,
      subtasks: const [
        SubtaskDraft(text: 'Milk'),
        SubtaskDraft(text: 'Spinach'),
      ],
    ),
    TaskDraft(
      title: 'Call the plumber',
      dueDate: addDays(t, 3),
      dueTime: const ClockTime(10, 0),
      list: TaskList.personal,
    ),
    const TaskDraft(title: 'Plan a weekend trip', list: TaskList.personal),
  ];
  for (final s in samples) {
    await tasks.create(s);
  }
  final doneId = await tasks.create(
    TaskDraft(
      title: 'Book dentist appointment',
      dueDate: addDays(t, -1),
      list: TaskList.personal,
    ),
  );
  await tasks.setDone(doneId, true);
}
