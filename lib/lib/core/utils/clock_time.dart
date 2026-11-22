/// A time of day (hour + minute) without a date, independent of Flutter's
/// TimeOfDay so pure logic and the database don't depend on the UI library.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  /// From minutes after midnight (how it's stored in the database).
  factory ClockTime.fromMinutes(int minutes) =>
      ClockTime(minutes ~/ 60, minutes % 60);

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  /// "6 pm", "6:30 pm", "12 am".
  String format() {
    final suffix = hour < 12 ? 'am' : 'pm';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute == 0 ? '' : ':${minute.toString().padLeft(2, '0')}';
    return '$h12$mm $suffix';
  }

  /// This time on the calendar day of [date].
  DateTime on(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  @override
  int compareTo(ClockTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}
