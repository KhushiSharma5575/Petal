import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why listening couldn't start or finish, in words the UI can explain.
enum SpeechProblem {
  /// Microphone permission was refused.
  noPermission,

  /// The phone has no speech recognizer at all.
  notAvailable,

  /// On-device recognition needs the offline English pack, which isn't
  /// installed. (Petal never falls back to online recognition.)
  offlinePackMissing,

  /// Nothing was heard.
  noMatch,

  /// Anything else.
  other,
}

/// What the voice sheet needs from speech recognition. Tests use a fake.
abstract class SpeechService {
  /// Prepares the recognizer (asks for mic permission the first time).
  /// Returns null when ready.
  Future<SpeechProblem?> initialize();

  /// Starts listening. [onResult] gets partial words while speaking and
  /// `isFinal: true` at the end; [onProblem] reports failures.
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechProblem problem) onProblem,
  });

  /// Stops listening and delivers what was heard so far as final.
  Future<void> stop();

  /// Stops listening and discards everything.
  Future<void> cancel();
}

/// Builds the whole sentence from the recognizer's results.
///
/// Offline recognizers work in chunks: after a short pause they close the
/// current chunk and start the next one from empty, and the final result
/// may only hold the last chunk. This keeps every chunk so "spent 100 on
/// food ... 200 on travel" isn't cut down to "200 on travel".
class TranscriptJoiner {
  final _done = <String>[];
  String _current = '';

  /// Everything heard so far.
  String get text => [..._done, _current].where((s) => s.isNotEmpty).join(' ');

  /// Takes the next result and returns the whole sentence so far.
  /// [chunkDone]: the recognizer finished this chunk; [isFinal]: the very
  /// last result.
  String add(String words, {bool chunkDone = false, bool isFinal = false}) {
    final w = words.trim();
    final before = _done.join(' ');
    if (before.isNotEmpty && _startsWithWords(w, before)) {
      // This recognizer repeats earlier chunks itself: take it as is.
      _done
        ..clear()
        ..add(w);
      _current = '';
      return text;
    }
    if (isFinal && _done.isNotEmpty && w == _done.last && _current.isEmpty) {
      return text; // the final result repeats the last finished chunk
    }
    if (!chunkDone && !isFinal && _restarted(w)) {
      // A new chunk began without the old one being marked finished.
      _done.add(_current);
    }
    if (chunkDone || isFinal) {
      if (w.isNotEmpty) _done.add(w);
      _current = '';
    } else {
      _current = w;
    }
    return text;
  }

  /// True when [w] doesn't continue the chunk in progress: much shorter and
  /// starting with a different word.
  bool _restarted(String w) {
    if (_current.isEmpty || w.isEmpty) return false;
    final firstOld = _current.split(' ').first.toLowerCase();
    final firstNew = w.split(' ').first.toLowerCase();
    return firstOld != firstNew && w.length * 2 < _current.length;
  }

  static bool _startsWithWords(String w, String prefix) =>
      w.toLowerCase() == prefix.toLowerCase() ||
      w.toLowerCase().startsWith('${prefix.toLowerCase()} ');
}

/// [SpeechService] using the phone's own recognizer, **on-device only**:
/// audio never leaves the phone. If the offline language pack is missing,
/// this reports [SpeechProblem.offlinePackMissing] instead of going online.
class DeviceSpeechService implements SpeechService {
  final _stt = SpeechToText();
  void Function(SpeechProblem)? _onProblem;
  void Function(String words, bool isFinal)? _onResult;
  bool _gotFinal = false;
  int _session = 0;
  var _joiner = TranscriptJoiner();

  /// Indian English understands Indian accents and words (auto, chai,
  /// paneer...) far better. Null until we know whether its offline pack is
  /// on this phone; false means use the phone's default language.
  static const _indianEnglish = 'en_IN';
  bool? _indianOk;
  bool _tryingIndian = false;
  bool _active = false;

