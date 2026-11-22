import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/motion.dart';
import '../../../core/platform/device_bridge.dart';
import '../../habits/state/habits_providers.dart';
import '../../money/state/money_providers.dart';
import '../../tasks/state/tasks_providers.dart';
import '../logic/answers.dart';
import '../logic/voice_parser.dart';
import '../state/speech_service.dart';
import '../state/voice_actions.dart';

/// Opens the voice sheet: Listening -> what was heard -> "I'll save: ..."
/// card with Save / Edit. Nothing is ever saved without that card.
Future<void> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const VoiceSheet(),
  );
}

enum _Stage { starting, listening, confirm, problem, typing }

class VoiceSheet extends ConsumerStatefulWidget {
  const VoiceSheet({super.key});

  @override
  ConsumerState<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<VoiceSheet> {
  late final SpeechService _speech = ref.read(speechServiceProvider);
  final _typed = TextEditingController();
  _Stage _stage = _Stage.starting;
  SpeechProblem? _problem;
  String _partial = '';
  String _heard = '';
  VoiceCommand? _command;
  bool _saving = false;

  /// Petal's answer when the user asked a question.
  String? _answer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    if (_stage == _Stage.listening) _speech.cancel();
    _typed.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  Future<void> _listen() async {
    setState(() {
      _stage = _Stage.starting;
      _partial = '';
      _problem = null;
    });
    final problem = await _speech.initialize();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _stage = _Stage.problem;
        _problem = problem;
      });
      return;
    }
    setState(() => _stage = _Stage.listening);
    await _speech.listen(
      onResult: (words, isFinal) {
        if (!mounted || _stage != _Stage.listening) return;
        setState(() => _partial = words);
        if (isFinal) _onHeard(words);
      },
      onProblem: (p) {
        if (!mounted || _stage != _Stage.listening) return;
        setState(() {
          _stage = _Stage.problem;
          _problem = p;
        });
      },
    );
  }

  void _onHeard(String words) {
    if (words.trim().isEmpty) {
      setState(() {
        _stage = _Stage.problem;
        _problem = SpeechProblem.noMatch;
      });
      return;
    }
    setState(() {
      _heard = words.trim();
      _command = parseVoice(_heard, _now);
      _stage = _Stage.confirm;
    });
    _answerIfQuestion();
  }

  /// Questions are answered right away, on screen and out loud.
  void _answerIfQuestion() {
    final c = _command;
    if (c is! AskPetal) {
      _answer = null;
      return;
    }
    final answer = answerQuestion(
      c,
      tasks: ref.read(tasksProvider).value ?? const [],
      expenses: ref.read(expensesProvider).value ?? const [],
      budgets: ref.read(budgetsProvider).value ?? const {},
      habits: ref.read(habitsProvider).value ?? const [],
      today: _now,
    );
    setState(() => _answer = answer);
    ref.read(deviceBridgeProvider).speak(answer);
  }

  void _startTyping() {
    if (_stage == _Stage.listening) _speech.cancel();
    _typed.text = _heard;
    setState(() {
      _command = _heard.isEmpty ? null : parseVoice(_heard, _now);
      _stage = _Stage.typing;
    });
  }

  Future<void> _save() async {
    final command = _command;
    if (command is AskPetal) {
      // Typed question: show the answer instead of saving.
      setState(() => _stage = _Stage.confirm);
      _answerIfQuestion();
      return;
    }
    if (command == null || command is NotUnderstood || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final summary = command is AddExpenses
        ? describeCommand(command, _now).split('\n').first
        : describeCommand(command, _now);
    final warning = switch (command) {
      AddExpense(:final draft) =>
        await ref.read(moneyControllerProvider).warningFor([draft]),
      AddExpenses(:final drafts) =>
        await ref.read(moneyControllerProvider).warningFor(drafts),
      _ => null,
    };
    final undo = await ref.read(voiceActionsProvider).save(command);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          // A budget warning stays a little longer, so it can be read.
          duration: Duration(seconds: warning == null ? 4 : 7),
          content: Text(
            warning == null ? 'Saved. $summary' : 'Saved. $summary\n$warning',
          ),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: () => undo()),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 200)),
          child: switch (_stage) {
            _Stage.starting => const _Centered(
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            _Stage.listening => _listening(),
            _Stage.confirm => _confirm(),
            _Stage.problem => _problemView(),
            _Stage.typing => _typing(),
          },
        ),
      ),
    );
  }

  Widget _listening() {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const _ListeningBars(),
        const SizedBox(height: PetalSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text('Listening…', style: text.titleLarge),
        ),
        const SizedBox(height: PetalSpacing.sm),
        Text(
          _partial.isEmpty
              ? 'Try "spent 250 on lunch", "call mom tomorrow at 6" or ask '
                    '"how much did I spend this week?"'
              : _partial,
          textAlign: TextAlign.center,
          style: _partial.isEmpty
              ? text.bodyMedium?.copyWith(color: PetalColors.textSecondary)
              : text.titleMedium,
        ),
        const SizedBox(height: PetalSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startTyping,
                icon: const Icon(LucideIcons.keyboard, size: 18),
                label: const Text('Type'),
              ),
            ),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: _speech.stop,
                icon: const Icon(LucideIcons.square, size: 16),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _confirm() {
    final text = Theme.of(context).textTheme;
    final command = _command!;
    final understood = command is! NotUnderstood;
    if (command is AskPetal) return _answerView();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('You said', style: text.labelMedium),
        Text('"$_heard"', style: text.bodyLarge),
        const SizedBox(height: PetalSpacing.lg),
        if (understood)
          _ConfirmCard(summary: describeCommand(command, _now))
        else
          Text(
            'Sorry, I didn\'t catch that. Try something like "add call mom '
            'tomorrow", "spent 250 on lunch", "drank 2 glasses of water" or '
            '"feeling good".',
            style: text.bodyMedium,
          ),
        const SizedBox(height: PetalSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: understood ? _startTyping : _listen,
                icon: Icon(
                  understood ? LucideIcons.pencil : LucideIcons.mic,
                  size: 18,
                ),
                label: Text(understood ? 'Edit' : 'Try again'),
              ),
            ),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: understood
                  ? FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Save'),
                    )
                  : FilledButton.icon(
                      onPressed: _startTyping,
                      icon: const Icon(LucideIcons.keyboard, size: 18),
                      label: const Text('Type it'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _answerView() {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('You asked', style: text.labelMedium),
        Text('"$_heard"', style: text.bodyLarge),
        const SizedBox(height: PetalSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(PetalSpacing.lg),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: PetalRadii.cardRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.flower2, color: palette.deep),
                const SizedBox(width: PetalSpacing.md),
                Expanded(
                  child: Text(
                    _answer ?? '',
                    style: nunito(
                      FontWeight.w700,
                      size: 17,
                      color: PetalColors.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PetalSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(deviceBridgeProvider).stopSpeaking();
                  _listen();
                },
                icon: const Icon(LucideIcons.mic, size: 18),
                label: const Text('Ask again'),
              ),
            ),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ref.read(deviceBridgeProvider).stopSpeaking();
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typing() {
    final text = Theme.of(context).textTheme;
    final command = _command;
    final ok = command != null && command is! NotUnderstood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Type or fix it', style: text.titleLarge),
        const SizedBox(height: PetalSpacing.md),
        TextField(
          controller: _typed,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. remind me to pay rent on Friday',
          ),
          onChanged: (v) => setState(() {
            _heard = v.trim();
            _command = _heard.isEmpty ? null : parseVoice(_heard, _now);
          }),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: PetalSpacing.lg),
        if (ok && command is AskPetal)
          Text('Tap Ask to hear the answer.', style: text.bodySmall)
        else if (ok)
          _ConfirmCard(summary: describeCommand(command, _now))
        else if (_heard.isNotEmpty)
          Text('Not sure what to save yet.', style: text.bodySmall),
        const SizedBox(height: PetalSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _listen,
                icon: const Icon(LucideIcons.mic, size: 18),
                label: const Text('Speak'),
              ),
            ),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: ok && !_saving ? _save : null,
                child: Text(command is AskPetal ? 'Ask' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _problemView() {
    final text = Theme.of(context).textTheme;
    final (title, message) = switch (_problem!) {
      SpeechProblem.noPermission => (
        'Microphone is off',
        'Allow the microphone for Petal in Settings > Apps > Petal > '
            'Permissions. You can type instead meanwhile.',
      ),
      SpeechProblem.notAvailable => (
        'No speech recognition',
        'This phone doesn\'t offer speech recognition. You can type instead.',
      ),
      SpeechProblem.offlinePackMissing => (
        'Offline speech isn\'t set up',
        'Petal only uses on-device speech, so your voice never leaves the '
            'phone. Download the offline English pack: in Settings, search '
            '"offline speech" (or open the Google app > Settings > Voice > '
            'Offline speech recognition) and add English. You can type '
            'instead meanwhile.',
      ),
      SpeechProblem.noMatch => (
        'I didn\'t hear anything',
        'Tap Try again and speak after the beep, or type it.',
      ),
      SpeechProblem.other => (
        'Something went wrong',
        'Speech recognition stopped unexpectedly. Try again, or type it.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.micOff, size: 36, color: context.palette.deep),
        const SizedBox(height: PetalSpacing.md),
        Text(title, textAlign: TextAlign.center, style: text.titleLarge),
        const SizedBox(height: PetalSpacing.sm),
        Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
        const SizedBox(height: PetalSpacing.xl),
        Row(
          children: [
            if (_problem != SpeechProblem.notAvailable) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _listen,
                  child: const Text('Try again'),
                ),
              ),
              const SizedBox(width: PetalSpacing.md),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _startTyping,
                icon: const Icon(LucideIcons.keyboard, size: 18),
                label: const Text('Type instead'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The "I'll save: ..." card.
class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(PetalSpacing.lg),
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I\'ll save:',
              style: nunito(FontWeight.w800, size: 13, color: palette.deep),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: nunito(FontWeight.w800, size: 16, color: PetalColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// Five gently bouncing bars while listening (still when reduce motion is
/// on).
class _ListeningBars extends StatefulWidget {
  const _ListeningBars();

  @override
  State<_ListeningBars> createState() => _ListeningBarsState();
}

class _ListeningBarsState extends State<_ListeningBars>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.palette.deep;
    return ExcludeSemantics(
      child: SizedBox(
        height: 48,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: reduceMotion(context)
                      ? 22
                      : 10 +
                            26 *
                                (0.5 -
                                    (((_controller.value + i * 0.12) % 1) - 0.5)
                                        .abs()) *
                                2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
