import 'package:petal/features/voice/state/speech_service.dart';

/// A pretend microphone. Tests call [say] or [fail] while it's listening.
class FakeSpeechService implements SpeechService {
  /// Returned from [initialize] (null = ready).
  SpeechProblem? initProblem;
  bool listening = false;
  int cancels = 0;

  void Function(String, bool)? _onResult;
  void Function(SpeechProblem)? _onProblem;

  @override
  Future<SpeechProblem?> initialize() async => initProblem;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechProblem problem) onProblem,
  }) async {
    listening = true;
    _onResult = onResult;
    _onProblem = onProblem;
  }

  /// Delivers partial words, then the final result.
  void say(String words) {
    final parts = words.split(' ');
    for (var i = 1; i < parts.length; i++) {
      _onResult?.call(parts.take(i).join(' '), false);
    }
    listening = false;
    _onResult?.call(words, true);
  }

  void fail(SpeechProblem p) {
    listening = false;
    _onProblem?.call(p);
  }

  @override
  Future<void> stop() async {
    listening = false;
  }

  @override
  Future<void> cancel() async {
    listening = false;
    cancels++;
  }
}
