import 'package:flutter_test/flutter_test.dart';
import 'package:petal/features/today/logic/greeting.dart';

void main() {
  test('the greeting changes at 5, 12, 17 and 22', () {
    expect(
      nextGreetingChange(DateTime(2026, 11, 13, 9, 30)),
      DateTime(2026, 11, 13, 12),
    );
    expect(
      nextGreetingChange(DateTime(2026, 11, 13, 17)),
      DateTime(2026, 11, 13, 22),
    );
    expect(
      nextGreetingChange(DateTime(2026, 11, 13, 23, 10)),
      DateTime(2026, 11, 14, 5),
    );
    expect(
      nextGreetingChange(DateTime(2026, 11, 30, 22, 0)),
      DateTime(2026, 12, 1, 5),
    );
  });
}
