import '../../../core/utils/clock_time.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/dates.dart';

/// Short, friendly label for a due date relative to [today]:
/// "Today", "Tomorrow", "Yesterday", "Wednesday" (within the next week),
/// otherwise "Mon 23 Nov". Adds the time if set: "Today, 6:30 pm".
String dueLabel(DateTime? date, ClockTime? time, DateTime today) {
  if (date == null) return '';
  final diff = daysBetween(today, date);
  final String day;
  if (diff == 0) {
    day = 'Today';
  } else if (diff == 1) {
    day = 'Tomorrow';
  } else if (diff == -1) {
    day = 'Yesterday';
  } else if (diff > 1 && diff < 7) {
    day = DateText.weekdays[date.weekday - 1];
  } else {
    day = shortDate(date);
  }
  return time == null ? day : '$day, ${time.format()}';
}

/// "Mon 23 Nov"
String shortDate(DateTime d) =>
    '${DateText.weekdays[d.weekday - 1].substring(0, 3)} ${d.day} '
    '${DateText.months[d.month - 1].substring(0, 3)}';
