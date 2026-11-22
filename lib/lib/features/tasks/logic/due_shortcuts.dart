import '../../../core/utils/dates.dart';

/// The quick "When" choices in the add/edit sheet.
enum DueShortcut {
  today('Today'),
  tomorrow('Tomorrow'),
  weekend('Weekend'),
  nextWeek('Next week'),
  pick('Pick a date'),
  none('No date');

  const DueShortcut(this.label);
  final String label;
}

/// The date a shortcut stands for. Returns null for [DueShortcut.none] and
/// [DueShortcut.pick] (the user chooses the date).
///
/// - Weekend: the coming Saturday; today if it's already Saturday or Sunday.
/// - Next week: next Monday.
DateTime? resolveShortcut(DueShortcut s, DateTime today) {
  final t = dateOnly(today);
  switch (s) {
    case DueShortcut.today:
      return t;
    case DueShortcut.tomorrow:
      return addDays(t, 1);
    case DueShortcut.weekend:
      if (t.weekday >= DateTime.saturday) return t;
      return addDays(t, DateTime.saturday - t.weekday);
    case DueShortcut.nextWeek:
      return addDays(t, 8 - t.weekday);
    case DueShortcut.pick:
    case DueShortcut.none:
      return null;
  }
}

/// Which chip to highlight for an existing date. Today and Tomorrow win over
/// Weekend/Next week when they overlap; any other date shows as "Pick a
/// date".
DueShortcut shortcutFor(DateTime? date, DateTime today) {
  if (date == null) return DueShortcut.none;
  for (final s in const [
    DueShortcut.today,
    DueShortcut.tomorrow,
    DueShortcut.weekend,
    DueShortcut.nextWeek,
  ]) {
    final r = resolveShortcut(s, today);
    if (r != null && isSameDay(r, date)) return s;
  }
  return DueShortcut.pick;
}
