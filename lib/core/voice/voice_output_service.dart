import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'voice_log.dart';

/// Speaks short confirmation/clarification sentences back to the user. This is intentionally a
/// thin adapter — all phrase WORDING lives in voice_provider.dart (see the doc comment there on
/// why TTS phrases are keyed by the voice RECOGNITION language rather than pulled from the ARB
/// files used for on-screen text).
///
/// Robustness rules (all learned from field logs where the app stayed silent AND slow):
///  * completion is tracked with the engine's own start / completion / error callbacks instead of
///    `awaitSpeakCompletion`, which can wait forever when the engine never reports "done";
///  * if the engine does not even START within [_startTimeout] the sentence is abandoned at once
///    (no long dead wait) and speech is skipped for [_brokenFor] — a missing / silent engine must
///    never slow the whole dialogue down;
///  * every step is logged to the [VoiceLog] so a silent device can be diagnosed from the log.
class VoiceOutputService {
  VoiceOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;
  bool _configured = false;
  String? _language;
  Completer<void>? _started;
  Completer<void>? _finished;
  DateTime? _brokenUntil;

  // The very first sentence may have to wait for the engine to bind; later ones start fast.
  bool _everStarted = false;
  static const _firstStartTimeout = Duration(seconds: 4);
  static const _startTimeout = Duration(milliseconds: 1800);
  static const _brokenFor = Duration(seconds: 45);

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    _tts.setStartHandler(() {
      final c = _started;
      _everStarted = true;
      if (c != null && !c.isCompleted) c.complete();
    });
    void done() {
      final c = _finished;
      if (c != null && !c.isCompleted) c.complete();
    }

    _tts.setCompletionHandler(done);
    _tts.setCancelHandler(done);
    _tts.setErrorHandler((message) {
      VoiceLog.d('tts', 'engine error: $message');
      final s = _started;
      if (s != null && !s.isCompleted) s.complete();
      done();
    });
    await _tts.awaitSpeakCompletion(false);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  /// Picks the best available Arabic / English voice once per language and logs what exists.
  Future<void> _ensureLanguage(String languageCode) async {
    if (_language == languageCode) return;
    final candidates = languageCode == 'en' ? const ['en-US', 'en-GB', 'en'] : const ['ar-SA', 'ar', 'ar-EG', 'ar-AE'];
    for (final tag in candidates) {
      try {
        final available = await _tts.isLanguageAvailable(tag).timeout(const Duration(seconds: 2));
        if (available == true || available == 1) {
          await _tts.setLanguage(tag).timeout(const Duration(seconds: 3));
          _language = languageCode;
          VoiceLog.d('tts', 'language set: $tag');
          return;
        }
      } catch (_) {}
    }
    VoiceLog.d('tts', 'no voice found for $languageCode - trying the default voice anyway');
    try {
      await _tts.setLanguage(candidates.first).timeout(const Duration(seconds: 3));
    } catch (_) {}
    _language = languageCode;
  }

  /// Loads the speech engine and language ahead of the first sentence, so the first spoken reply
  /// (e.g. the answer to «ديوني») is not delayed or lost while the engine starts up.
  Future<void> warmUp({required String languageCode}) async {
    try {
      await _ensureConfigured().timeout(const Duration(seconds: 4));
      await _ensureLanguage(languageCode);
    } catch (e) {
      VoiceLog.d('tts', 'warm-up failed ($e)');
    }
  }

  /// Stops whatever is currently being spoken (if anything) before starting the new sentence, so
  /// two utterances can never overlap — matching "عدم تداخل أكثر من رسالة صوتية" from the spec.
  Future<void> speak(String text, {required String languageCode}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final broken = _brokenUntil;
    if (broken != null && DateTime.now().isBefore(broken)) return; // engine known dead: don't wait
    try {
      await _ensureConfigured().timeout(const Duration(seconds: 4));
      await _ensureLanguage(languageCode);
      final speaking = _finished;
      if (speaking != null && !speaking.isCompleted) {
        await _tts.stop().timeout(const Duration(seconds: 1)); // never two sentences at once
      }
      final started = Completer<void>();
      final finished = Completer<void>();
      _started = started;
      _finished = finished;
      final result = await _tts.speak(trimmed).timeout(const Duration(seconds: 3));
      if (result == 0) {
        VoiceLog.d('tts', 'speak() refused by the engine');
        _brokenUntil = DateTime.now().add(_brokenFor);
        return;
      }
      await started.future.timeout(_everStarted ? _startTimeout : _firstStartTimeout, onTimeout: () {
        VoiceLog.d('tts', 'engine never started speaking - skipping speech for ${_brokenFor.inSeconds}s');
        _brokenUntil = DateTime.now().add(_brokenFor);
        finished.complete();
      });
      // Started: wait for the end, bounded by a generous estimate of how long the sentence takes.
      await finished.future.timeout(Duration(milliseconds: 2500 + trimmed.length * 130));
    } catch (e) {
      VoiceLog.d('tts', 'speak failed ($e)');
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() => stop();
}
