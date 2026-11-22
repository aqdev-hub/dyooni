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

  /// Loads the speech engine and language ahead of the first sentence, so the first spoken reply
  /// (e.g. the answer to «ديوني») is not delayed or lost while the engine starts up.
  Future<void> warmUp({required String languageCode}) async {
    try {
      await _ensureConfigured().timeout(const Duration(seconds: 4));
      await _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'ar-SA').timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Stops whatever is currently being spoken (if anything) before starting the new sentence, so
  /// two utterances can never overlap — matching "عدم تداخل أكثر من رسالة صوتية" from the spec.
  Future<void> speak(String text, {required String languageCode}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _tts.stop().timeout(const Duration(seconds: 2));
      await _ensureConfigured().timeout(const Duration(seconds: 4));
      // ar-SA / en-US are the most broadly available regional tags across Android OEMs and iOS.
      await _tts.setLanguage(languageCode == 'en' ? 'en-US' : 'ar-SA').timeout(const Duration(seconds: 3));
      // awaitSpeakCompletion can wait forever when the engine never reports "done" (seen in the
      // field log: a 4 s hang). Bounded by a generous estimate of how long the sentence takes.
      final limit = Duration(milliseconds: 2500 + trimmed.length * 130);
      await _tts.speak(trimmed).timeout(limit);
    } catch (_) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}
