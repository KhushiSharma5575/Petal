import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';

/// Greeting for the Today header, based on the hour of day.
///
/// 05:00-11:59 morning, 12:00-16:59 afternoon, 17:00-21:59 evening,
/// otherwise night.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning!';
  if (h >= 12 && h < 17) return 'Good afternoon!';
  if (h >= 17 && h < 22) return 'Good evening!';
  return 'Good night!';
}

/// Hours where the greeting changes.
const _changeHours = [5, 12, 17, 22];

/// The next moment [greetingFor] gives a different answer.
DateTime nextGreetingChange(DateTime now) {
  for (final h in _changeHours) {
    final at = DateTime(now.year, now.month, now.day, h);
    if (at.isAfter(now)) return at;
  }
  return DateTime(now.year, now.month, now.day + 1, _changeHours.first);
}

/// The current greeting. Updates itself when the time of day changes, so
/// "Good morning!" doesn't stay up all evening if Petal is left open.
class GreetingNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    final now = ref.watch(clockProvider)();
    _timer?.cancel();
    _timer = Timer(
      nextGreetingChange(now).difference(now) + const Duration(seconds: 1),
      () => ref.invalidateSelf(),
    );
    ref.onDispose(() => _timer?.cancel());
    return greetingFor(now);
  }

  /// Re-checks, e.g. when the app returns from the background (timers
  /// may not run while the phone sleeps).
  void refresh() {
    final now = greetingFor(ref.read(clockProvider)());
    if (now != state) ref.invalidateSelf();
  }
}

final greetingProvider = NotifierProvider<GreetingNotifier, String>(
  GreetingNotifier.new,
);
