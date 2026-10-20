import 'dart:async';

/// Why this file was ADDED on top of the original `SpeechEngine`:
///
/// Previously, a network hiccup on the cloud engine and "the person genuinely said nothing"
/// looked IDENTICAL from VoiceController's point of view — both ended the same way: silence
/// until `_noSpeechAfter` (8s) fired, then `voiceNoSpeechCaptured` ("لم ألتقط أي صوت") was shown.
/// That is the root cause of the reported "medium-strength internet = the app doesn't hear
/// anything" bug. A real production voice feature must tell these two cases apart and retry
/// automatically on the connectivity one — see voice_provider.dart's `_onEngineError`.
enum SpeechEngineErrorType {
  /// The recognizer itself failed to reach/complete a round trip to the cloud service — this is
  /// exactly what a "good but not excellent" signal produces (`error_network`,
  /// `error_network_timeout`, `error_server`, `error_server_disconnected`,
  /// `error_too_many_requests` on Android). MUST be retried silently, never shown to the person
  /// as "you didn't say anything".
  network,

  /// The recognizer genuinely heard nothing usable (`error_no_match`, `error_speech_timeout`).
  /// This is the only case that should ever surface as "لم ألتقط أي صوت".
  noMatch,

  /// Microphone/speech permission is missing or was revoked mid-session.
  permission,

  /// The OS recognizer could not start or lost its audio input right now (`error_busy`,
  /// `error_client`, `error_audio`) — typically because something else (a previous engine, the
  /// recorder) still held the microphone or the native recognizer was left in a stale state.
  /// Retried silently after the engine re-initialises itself; shown to the person only if
  /// every retry fails.
  recoverable,

  /// Anything else — logged for diagnostics, treated conservatively (same as [noMatch] by the
  /// caller) rather than silently retried forever.
  other,
}

class SpeechEngineError {
  const SpeechEngineError(this.type, {this.message});
  final SpeechEngineErrorType type;

  /// The raw underlying error code/message, kept only for logs — never shown to the person.
  final String? message;
}

/// Thrown by [SpeechEngine.stop] when the recognizer FAILED to produce a result (as opposed to
/// hearing nothing, which is an ordinary empty transcript). [code] is the dialogue's own error code
/// (see VoiceController) and [message] is for logs only.
class SpeechEngineException implements Exception {
  const SpeechEngineException(this.code, [this.message]);
  final String code;
  final String? message;

  @override
  String toString() => 'SpeechEngineException($code${message == null ? '' : ': $message'})';
}

/// The stable contract used by the voice dialogue. Implementations may be fully offline, use
/// the device's cloud-backed recognizer, or be replaced by another provider later without
/// changing parsing, confirmation, account creation, or transaction saving.
abstract interface class SpeechEngine {
  Stream<String> get partialResults;
  Stream<String> get finalResults;

  /// Structured, non-fatal recognizer errors. See [SpeechEngineErrorType] for why this exists —
  /// in short, it is what lets VoiceController retry a flaky connection instead of lying to the
  /// person that they didn't speak.
  Stream<SpeechEngineError> get errors;

  /// Ranked alternative transcripts of the LAST final result (best first, the final text itself
  /// included), when the recognizer provides them — empty otherwise. The controller uses them to
  /// pick the hypothesis whose NUMBER is parseable when the top one is garbled ("أuأ ألف").
  List<String> get lastAlternatives;

  /// System/cloud recognizers naturally finish a session after silence; local streaming engines
  /// do not. The controller uses this to finish exactly once in the right place.
  bool get endsSessionOnFinal;

  /// Fires repeatedly while the person is audibly speaking, for engines that produce NO live text
  /// (Whisper decodes only after recording stops). The controller re-arms its "end of speech"
  /// timer on every event, exactly as it does for a live partial transcript — without this a
  /// batch engine would be cut off by the initial no-speech timer in the middle of a sentence.
  /// Engines with live text may simply never emit.
  Stream<void> get speechActivity;

  /// `true` when [partialResults] carries real live text (Vosk, system recognizer). `false` for a
  /// batch engine: wake-word detection (which needs live text) is then unavailable.
  bool get providesLiveText;

  Future<bool> hasPermission();
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<(String transcript, String? recordingPath)> stop();
  Future<void> cancel();

  /// Frees EVERY OS resource this engine holds (microphone, native recognizer, muted volumes) so
  /// a different engine can use the hardware straight away. Called when the person switches
  /// between local and cloud recognition. The engine must be able to [start] again afterwards.
  Future<void> release();
  void dispose();
}
