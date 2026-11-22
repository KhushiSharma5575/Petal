/// Small, dependency-free English date helpers.
///
/// We avoid the `intl` package for now because we only need English names.
abstract final class DateText {
  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "Friday, 13 November"
  static String longDay(DateTime d) =>
      '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}
