import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

import 'speech_engine.dart';

/// Suppresses the Android system's own "start listening" / "stop listening" notification tones
/// that `android.speech.SpeechRecognizer` plays on every session, at the OS level — NOT
/// something this app ever explicitly triggers. This is a long-standing, widely-reported
/// limitation of the `speech_to_text` plugin (and of `SpeechRecognizer` in general): there is no
/// supported Dart-side flag to disable it. The two different tones the person hears
/// ("نغمة... ثم بعد ثانيتين نغمة أخرى") are literally Android's begin-of-speech and
/// end-of-speech system cues — they repeat on EVERY fresh `listen()` call, which is exactly why
/// they feel constant in Dyooni's voice dialogue: every clarification question and every
/// confirmation re-listen opens a brand-new recognizer session (see voice_provider.dart's many
/// `_speakThenListenFor...` methods), each one playing both tones again.
///
/// The practical, production-proven workaround (used across the Flutter ecosystem for this
/// exact plugin limitation): mute the notification/system audio streams for the few hundred
/// milliseconds a session is starting/stopping, then restore the person's original volume
/// immediately after. See MainActivity.kt's `dyooni/voice_audio_cues` channel for the native
/// half of this. Best-effort by design: a failure here (e.g. iOS, where this channel is simply
/// absent and every call is a no-op) must never block the actual voice feature from working —
/// only the cosmetic tone-muting is skipped.
class _SystemSoundMuter {
  static const _channel = MethodChannel('dyooni/voice_audio_cues');

  Future<void> mute() async {
    try {
      await _channel.invokeMethod<void>('muteRecognitionSounds');
    } catch (_) {
      // iOS / missing native handler / anything else — silently skip the cosmetic mute.
    }
  }

  Future<void> restore() async {
    try {
      await _channel.invokeMethod<void>('restoreRecognitionSounds');
    } catch (_) {
      // Must never throw — a failed restore would otherwise be masked by whatever caller awaited
      // this, and the person's own volume must never be left muted because of it (the native
      // side also restores defensively on its own if it ever detects a stuck mute — see Kotlin).
    }
  }
}

/// Uses the speech service supplied by Android/iOS. On most production Android devices this is
/// Google Speech Services and is substantially stronger for Arabic names and numbers than the
/// bundled Vosk MGB-2 model. The OS/provider decides whether it processes locally or online;
/// this engine deliberately never embeds a cloud API key in the mobile app.
class SystemSpeechEngine implements SpeechEngine {
  SystemSpeechEngine({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  final _soundMuter = _SystemSoundMuter();
  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  final _errorController = StreamController<SpeechEngineError>.broadcast();
  String _latestTranscript = '';
  bool _initialized = false;

  /// Set after a native error that leaves the recognizer in an unknown state; the next
  /// [start] then re-initialises the plugin (fresh native SpeechRecognizer) before listening.
  bool _needsReinit = false;

  @override
  Stream<String> get partialResults => _partialController.stream;
  @override
  Stream<String> get finalResults => _finalController.stream;

  List<String> _lastAlternatives = const [];

  @override
  List<String> get lastAlternatives => _lastAlternatives;
  @override
  Stream<SpeechEngineError> get errors => _errorController.stream;
  @override
  bool get endsSessionOnFinal => true;

  Future<bool> _ensureInitialized() async {
    if (_initialized && !_needsReinit) return true;
    _needsReinit = false;
    _initialized = await _speech.initialize(
      onError: _handleNativeError,
      onStatus: (_) {},
    );
    return _initialized;
  }

  /// THE fix for "a medium/good-but-not-excellent connection makes the app hear nothing":
  /// previously this callback was `onError: (_) {}` — every native error, INCLUDING plain
  /// network failures, was silently discarded. The person then waited out the full 8-second
  /// silence timeout and was told "لم ألتقط أي صوت" (I didn't catch any speech) — a flatly
  /// wrong diagnosis for what was actually a connectivity blip, not silence.
  ///
  /// Maps the plugin's raw Android error codes to the small, meaningful set
  /// [SpeechEngineErrorType] defines. `error_network`/`error_network_timeout`/`error_server`/
  /// `error_server_disconnected`/`error_too_many_requests` are exactly what a "good but not
  /// perfect" signal produces when the round trip to the cloud recognizer stalls or drops — see
  /// voice_provider.dart's `_onEngineError`/`_retryAfterNetworkBlip` for the silent-retry
  /// handling this now enables.
  void _handleNativeError(SpeechRecognitionError error) {
    const networkCodes = {
      'error_network',
      'error_network_timeout',
      'error_server',
      'error_server_disconnected',
      'error_too_many_requests',
    };
    const noMatchCodes = {'error_no_match', 'error_speech_timeout'};
    const permissionCodes = {'error_insufficient_permissions'};
    // Previously every one of these fell into `other` and was ignored, so the person just waited
    // out the 8-second timeout and heard "لم ألتقط أي صوت" although the OS recognizer had never
    // actually listened (e.g. right after the local engine used the microphone).
    const recoverableCodes = {'error_busy', 'error_client', 'error_audio'};

    final code = error.errorMsg;
    final type = networkCodes.contains(code)
        ? SpeechEngineErrorType.network
        : noMatchCodes.contains(code)
            ? SpeechEngineErrorType.noMatch
            : permissionCodes.contains(code)
                ? SpeechEngineErrorType.permission
                : recoverableCodes.contains(code)
                    ? SpeechEngineErrorType.recoverable
                    : SpeechEngineErrorType.other;
    if (type == SpeechEngineErrorType.recoverable) _needsReinit = true;
    // Kept in the logs on purpose: the exact Android code is what identifies a device-specific
    // recognizer problem.
    debugPrint('[voice] system recognizer error: $code (permanent: ${error.permanent})');
    _errorController.add(SpeechEngineError(type, message: code));
  }

  @override
  Future<bool> hasPermission() async => _ensureInitialized();

  @override
  Future<void> start() async {
    if (!await _ensureInitialized()) {
      throw StateError('System speech recognition is unavailable.');
    }
    _latestTranscript = '';
    _lastAlternatives = const [];
    // A previous session (or the plugin's own bookkeeping) may still think it is listening — a
    // new listen() on top of that is silently ignored, which looks exactly like "hears nothing".
    if (_speech.isListening) {
      await _speech.cancel();
    }
    // Muted BEFORE listen() starts so the very first of the two system tones is covered too —
    // restored in stop()/cancel(), both of which run on every exit path (see voice_provider.dart,
    // every code path that ends a session calls one of the two).
    await _soundMuter.mute();
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
          _lastAlternatives = [
            text,
            for (final alt in result.alternates)
              if (alt.recognizedWords.trim().isNotEmpty && alt.recognizedWords.trim() != text)
                alt.recognizedWords.trim(),
          ];
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
    await _soundMuter.restore();
    return (_latestTranscript, null);
  }

  @override
  Future<void> cancel() async {
    _latestTranscript = '';
    await _speech.cancel();
    await _soundMuter.restore();
  }

  @override
  Future<void> release() async {
    _latestTranscript = '';
    try {
      await _speech.cancel();
    } catch (_) {
      // Nothing to cancel is fine.
    }
    await _soundMuter.restore();
    // Fresh native recognizer on the next start — it may have been left stale while another
    // engine owned the microphone.
    _needsReinit = true;
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_soundMuter.restore());
    _partialController.close();
    _finalController.close();
    _errorController.close();
  }
}
