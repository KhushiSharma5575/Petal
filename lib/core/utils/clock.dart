import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dates.dart';

/// The current time. Tests override this to freeze "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today's date (midnight). Updates itself just after midnight so a screen
/// left open overnight moves "Tomorrow" tasks into "Today".
class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = ref.watch(clockProvider)();
    _timer?.cancel();
    final nextMidnight = addDays(dateOnly(now), 1);
    _timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () => ref.invalidateSelf(),
    );
    ref.onDispose(() => _timer?.cancel());
    return dateOnly(now);
  }

  /// Re-checks the date, e.g. when the app returns from the background.
  void refresh() {
    final now = dateOnly(ref.read(clockProvider)());
    if (now != state) ref.invalidateSelf();
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);
