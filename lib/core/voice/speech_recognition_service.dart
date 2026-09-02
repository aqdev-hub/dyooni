import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Adapter around the native recognizer. Command parsing deliberately lives in
/// logic/voice so this implementation can be replaced without changing rules.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final _results = StreamController<SpeechRecognitionResult>.broadcast();
  final _statuses = StreamController<String>.broadcast();
  Stream<SpeechRecognitionResult> get results => _results.stream;
  Stream<String> get statuses => _statuses.stream;

  /// Every time the native layer calls back with a result, EVEN an empty one that gets filtered
  /// out of [results] below — this is a pure diagnostic counter. If this stays at 0 after a full
  /// listening session, the recognizer received no signal from the OS at all (a permission,
  /// microphone-routing, or on-device language-pack problem outside this app's code) — as
  /// opposed to receiving signals that simply transcribed to nothing usable.
  int totalResultCallbacks = 0;

  Future<bool> initialize({required void Function(String) onError}) {
    return _speech.initialize(
      onError: (error) => onError(error.errorMsg),
      onStatus: _statuses.add,
    );
  }

  Future<void> start({required String localeId}) async {
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        // Was `true`. A single transient recognizer error (most commonly `error_no_match` during
        // an ordinary short pause between words — not a real failure) used to end the ENTIRE
        // listening session immediately. With this `false`, the native recognizer keeps listening
        // through those and only genuinely stops on `listenFor`/`pauseFor` timeout or an explicit
        // stop() — VoiceController._onSpeechError filters which errors are worth acting on.
        cancelOnError: false,
      ),
    );
  }

  /// Devices expose locale IDs differently (`ar_SA`, `ar-SA`, or simply
  /// `ar`). Resolve against the installed recognizer locales rather than
  /// assuming one fixed ID and silently failing on another phone.
  Future<String?> resolveLocaleId(String languageCode) async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(languageCode.toLowerCase())) return locale.localeId;
    }
    return null;
  }

  void _onResult(SpeechRecognitionResult result) {
    totalResultCallbacks++;
    if (result.recognizedWords.trim().isNotEmpty) _results.add(result);
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
  bool get isListening => _speech.isListening;

  Future<void> dispose() async {
    await _results.close();
    await _statuses.close();
  }
}
