/// Date-only helpers. Petal treats due dates as calendar days (no time zone),
/// so all comparisons go through [dateOnly].
library;

/// Midnight of [d]'s calendar day (local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] plus [days] calendar days. Uses the constructor rather than adding a
/// Duration so daylight-saving changes can't shift the day.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

/// Whole days from [from] to [to] (negative if [to] is earlier).
/// Compares as UTC calendar days so daylight-saving changes can't skew it.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "2026-11-13"
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses "2026-11-13" into a local date.
DateTime fromIsoDate(String s) {
  final parts = s.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