  void _onError(SpeechRecognitionError e) {
    final languageMissing = const {
      'error_language_unavailable',
      'error_language_not_supported',
      'error_server',
      'error_server_disconnected',
    }.contains(e.errorMsg);
    if (_tryingIndian && languageMissing && _joiner.text.isEmpty) {
      // No Indian English pack: quietly listen again in the phone's own
      // language, and remember not to try again this run.
      _indianOk = false;
      _tryingIndian = false;
      _session++; // ignore the "done" from the failed attempt
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_active) {
          _start();
        } else {
          _report(SpeechProblem.noMatch); // stopped before anything was said
        }
      });
      return;
    }
    _report(_map(e.errorMsg));
  }

  @override
  Future<SpeechProblem?> initialize() async {
    final ok = await _stt.initialize(
      debugLogging: kDebugMode,
      onError: _onError,
      onStatus: (status) {
        // Finished without any final words: "didn't hear". The plugin can
        // send this just before the real error, so wait a moment and let
        // the error win if one arrives.
        if (status == SpeechToText.doneStatus && !_gotFinal) {
          final session = _session;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (session != _session || _gotFinal) return;
            // A late "done" from an earlier attempt while a new one runs.
            if (_stt.isListening) return;
            // Words were heard but no final result came: use them.
            final heard = _joiner.text;
            if (heard.isNotEmpty) {
              _gotFinal = true;
              _onResult?.call(heard, true);
            } else {
              _report(SpeechProblem.noMatch);
            }
          });
        }
      },
    );
    if (!ok) {
      return await _stt.hasPermission
          ? SpeechProblem.notAvailable
          : SpeechProblem.noPermission;
    }
    // No locale is picked on purpose: the phone's own speech language is
    // the one whose offline pack is installed. (Asking the plugin for its
    // locale list also opens and closes a second recognizer connection,
    // which kills the listening session on Android 13+.)
    return null;
  }

  /// Reports at most one problem per listening session.
  void _report(SpeechProblem problem) {
    final onProblem = _onProblem;
    _onProblem = null;
    onProblem?.call(problem);
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechProblem problem) onProblem,
  }) async {
    _onProblem = onProblem;
    _onResult = onResult;
    _active = true;
    await _start();
  }

  Future<void> _start() async {
    _session++;
    _gotFinal = false;
    _joiner = TranscriptJoiner();
    _tryingIndian = _indianOk != false;
    final session = _session;
    await _stt.listen(
      onResult: (r) {
        if (_gotFinal || session != _session) return;
        if (_tryingIndian) _indianOk = true;
        final text = _joiner.add(
          r.recognizedWords,
          chunkDone: r.resultTypeValue == ResultType.intermediate,
          isFinal: r.finalResult,
        );
        if (r.finalResult) _gotFinal = true;
        _onResult?.call(text, r.finalResult);
      },
      listenOptions: SpeechListenOptions(
        onDevice: true, // never send audio to a server
        // Null = the phone's speech language (whose pack is installed).
        localeId: _tryingIndian ? _indianEnglish : null,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        // Room to think between items ("100 on food... 200 on travel").
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Future<void> stop() {
    _active = false;
    return _stt.stop();
  }

  @override
  Future<void> cancel() {
    _active = false;
    return _stt.cancel();
  }

  static SpeechProblem _map(String code) => switch (code) {
    'error_permission' ||
    'error_insufficient_permissions' => SpeechProblem.noPermission,
    'error_no_match' || 'error_speech_timeout' => SpeechProblem.noMatch,
    // With on-device mode, these mean the offline pack isn't there (the
    // recognizer would have needed the internet).
    'error_language_unavailable' ||
    'error_language_not_supported' ||
    'error_network' ||
    'error_network_timeout' ||
    'error_server' ||
    'error_server_disconnected' => SpeechProblem.offlinePackMissing,
    _ => SpeechProblem.other,
  };
}

final speechServiceProvider = Provider<SpeechService>(
  (ref) => DeviceSpeechService(),
);
