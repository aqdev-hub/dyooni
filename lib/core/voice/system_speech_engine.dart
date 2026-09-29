import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_engine.dart';

/// Uses the speech service supplied by Android/iOS. On most production Android devices this is
/// Google Speech Services and is substantially stronger for Arabic names and numbers than the
/// bundled Vosk MGB-2 model. The OS/provider decides whether it processes locally or online;
/// this engine deliberately never embeds a cloud API key in the mobile app.
class SystemSpeechEngine implements SpeechEngine {
  SystemSpeechEngine({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  String _latestTranscript = '';
  bool _initialized = false;

  @override
  Stream<String> get partialResults => _partialController.stream;
  @override
  Stream<String> get finalResults => _finalController.stream;
  @override
  bool get endsSessionOnFinal => true;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _initialized;
  }

  @override
  Future<bool> hasPermission() async => _ensureInitialized();

  @override
  Future<void> start() async {
    if (!await _ensureInitialized()) {
      throw StateError('System speech recognition is unavailable.');
    }
    _latestTranscript = '';
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: await _arabicLocaleId(),
        partialResults: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        _latestTranscript = text;
        if (result.finalResult) {
          _finalController.add(text);
        } else {
          _partialController.add(text);
        }
      },
    );
  }

  /// Use Yemeni Arabic when the installed recognizer offers it, rather than forcing a Saudi
  /// locale. That gives the cloud/system provider the best available chance with local names.
  Future<String> _arabicLocaleId() async {
    final locales = await _speech.locales();
    final yemeni = locales.where((locale) => locale.localeId.toLowerCase() == 'ar_ye');
    if (yemeni.isNotEmpty) return yemeni.first.localeId;
    final arabic = locales.where((locale) => locale.localeId.toLowerCase().startsWith('ar'));
    return arabic.isNotEmpty ? arabic.first.localeId : 'ar_SA';
  }

  @override
  Future<void> pause() => _speech.stop();

  @override
  Future<void> resume() => start();

  @override
  Future<(String transcript, String? recordingPath)> stop() async {
    await _speech.stop();
    return (_latestTranscript, null);
  }

  @override
  Future<void> cancel() async {
    _latestTranscript = '';
    await _speech.cancel();
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _partialController.close();
    _finalController.close();
  }
}
