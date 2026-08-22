import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Adapter around the native recognizer. Command parsing deliberately lives in
/// logic/voice so this implementation can be replaced without changing rules.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final _results = StreamController<String>.broadcast();
  final _statuses = StreamController<String>.broadcast();
  Stream<String> get results => _results.stream;
  Stream<String> get statuses => _statuses.stream;

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
        cancelOnError: true,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.trim().isNotEmpty) _results.add(result.recognizedWords.trim());
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
  bool get isListening => _speech.isListening;

  Future<void> dispose() async {
    await _results.close();
    await _statuses.close();
  }
}
