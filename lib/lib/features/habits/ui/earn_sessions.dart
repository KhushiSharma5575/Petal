import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/device_bridge.dart';
import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../data/models/habit.dart';
import '../logic/earn_logic.dart';
import '../state/habits_providers.dart';

// ---------------------------------------------------------------------------
// Workout: steps decide the streak
// ---------------------------------------------------------------------------

/// Opens (or reopens) the workout session for [habit].
Future<void> showWorkoutSession(BuildContext context, Habit habit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WorkoutSessionSheet(habit: habit),
  );
}

class WorkoutSessionSheet extends ConsumerStatefulWidget {
  const WorkoutSessionSheet({super.key, required this.habit});
  final Habit habit;

  @override
  ConsumerState<WorkoutSessionSheet> createState() =>
      _WorkoutSessionSheetState();
}

class _WorkoutSessionSheetState extends ConsumerState<WorkoutSessionSheet> {
  WorkoutSession? _session;
  bool _hasSteps = false;
  int _total = 0;
  StreamSubscription<int>? _sub;
  Timer? _tick;
  String? _note;

  DateTime get _now => ref.read(clockProvider)();
  HabitsController get _controller => ref.read(habitsControllerProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final saved = await ref.read(workoutSessionProvider.future);
    final session = saved ?? WorkoutSession(_now, null);
    if (saved == null) await _controller.saveWorkoutSession(session);
    final device = ref.read(deviceBridgeProvider);
    final allowed =
        await device.hasStepCounter() &&
        await device.requestActivityPermission();
    if (!mounted) return;
    setState(() {
      _session = session;
      _hasSteps = allowed;
      if (!allowed) {
        _note = 'Steps aren\'t available, so a 20-minute session counts.';
      }
    });
    if (allowed) {
      _sub = device.steps().listen(
        (total) async {
          var s = _session!;
          if (s.baseSteps == null) {
            // First reading: steps count from here.
            s = WorkoutSession(s.start, total);
            await _controller.saveWorkoutSession(s);
          }
          if (mounted) {
            setState(() {
              _session = s;
              _total = total;
            });
          }
        },
        onError: (Object _) {
          if (mounted) {
            setState(() {
              _hasSteps = false;
              _note = 'Steps aren\'t available, so a 20-minute session counts.';
            });
          }
        },
      );
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  int get _steps => _session?.stepsAt(_total) ?? 0;
  Duration get _elapsed =>
      _session == null ? Duration.zero : _now.difference(_session!.start);

  bool get _earned => workoutEarned(
    steps: _steps,
    elapsed: _elapsed,
    stepTarget: ref.read(workoutStepsProvider).value ?? 1000,
    hasSteps: _hasSteps,
  );

  Future<void> _finish() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (_earned) {
      await _controller.markDone(widget.habit);
      await _controller.saveWorkoutSession(null);
      nav.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            content: Text(
              _hasSteps
                  ? 'Streak earned! $_steps steps in ${_elapsed.inMinutes} min.'
                  : 'Streak earned! ${_elapsed.inMinutes} minutes of workout.',
            ),
          ),
        );
      return;
    }
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not earned yet'),
        content: Text('${_hint()}\nEnd now without the streak?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (end == true) {
      await _controller.saveWorkoutSession(null);
      nav.pop();
    }
  }

  String _hint() => workoutHint(
    steps: _steps,
    elapsed: _elapsed,
    stepTarget: ref.read(workoutStepsProvider).value ?? 1000,
    hasSteps: _hasSteps,
  );

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(workoutStepsProvider).value ?? 1000;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final earned = _earned;
    final progress = _hasSteps
        ? (_steps / target).clamp(0.0, 1.0)
        : (_elapsed.inSeconds / (gymMinutes * 60)).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.habit.name} session', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Keep your phone with you. Petal only reads the step counter '
            'while this is open, nothing else.',
            style: text.bodySmall,
          ),
          const SizedBox(height: PetalSpacing.xl),
          Center(
            child: SizedBox.square(
              dimension: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: palette.soft,
                    color: earned ? palette.deep : palette.accent,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hasSteps ? '$_steps' : clockText(_elapsed),
                            style: nunito(
                              FontWeight.w800,
                              size: 36,
                              color: PetalColors.text,
                            ),
                          ),
                          Text(
                            _hasSteps ? 'of $target steps' : 'of 20 min',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PetalSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.timer,
                size: 16,
                color: PetalColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(clockText(_elapsed), style: text.titleSmall),
            ],
          ),
          const SizedBox(height: PetalSpacing.sm),
          Text(
            _session == null
                ? 'Starting...'
                : earned
                ? 'You earned it! Tap Finish to keep your streak.'
                : _hint(),
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          if (_note != null) ...[
            const SizedBox(height: PetalSpacing.sm),
            Text(_note!, textAlign: TextAlign.center, style: text.bodySmall),
          ],
          const SizedBox(height: PetalSpacing.xl),
          FilledButton(
            onPressed: _session == null ? null : _finish,
            style: FilledButton.styleFrom(
              backgroundColor: earned ? palette.deep : PetalColors.ink,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(earned ? 'Finish and earn streak' : 'Finish'),
          ),
          const SizedBox(height: PetalSpacing.sm),
          Text(
            'You can close this; the session keeps counting.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study: face-down focus timer
// ---------------------------------------------------------------------------

Future<void> showFocusSession(BuildContext context, Habit habit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The timer must be stopped on purpose, not by a stray swipe.
    enableDrag: false,
    isDismissible: false,
    builder: (_) => FocusSessionSheet(habit: habit),
  );
}

enum _FocusStage { choose, running, done }

class FocusSessionSheet extends ConsumerStatefulWidget {
  const FocusSessionSheet({super.key, required this.habit});
  final Habit habit;

  @override
  ConsumerState<FocusSessionSheet> createState() => _FocusSessionSheetState();
}

class _FocusSessionSheetState extends ConsumerState<FocusSessionSheet> {
  static const _lengths = [25, 45, 60];
  int _minutes = 25;
  _FocusStage _stage = _FocusStage.choose;
  final _clock = FocusClock();
  StreamSubscription<bool>? _sub;
  Timer? _tick;
  AppLifecycleListener? _life;
  bool _noSensor = false;
  int _saved = 0;

  DateTime get _now => ref.read(clockProvider)();
  // Kept in a field: dispose() can't use ref.
  late final DeviceBridge _device;

  @override
  void initState() {
    super.initState();
    _device = ref.read(deviceBridgeProvider);
  }

  Duration get _target => Duration(minutes: _minutes);

  void _begin() {
    setState(() => _stage = _FocusStage.running);
    _device.keepScreenOn(true);
    _sub = _device.faceDown().listen(
      (down) => setState(() => _clock.setFaceDown(down, _now)),
      onError: (Object _) => setState(() => _noSensor = true),
    );
    // Leaving Petal pauses the timer.
    _life = AppLifecycleListener(
      onHide: () => setState(() => _clock.setFaceDown(false, _now)),
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_clock.focusedAt(_now) >= _target) {
        _complete(_minutes);
      } else {
        setState(() {});
      }
    });
  }

  void _stopSensors() {
    final wasRunning = _tick != null;
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
    _life?.dispose();
    _life = null;
    if (wasRunning) _device.keepScreenOn(false);
  }

  Future<void> _complete(int minutes) async {
    _stopSensors();
    if (minutes > 0) {
      await ref.read(habitsControllerProvider).addToday(widget.habit, minutes);
    }
    if (!mounted) return;
    setState(() {
      _saved = minutes;
      _stage = _FocusStage.done;
    });
  }

  Future<void> _stopEarly() async {
    final focused = _clock.focusedAt(_now).inMinutes;
    final nav = Navigator.of(context);
    if (focused < 1) {
      _stopSensors();
      nav.pop();
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the timer?'),
        content: Text('You focused for $focused min. Add it to Study?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Add $focused min'),
          ),
        ],
      ),
    );
    if (keep == null) return; // dismissed: keep timing
    if (keep) {
      await _complete(focused);
    } else {
      _stopSensors();
      nav.pop();
    }
  }

  @override
  void dispose() {
    _stopSensors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    final Widget body = switch (_stage) {
      _FocusStage.choose => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Focus timer', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Put your phone face down. The timer only runs while it stays '
            'down, and the minutes go to ${widget.habit.name}.',
            style: text.bodySmall,
          ),
          const SizedBox(height: PetalSpacing.lg),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final m in _lengths)
                ButtonSegment(value: m, label: Text('$m min')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() => _minutes = s.first),
          ),
          const SizedBox(height: PetalSpacing.xl),
          FilledButton.icon(
            onPressed: _begin,
            style: FilledButton.styleFrom(
              backgroundColor: PetalColors.ink,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(LucideIcons.play, size: 18),
            label: const Text('Start'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
      _FocusStage.running => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Focus timer', style: text.titleLarge),
          const SizedBox(height: PetalSpacing.xl),
          Center(
            child: SizedBox.square(
              dimension: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value:
                        (_clock.focusedAt(_now).inSeconds / _target.inSeconds)
                            .clamp(0.0, 1.0),
                    strokeWidth: 12,
                    backgroundColor: palette.soft,
                    color: palette.accent,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      clockText(_target - _clock.focusedAt(_now)),
                      style: nunito(
                        FontWeight.w800,
                        size: 40,
                        color: PetalColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PetalSpacing.lg),
          Semantics(
            liveRegion: true,
            child: Text(
              _noSensor
                  ? 'This phone can\'t tell if it\'s face down.'
                  : _clock.running
                  ? 'Focusing... the phone is face down.'
                  : 'Paused. Put your phone face down to continue.',
              textAlign: TextAlign.center,
              style: nunito(
                FontWeight.w700,
                size: 15,
                color: _clock.running ? palette.deep : PetalColors.text,
              ),
            ),
          ),
          const SizedBox(height: PetalSpacing.xl),
          OutlinedButton(
            onPressed: _stopEarly,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
      _FocusStage.done => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PetalSpacing.lg),
          Icon(LucideIcons.partyPopper, size: 48, color: palette.deep),
          const SizedBox(height: PetalSpacing.md),
          Text(
            'Well done!',
            textAlign: TextAlign.center,
            style: pacifico(size: 28),
          ),
          const SizedBox(height: PetalSpacing.sm),
          Text(
            '$_saved min of focus added to ${widget.habit.name}.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
          const SizedBox(height: PetalSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: PetalColors.ink,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    };

    return PopScope(
      // Back while running asks first, like Stop.
      canPop: _stage != _FocusStage.running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopEarly();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: body,
      ),
    );
  }
}
