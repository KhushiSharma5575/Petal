import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/utils/clock_time.dart';
import '../../core/utils/dates.dart';
import '../db/app_database.dart';
import '../models/expense.dart';
import '../models/habit.dart';
import '../models/mood.dart';
import '../models/task.dart';
import '../repositories/expense_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/mood_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/task_repository.dart';

/// How far back the demo goes (enough for streaks, charts and insights).
const demoDays = 60;

/// DEBUG ONLY (the Settings button only shows in debug builds): replaces
/// all tasks, habits, moods, spends and budgets with about two months of
/// realistic data for a demo video. The name, theme and other settings are
/// kept. The same [seed] always gives the same data.
Future<void> loadDemoData(
  AppDatabase db,
  DateTime today, {
  int seed = 7,
}) async {
  final t = dateOnly(today);
  final rnd = Random(seed);
  final tasks = TaskRepository(db);
  final habits = HabitRepository(db);
  final moods = MoodRepository(db);
  final money = ExpenseRepository(db);
  final settings = SettingsRepository(db);

  await db.transaction(() async {
    await db.delete(db.subtasks).go();
    await db.delete(db.tasks).go();
    await db.delete(db.habitLogs).go();
    await db.delete(db.moods).go();
    await db.delete(db.weeklyPlan).go();
    await db.delete(db.expenses).go();
    await db.delete(db.budgets).go();
    await (db.delete(db.habits)..where((h) => h.key.like('custom_%'))).go();
    await db
        .update(db.habits)
        .write(const HabitsCompanion(active: Value(true)));
  });
  await habits.setGoal(HabitKeys.water, 8);
  await habits.setGoal(HabitKeys.study, 120);
  await habits.addHabit(name: 'Skincare', type: HabitType.check, goal: 1);
  await habits.addHabit(name: 'Journal', type: HabitType.check, goal: 1);
  for (final key in [
    SettingKeys.sampleDataSeeded,
    SettingKeys.sampleHabitsSeeded,
    SettingKeys.sampleMoneySeeded,
    SettingKeys.welcomeSeen,
  ]) {
    await settings.setFlag(key, true);
  }
  await settings.set(SettingKeys.workoutSession, '');

  // --- weekly plan ---------------------------------------------------------
  const plan = [
    ('Legs', 'Maths'),
    ('Upper body', 'Physics'),
    ('Yoga', 'Revision'),
    ('Cardio 30 min', 'Maths'),
    ('Full body', 'Chemistry'),
    ('Long walk', 'Mock test'),
    ('Rest day', ''),
  ];
  for (final (i, (workout, focus)) in plan.indexed) {
    await habits.setPlan(
      PlanDay(weekday: i + 1, workout: workout, studyFocus: focus),
    );
  }

  // --- habits and moods ----------------------------------------------------
  final byKey = {
    for (final h in await habits.getHabits(t)) h.habit.key: h.habit,
  };
  final skincare = byKey.values.firstWhere((h) => h.name == 'Skincare');
  final journal = byKey.values.firstWhere((h) => h.name == 'Journal');
  Future<void> log(Habit h, DateTime day, int v) =>
      habits.setValue(h.id, day, v);
  bool chance(double p) => rnd.nextDouble() < p;

  for (var i = demoDays; i >= 1; i--) {
    final day = addDays(t, -i);
    // Mondays are the hard day (an insight shows it); Sunday is rest.
    final slack = day.weekday == DateTime.monday ? 0.45 : 1.0;
    final recent = i <= 3; // a little workout streak going into today
    final worked =
        day.weekday != DateTime.sunday && (recent || chance(0.7 * slack));
    if (worked) await log(byKey[HabitKeys.workout]!, day, 1);
    // Meditation: an unbroken run for the last 12 days.
    if (i <= 12 || chance(0.65 * slack)) {
      await log(byKey[HabitKeys.meditate]!, day, 1);
    }
    if (chance(0.7 * slack)) await log(byKey[HabitKeys.read]!, day, 1);
    await log(
      byKey[HabitKeys.water]!,
      day,
      chance(0.45 * slack) ? 8 : 4 + rnd.nextInt(4),
    );
    if (day.weekday != DateTime.sunday) {
      final mins = chance(0.5 * slack)
          ? 120 + rnd.nextInt(3) * 15
          : 30 + rnd.nextInt(5) * 15;
      await log(byKey[HabitKeys.study]!, day, mins);
    }
    if (i <= 20 && chance(0.85)) await log(skincare, day, 1);
    if (i <= 20 && chance(0.5)) await log(journal, day, 1);

    // Moods: better on workout days (an insight shows it).
    if (chance(0.9)) {
      final r = rnd.nextDouble();
      final mood = worked
          ? (r < 0.55
                ? Mood.great
                : r < 0.9
                ? Mood.good
                : Mood.okay)
          : (r < 0.15
                ? Mood.good
                : r < 0.65
                ? Mood.okay
                : r < 0.9
                ? Mood.low
                : Mood.bad);
      await moods.setMood(day, mood);
    }
  }
  // Today, mid-afternoon: some done, some still to do.
  await log(byKey[HabitKeys.water]!, t, 3);
  await log(byKey[HabitKeys.study]!, t, 45);
  await log(byKey[HabitKeys.meditate]!, t, 1);
  await log(skincare, t, 1);
  await moods.setMood(t, Mood.great);

  // --- spends --------------------------------------------------------------
  // (note, category, min rupees, max rupees)
  const daily = [
    ('Chai', ExpenseCategory.food, 20, 40),
    ('Lunch', ExpenseCategory.food, 120, 260),
    ('Auto', ExpenseCategory.travel, 60, 140),
    ('Metro', ExpenseCategory.travel, 30, 70),
    ('Snacks', ExpenseCategory.food, 40, 120),
    ('Groceries', ExpenseCategory.food, 300, 900),
    ('Uber', ExpenseCategory.travel, 150, 380),
  ];
  const weekend = [
    ('Movie', ExpenseCategory.fun, 250, 600),
    ('Dinner with friends', ExpenseCategory.food, 500, 1400),
    ('Shopping', ExpenseCategory.shopping, 600, 2200),
    ('Cafe', ExpenseCategory.food, 200, 500),
    ('Bowling', ExpenseCategory.fun, 400, 800),
  ];
  const occasional = [
    ('Pharmacy', ExpenseCategory.health, 120, 600),
    ('Books', ExpenseCategory.shopping, 300, 900),
    ('Netflix', ExpenseCategory.fun, 499, 499),
    ('T-shirt', ExpenseCategory.shopping, 400, 1200),
    ('Doctor visit', ExpenseCategory.health, 500, 800),
  ];
  Future<void> spend((String, ExpenseCategory, int, int) item, DateTime d) {
    final (note, category, lo, hi) = item;
    final rupees = lo + rnd.nextInt(hi - lo + 1);
    final rounded = rupees >= 100 ? (rupees / 10).round() * 10 : rupees;
    return money.add(
      ExpenseDraft(
        amount: rounded * 100,
        category: category,
        note: note,
        date: d,
      ),
    );
  }

  for (var i = demoDays; i >= 1; i--) {
    final day = addDays(t, -i);
    final isWeekend = day.weekday >= DateTime.saturday;
    final n = isWeekend ? 1 : 1 + rnd.nextInt(3);
    for (var k = 0; k < n; k++) {
      await spend(daily[rnd.nextInt(daily.length)], day);
    }
    if (isWeekend) {
      await spend(weekend[rnd.nextInt(weekend.length)], day);
      if (chance(0.6)) await spend(weekend[rnd.nextInt(weekend.length)], day);
    }
    if (chance(0.12)) {
      await spend(occasional[rnd.nextInt(occasional.length)], day);
    }
    // Monthly bills on the 1st and 5th.
    if (day.day == 1) {
      await money.add(
        ExpenseDraft(
          amount: 69900,
          category: ExpenseCategory.bills,
          note: 'Internet bill',
          date: day,
        ),
      );
    }
    if (day.day == 5) {
      await money.add(
        ExpenseDraft(
          amount: 184000,
          category: ExpenseCategory.bills,
          note: 'Electricity bill',
          date: day,
        ),
      );
    }
  }
  for (final (note, category, rupees) in const [
    ('Chai', ExpenseCategory.food, 30),
    ('Lunch', ExpenseCategory.food, 180),
    ('Auto', ExpenseCategory.travel, 90),
  ]) {
    await money.add(
      ExpenseDraft(
        amount: rupees * 100,
        category: category,
        note: note,
        date: t,
      ),
    );
  }

  // Budgets set around this month's spending, so the card shows a mix:
  // comfortable, nearly there, and one just over.
  final monthStart = DateTime(t.year, t.month, 1);
  final monthTotals = <ExpenseCategory, int>{};
  for (final e in await money.getAll()) {
    if (!e.date.isBefore(monthStart)) {
      monthTotals[e.category] = (monthTotals[e.category] ?? 0) + e.amount;
    }
  }
  int around(ExpenseCategory c, double factor, int fallbackRupees) {
    final spent = monthTotals[c] ?? 0;
    final rupees = spent == 0 ? fallbackRupees : spent / 100 * factor;
    return ((rupees / 500).ceil() * 500 * 100).toInt();
  }

  await money.setBudget(
    ExpenseCategory.food,
    around(ExpenseCategory.food, 1.5, 6000),
  );
  await money.setBudget(
    ExpenseCategory.shopping,
    around(ExpenseCategory.shopping, 1.08, 3000),
  );
  await money.setBudget(
    ExpenseCategory.travel,
    around(ExpenseCategory.travel, 1.6, 2500),
  );
  await money.setBudget(
    ExpenseCategory.bills,
    around(ExpenseCategory.bills, 1.2, 3000),
  );
  final fun = monthTotals[ExpenseCategory.fun] ?? 0;
  await money.setBudget(
    ExpenseCategory.fun,
    // Just under what was spent: "Over by ₹..." on purpose.
    fun > 100000 ? (fun ~/ 50000) * 50000 - 50000 : 100000,
  );

  // --- tasks ---------------------------------------------------------------
  final open = [
    TaskDraft(
      title: 'Send project report',
      dueDate: t,
      dueTime: const ClockTime(17, 0),
      priority: TaskPriority.high,
      list: TaskList.work,
      reminder: true,
    ),
    TaskDraft(
      title: 'Revise Physics notes',
      dueDate: t,
      list: TaskList.study,
      subtasks: const [
        SubtaskDraft(text: 'Chapter 5 summary', done: true),
        SubtaskDraft(text: 'Make flashcards'),
        SubtaskDraft(text: 'Practice 10 questions'),
      ],
    ),
    TaskDraft(
      title: 'Call mom',
      dueDate: t,
      dueTime: const ClockTime(19, 30),
      list: TaskList.personal,
      reminder: true,
    ),
    TaskDraft(
      title: 'Pay electricity bill',
      dueDate: addDays(t, 1),
      priority: TaskPriority.high,
      list: TaskList.personal,
    ),
    TaskDraft(
      title: 'Buy groceries',
      dueDate: addDays(t, 1),
      dueTime: const ClockTime(18, 30),
      priority: TaskPriority.low,
      list: TaskList.shopping,
      subtasks: const [
        SubtaskDraft(text: 'Milk'),
        SubtaskDraft(text: 'Paneer'),
        SubtaskDraft(text: 'Spinach'),
      ],
    ),
    TaskDraft(
      title: 'Dentist appointment',
      dueDate: addDays(t, 3),
      dueTime: const ClockTime(11, 0),
      list: TaskList.personal,
      reminder: true,
    ),
    TaskDraft(
      title: 'Team presentation',
      dueDate: addDays(t, 4),
      dueTime: const ClockTime(15, 0),
      priority: TaskPriority.high,
      list: TaskList.work,
    ),
    const TaskDraft(title: 'Plan Goa trip', list: TaskList.personal),
  ];
  for (final d in open) {
    await tasks.create(d);
  }
  // Done over the past week, so "Tasks done" and Completed look lived in.
  const done = [
    ('Team stand-up notes', TaskList.work, 0),
    ('Book train tickets', TaskList.personal, 1),
    ('Submit assignment', TaskList.study, 1),
    ('Renew gym membership', TaskList.personal, 2),
    ('Fix login bug', TaskList.work, 2),
    ('Clean my desk', TaskList.personal, 3),
    ('Mock test 2', TaskList.study, 4),
    ('Order birthday gift', TaskList.shopping, 5),
    ('Client call', TaskList.work, 6),
  ];
  for (final (title, list, daysAgo) in done) {
    final day = addDays(t, -daysAgo);
    final id = await tasks.create(
      TaskDraft(title: title, dueDate: day, list: list),
    );
    await (db.update(db.tasks)..where((x) => x.id.equals(id))).write(
      TasksCompanion(
        done: const Value(true),
        doneAt: Value(day.add(Duration(hours: 10 + rnd.nextInt(8)))),
      ),
    );
  }
}
