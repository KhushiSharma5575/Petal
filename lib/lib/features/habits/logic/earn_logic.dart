/// "Earn your streak" rules. Pure, so they're easy to test.
library;

/// A gym session: at least this long...
const gymMinutes = 20;

/// ...with at least this much moving around between machines.
const gymSteps = 300;

/// Whether a workout session has earned the streak.
///
/// With a step counter: [stepTarget] steps (a walk), or [gymMinutes]
/// minutes with [gymSteps]+ steps (a gym session). Without one (no sensor
/// or permission refused): [gymMinutes] minutes.
bool workoutEarned({
  required int steps,
  required Duration elapsed,
  required int stepTarget,
  required bool hasSteps,
}) {
  final longEnough = elapsed.inMinutes >= gymMinutes;
  if (!hasSteps) return longEnough;
  return steps >= stepTarget || (longEnough && steps >= gymSteps);
}

/// What's still needed, in one friendly line.
String workoutHint({
  required int steps,
  required Duration elapsed,
  required int stepTarget,
  required bool hasSteps,
}) {
  final minsLeft = gymMinutes - elapsed.inMinutes;
  if (!hasSteps) {
    return 'Keep going $minsLeft more ${minsLeft == 1 ? 'minute' : 'minutes'}.';
  }
  final walk = '${stepTarget - steps} more steps';
  if (minsLeft <= 0) return 'Walk $walk, or ${gymSteps - steps} more for gym.';
  return 'Walk $walk, or keep going $minsLeft min for a gym session.';
}

/// A saved workout session: when it started, and the phone's step total
/// then (null until the first reading).
class WorkoutSession {
  const WorkoutSession(this.start, this.baseSteps);
  final DateTime start;
  final int? baseSteps;

  String encode() => '${start.toIso8601String()}|${baseSteps ?? ''}';

  static WorkoutSession? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('|');
    final start = DateTime.tryParse(parts.first);
    if (start == null) return null;
    return WorkoutSession(
      start,
      parts.length > 1 ? int.tryParse(parts[1]) : null,
    );
  }

  /// Steps since the session began. The phone's total restarts at 0 when
  /// it reboots; then everything since the reboot counts.
  int stepsAt(int total) {
    final base = baseSteps;
    if (base == null) return 0;
    return total >= base ? total - base : total;
  }
}

/// The focus timer's clock: time only counts while the phone is face down
/// (and Petal is open).
class FocusClock {
  Duration _banked = Duration.zero;
  DateTime? _downSince;

  bool get running => _downSince != null;

  void setFaceDown(bool down, DateTime now) {
    if (down && _downSince == null) {
      _downSince = now;
    } else if (!down && _downSince != null) {
      _banked += now.difference(_downSince!);
      _downSince = null;
    }
  }

  Duration focusedAt(DateTime now) =>
      _banked +
      (_downSince == null ? Duration.zero : now.difference(_downSince!));
}

/// "12:05" for a countdown or stopwatch.
String clockText(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
