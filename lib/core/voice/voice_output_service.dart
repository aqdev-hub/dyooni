import 'package:flutter_tts/flutter_tts.dart';

/// Speaks short confirmation/clarification sentences back to the user. This is intentionally a
/// thin adapter — all phrase WORDING lives in voice_provider.dart (see the doc comment there on
/// why TTS phrases are keyed by the voice RECOGNITION language rather than pulled from the ARB
/// files used for on-screen text).
class VoiceOutputService {
  VoiceOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _configured = true;
  }

  /// Stops whatever is currently being spoken (if anything) before starting the new sentence, so
  /// two utterances can never overlap — matching "عدم تداخل أكثر من رسالة صوتية" from the spec.
  Future<void> speak(String text, {required String languageCode}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _tts.stop();
    await _ensureConfigured();
    // ar-SA / en-US are the most broadly available regional tags across Android OEMs and iOS.
    await _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'ar-SA');
    await _tts.speak(trimmed);
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}
