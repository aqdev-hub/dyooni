import 'dart:async';

/// The stable contract used by the voice dialogue. Implementations may be fully offline, use
/// the device's cloud-backed recognizer, or be replaced by another provider later without
/// changing parsing, confirmation, account creation, or transaction saving.
abstract interface class SpeechEngine {
  Stream<String> get partialResults;
  Stream<String> get finalResults;

  /// System/cloud recognizers naturally finish a session after silence; local streaming engines
  /// do not. The controller uses this to finish exactly once in the right place.
  bool get endsSessionOnFinal;

  Future<bool> hasPermission();
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<(String transcript, String? recordingPath)> stop();
  Future<void> cancel();
  void dispose();
}
