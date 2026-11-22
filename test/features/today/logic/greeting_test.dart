import 'package:flutter_test/flutter_test.dart';
import 'package:petal/features/today/logic/greeting.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 11, 13, hour, minute);

  test('morning from 05:00 to 11:59', () {
    expect(greetingFor(at(5)), 'Good morning!');
    expect(greetingFor(at(11, 59)), 'Good morning!');
  });

  test('afternoon from 12:00 to 16:59', () {
    expect(greetingFor(at(12)), 'Good afternoon!');
    expect(greetingFor(at(16, 59)), 'Good afternoon!');
  });

  test('evening from 17:00 to 21:59', () {
    expect(greetingFor(at(17)), 'Good evening!');
    expect(greetingFor(at(21, 59)), 'Good evening!');
  });

  test('night from 22:00 to 04:59', () {
    expect(greetingFor(at(22)), 'Good night!');
    expect(greetingFor(at(0)), 'Good night!');
    expect(greetingFor(at(4, 59)), 'Good night!');
  });
}
