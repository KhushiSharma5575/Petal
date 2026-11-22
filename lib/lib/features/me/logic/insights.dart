import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/habit.dart';
import '../../../data/models/mood.dart';
import '../../habits/logic/habit_logic.dart';

/// How many days back the insights look.
const insightDays = 60;

/// Things Petal noticed in the user's own data, strongest first. Worked out
/// on the phone; nothing is sent anywhere. Each pattern needs enough days
/// behind it, so a quiet first week shows nothing rather than guesses.
List<String> findInsights({
  required Iterable<HabitWithLogs> habits,
  required Map<DateTime, Mood> moods,
  required Iterable<Expense> expenses,
  required DateTime today,
}) {
  final t = dateOnly(today);
  final found = <(double, String)>[]; // (strength, sentence)

  // 1. Mood on days a habit was done vs not.
  for (final h in habits) {
    final withIt = <int>[], without = <int>[];
    for (final MapEntry(key: day, value: mood) in moods.entries) {
      if (day.isAfter(t) || t.difference(day).inDays > insightDays) continue;
      (isDone(h.habit, h.valueOn(day)) ? withIt : without).add(_score(mood));
    }
    if (withIt.length < 4 || without.length < 4) continue;
    final diff = _avg(withIt) - _avg(without);
    if (diff >= 0.5) {
      found.add((diff, 'You feel happier on days you ${_doing(h.habit)}.'));
    }
  }

  // 2. Weekend vs weekday spending (last 8 weeks).
  final since = addDays(t, -56);
  var weekend = 0, weekday = 0, weekendDays = 0, weekdayDays = 0;
  for (var d = since; !d.isAfter(t); d = addDays(d, 1)) {
    final isWeekend = d.weekday >= DateTime.saturday;
    isWeekend ? weekendDays++ : weekdayDays++;
  }
  var spendDays = 0;
  final seen = <DateTime>{};
  for (final e in expenses) {
    if (e.date.isBefore(since) || e.date.isAfter(t)) continue;
    if (seen.add(e.date)) spendDays++;
    e.date.weekday >= DateTime.saturday
        ? weekend += e.amount
        : weekday += e.amount;
  }
  if (spendDays >= 7 && weekday > 0 && weekendDays > 0) {
    final ratio = (weekend / weekendDays) / (weekday / weekdayDays);
    if (ratio >= 1.5) {
      found.add((
        ratio - 1,
        'You spend about ${ratio.toStringAsFixed(ratio >= 3 ? 0 : 1)}x more '
            'a day on weekends.',
      ));
    } else if (ratio <= 0.6 && weekend > 0) {
      found.add((
        1 / ratio - 1,
        'Weekends are your thrifty days: you spend much less than on '
            'weekdays.',
      ));
    }
  }

  // 3. The weekday habits slip most (last 8 weeks).
  final doneByDay = List.filled(8, 0), possibleByDay = List.filled(8, 0);
  for (var d = since; d.isBefore(t); d = addDays(d, 1)) {
    for (final h in habits) {
      possibleByDay[d.weekday]++;
      if (isDone(h.habit, h.valueOn(d))) doneByDay[d.weekday]++;
    }
  }
  final totalDone = doneByDay.fold(0, (a, b) => a + b);
  if (totalDone >= 20) {
    var worst = 1;
    double rate(int wd) =>
        possibleByDay[wd] == 0 ? 1 : doneByDay[wd] / possibleByDay[wd];
    for (var wd = 2; wd <= 7; wd++) {
      if (rate(wd) < rate(worst)) worst = wd;
    }
    final average = totalDone / possibleByDay.fold(0, (a, b) => a + b);
    if (average - rate(worst) >= 0.2) {
      found.add((
        (average - rate(worst)) * 2,
        'Your habits slip most on ${_weekdays[worst - 1]}s. Plan something '
            'small for them.',
      ));
    }
  }

  // 4. This month's pace vs last month.
  if (t.day >= 7) {
    final monthStart = DateTime(t.year, t.month, 1);
    final lastStart = DateTime(t.year, t.month - 1, 1);
    var thisMonth = 0, lastMonth = 0;
    for (final e in expenses) {
      if (!e.date.isBefore(monthStart) && !e.date.isAfter(t)) {
        thisMonth += e.amount;
      } else if (!e.date.isBefore(lastStart) && e.date.isBefore(monthStart)) {
        lastMonth += e.amount;
      }
    }
    final daysInMonth = DateTime(t.year, t.month + 1, 0).day;
    final forecast = (thisMonth * daysInMonth / t.day).round();
    if (thisMonth > 0 && lastMonth > 0) {
      final change = forecast / lastMonth;
      if (change >= 1.2 || change <= 0.8) {
        found.add((
          (change - 1).abs(),
          'At this pace you\'ll spend about ${formatRupees(_round(forecast))} '
              'this month (${formatRupees(_round(lastMonth))} last month).',
        ));
      }
    }
  }

  found.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final f in found) f.$2];
}

/// Rounded to ₹100 so a forecast doesn't look falsely exact.
int _round(int paise) => (paise / 10000).round() * 10000;

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

int _score(Mood m) => switch (m) {
  Mood.great => 5,
  Mood.good => 4,
  Mood.okay => 3,
  Mood.low => 2,
  Mood.bad => 1,
};

double _avg(List<int> xs) => xs.fold(0, (a, b) => a + b) / xs.length;

/// "work out", "meditate", "drink enough water", "do skincare".
String _doing(Habit h) => switch (h.key) {
  HabitKeys.workout => 'work out',
  HabitKeys.water => 'drink enough water',
  HabitKeys.study => 'study',
  HabitKeys.meditate => 'meditate',
  HabitKeys.read => 'read',
  _ => 'do ${h.name.toLowerCase()}',
};

/// The mood seen most this week (Monday to today), or null.
Mood? weekMood(Map<DateTime, Mood> moods, DateTime today) {
  final t = dateOnly(today);
  final monday = startOfWeek(t);
  final counts = <Mood, int>{};
  for (final MapEntry(key: d, value: m) in moods.entries) {
    if (!d.isBefore(monday) && !d.isAfter(t)) counts[m] = (counts[m] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}
