import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

import 'native_speech_bridge.dart';
import 'parallel_recorder.dart';
import 'speech_engine.dart';
import 'voice_log.dart';

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
  SystemSpeechEngine({stt.SpeechToText? speech, ParallelRecorder? recorder, NativeSpeechBridge? native, this.recordInParallel = false})
      : _speech = speech ?? stt.SpeechToText(),
        _native = native ?? NativeSpeechBridge(),
        _recorder = recorder ?? ParallelRecorder();

  /// OFF by default. Android lets only ONE capture client hear the microphone at a time: when our
  /// own `record` stream opens beside the system recognizer, the OS silences one of them and the
  /// recognizer was the one that went deaf (v12 regression: "cloud hears nothing"). Hearing the
  /// person is the feature; the parallel copy is a best-effort extra that must be opted into.
  final bool recordInParallel;

  /// Android 13+ path: the app's recorder is the ONLY microphone owner and feeds the system
  /// recognizer through EXTRA_AUDIO_SOURCE, so it hears AND the original recording is kept.
  /// Flip to false to go back to the plain plugin path everywhere.
  static const useNativeAudioSource = true;
  final NativeSpeechBridge _native;
  StreamSubscription<NativeSpeechEvent>? _nativeSub;
  bool? _nativeSupported;
  bool _nativeFailed = false;
  bool _nativeActive = false;

  /// Whether the app-supplied-audio path has EVER produced text in this app run. A recognizer
  /// service may accept EXTRA_AUDIO_SOURCE yet never use it (it then reports "no speech" or just
  /// stays silent while the person talks). Until the path has proven itself, an empty outcome is
  /// treated as "this path does not work here" and the plain plugin path takes over — see
  /// [_fallbackToPlugin].
  bool _nativeProducedText = false;
  Timer? _nativeWatchdog;
  static const _nativeWatchdogDelay = Duration(seconds: 9);
  final stt.SpeechToText _speech;

  /// After a network-class error the recognizer is asked to work ON THE DEVICE (no round trip), so
  /// a weak connection no longer means "hears nothing". Online is tried again after
  /// [_offlineHold] — the connection may be back.
  bool _preferOffline = false;
  DateTime? _lastNetworkErrorAt;
  static const _offlineHold = Duration(minutes: 2);
  String? _localeId;
  final _clock = Stopwatch();
  final _soundMuter = _SystemSoundMuter();
  // Keeps a replayable copy of the voice while the OS recognizer listens — see ParallelRecorder.
  final ParallelRecorder _recorder;
  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  final _errorController = StreamController<SpeechEngineError>.broadcast();
  String _latestTranscript = '';
  bool _initialized = false;

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

  // The system recognizer streams live text, so it never needs the activity signal.
  @override
  Stream<void> get speechActivity => const Stream<void>.empty();

  @override
  bool get providesLiveText => true;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    final sw = Stopwatch()..start();
    _initialized = await _speech.initialize(
      onError: _handleNativeError,
      onStatus: (status) => VoiceLog.d('system', 'plugin status: $status (+${_clock.elapsedMilliseconds}ms since start)'),
    );
    VoiceLog.d('system', 'plugin initialised=$_initialized in ${sw.elapsedMilliseconds}ms');
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
    const languageCodes = {'error_language_not_supported', 'error_language_unavailable'};

    final code = error.errorMsg;
    final type = networkCodes.contains(code)
        ? SpeechEngineErrorType.network
        : noMatchCodes.contains(code)
            ? SpeechEngineErrorType.noMatch
            : permissionCodes.contains(code)
                ? SpeechEngineErrorType.permission
                : languageCodes.contains(code)
                    ? SpeechEngineErrorType.languageUnavailable
                    : SpeechEngineErrorType.other;
    if (type == SpeechEngineErrorType.network) _noteNetworkTrouble('plugin $code');
    if (type == SpeechEngineErrorType.languageUnavailable) _preferOffline = false;
    // Kept in the logs on purpose: the exact Android code is what identifies a device-specific
    // recognizer problem.
    VoiceLog.d('system', 'plugin error: $code permanent=${error.permanent} type=${type.name} offlineMode=$_preferOffline wantListening=$_wantListening nativeActive=$_nativeActive (+${_clock.elapsedMilliseconds}ms)');
    if (type == SpeechEngineErrorType.noMatch && _wantListening && !_nativeActive) {
      unawaited(_restartDeadSession());
      return;
    }
    _errorController.add(SpeechEngineError(type, message: code));
  }

  @override
  Future<bool> hasPermission() async => _ensureInitialized();

  @override
  Future<void> start() async {
    if (!await _ensureInitialized()) {
      throw StateError('System speech recognition is unavailable.');
    }
    _clock
      ..reset()
      ..start();
    _latestTranscript = '';
    _lastAlternatives = const [];
    final held = _lastNetworkErrorAt;
    if (_preferOffline && held != null && DateTime.now().difference(held) > _offlineHold) {
      _preferOffline = false;
      VoiceLog.d('system', 'trying the online recognizer again');
    }
    VoiceLog.d('system', 'start(): offlineMode=$_preferOffline nativePath=${useNativeAudioSource && !_nativeFailed}');
    // Tones are silenced WITHOUT waiting (the muter only touches the notification stream now) so
    // listening begins as early as possible.
    unawaited(_soundMuter.mute());
    _wantListening = true;
    _deadRestarts = 0;
    if (await _tryStartNative()) return;
    await _listenWithPlugin();
    // After listen() so the recognizer has already claimed the microphone; never throws.
    if (recordInParallel) await _recorder.start();
    VoiceLog.d('system', 'plugin listening after ${_clock.elapsedMilliseconds}ms');
  }

  void _noteNetworkTrouble(String why) {
    _lastNetworkErrorAt = DateTime.now();
    if (!_preferOffline) {
      _preferOffline = true;
      VoiceLog.d('system', 'network trouble ($why) -> switching the recognizer to on-device mode');
    }
  }

  /// Whether the dialogue currently wants the recognizer running (between start() and
  /// stop()/pause()/cancel()/release()).
  bool _wantListening = false;
  bool _restarting = false;
  int _deadRestarts = 0;
  static const _maxDeadRestarts = 20;

  Future<void> _listenWithPlugin() async {
    final locale = await _arabicLocaleId();
    VoiceLog.d('system', 'plugin listen(locale=$locale onDevice=$_preferOffline) at +${_clock.elapsedMilliseconds}ms');
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: locale,
        onDevice: _preferOffline,
        partialResults: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) => _handleResult(
        result.recognizedWords,
        result.finalResult,
        [for (final alt in result.alternates) alt.recognizedWords],
      ),
    );
  }

  /// THE fix for "it heard me, then stopped hearing, then heard me again" in cloud mode. Android's
  /// recognizer ends a session by itself with `error_speech_timeout` / `error_no_match` — most
  /// often a session that began a moment too early after the previous one and heard nothing (the
  /// v-log showed `listening → notListening → done → error_speech_timeout` within a beat, with no
  /// text). Previously that error was only logged, so the engine sat DEAD while the person kept
  /// talking until the 8 s silence timer gave up. Now, while the dialogue still wants to listen,
  /// the recognizer is quietly restarted after a short gap and the error is never shown.
  Future<void> _restartDeadSession() async {
    if (!_wantListening || _restarting || _nativeActive || _deadRestarts >= _maxDeadRestarts) return;
    _restarting = true;
    _deadRestarts++;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_wantListening && !_nativeActive) {
        try {
          await _speech.cancel();
        } catch (_) {}
        await _listenWithPlugin();
        VoiceLog.d('system', 'system recognizer restarted after an empty session ($_deadRestarts)');
      }
    } catch (e) {
      VoiceLog.d('system', 'system recognizer restart failed: $e');
    } finally {
      _restarting = false;
    }
  }

  void _handleResult(String raw, bool isFinal, List<String> alternates) {
    final text = raw.trim();
    // Diagnostic only: length and finality, never the words themselves.
    VoiceLog.d('system', 'plugin result: final=$isFinal alternates=${alternates.length} text="$text" (+${_clock.elapsedMilliseconds}ms)');
    if (text.isEmpty) return;
    _latestTranscript = text;
    _deadRestarts = 0;
    if (isFinal) {
      _lastAlternatives = [
        text,
        for (final alt in alternates)
          if (alt.trim().isNotEmpty && alt.trim() != text) alt.trim(),
      ];
      _finalController.add(text);
    } else {
      _partialController.add(text);
    }
  }

  void _onNativeEvent(NativeSpeechEvent event) {
    VoiceLog.d('system', 'native event: ${event.type} code=${event.code} texts=${event.texts} (+${_clock.elapsedMilliseconds}ms)');
    switch (event.type) {
      case 'state':
        return; // ready / speechBegin / speechEnd — logged above, nothing else to do
      case 'partial':
      case 'final':
        if (event.texts.isEmpty) return;
        _nativeProducedText = true;
        _nativeWatchdog?.cancel();
        _handleResult(event.texts.first, event.type == 'final', event.texts.skip(1).toList());
      case 'error':
        // 3 audio, 5 client, 12/13 language: this recognizer cannot work through the audio-source
        // path. Remember it so the next session uses the plain plugin path instead.
        const unusable = {3, 5};
        if (unusable.contains(event.code)) _nativeFailed = true;
        // 12/13: no language model (often because OFFLINE was requested and no Arabic pack is
        // installed). Not a reason to abandon the audio-source path — drop offline mode and let the
        // dialogue decide (switch to the local engine).
        if (event.code == 12 || event.code == 13) {
          _preferOffline = false;
          _errorController.add(SpeechEngineError(SpeechEngineErrorType.languageUnavailable, message: 'native_${event.code}'));
          return;
        }
        // "No speech / no match" from a path that has never produced any text is the signature
        // of a recognizer that ignores the audio we feed it: switch paths instead of telling the
        // person nothing was heard.
        if ((event.code == 6 || event.code == 7) && !_nativeProducedText && _wantListening && _nativeActive) {
          _nativeFailed = true;
          unawaited(_fallbackToPlugin('native path ended empty (code ${event.code})'));
          return;
        }
        const network = {1, 2, 4, 10, 11};
        const noMatch = {6, 7};
        if (network.contains(event.code)) _noteNetworkTrouble('native ${event.code}');
        final type = network.contains(event.code)
            ? SpeechEngineErrorType.network
            : noMatch.contains(event.code)
                ? SpeechEngineErrorType.noMatch
                : event.code == 9
                    ? SpeechEngineErrorType.permission
                    : SpeechEngineErrorType.other;
        VoiceLog.d('system', 'native error ${event.code} -> ${type.name} offlineMode=$_preferOffline');
        _errorController.add(SpeechEngineError(type, message: 'native_${event.code}'));
    }
  }

  Future<bool> _tryStartNative() async {
    if (!useNativeAudioSource || _nativeFailed || !Platform.isAndroid) return false;
    _nativeSupported ??= await _native.isSupported();
    if (_nativeSupported != true) return false;
    _nativeSub ??= _native.events.listen(_onNativeEvent);
    // The microphone is opened FIRST and its audio is held in memory until the recognizer is up,
    // then handed over in order — so the first words after the start are no longer lost to the
    // recognizer's start-up time (the "first part of my sentence is cut" symptom).
    final early = <Uint8List>[];
    var handedOver = false;
    _recorder.onChunk = (chunk) {
      if (handedOver) {
        _native.feed(chunk);
      } else {
        early.add(chunk);
      }
    };
    final recorderStarted = _recorder.start();
    final locale = await _arabicLocaleId();
    final started = await _native.start(locale, preferOffline: _preferOffline);
    await recorderStarted;
    if (!started) {
      _recorder.onChunk = null;
      await _recorder.cancel();
      _nativeFailed = true;
      VoiceLog.d('system', 'native recognizer refused to start');
      return false;
    }
    for (final chunk in early) {
      _native.feed(chunk);
    }
    VoiceLog.d('system', 'native: handed over ${early.length} pre-roll chunks after ${_clock.elapsedMilliseconds}ms');
    early.clear();
    handedOver = true;
    _nativeActive = true;
    VoiceLog.d('system', 'native recognizer running on app-supplied audio (offline=$_preferOffline)');
    _armNativeWatchdog();
    return true;
  }

  /// If the app-supplied-audio path has never produced text and nothing at all happens for a while,
  /// give up on it (once) and use the plain plugin path.
  void _armNativeWatchdog() {
    _nativeWatchdog?.cancel();
    if (_nativeProducedText) return;
    _nativeWatchdog = Timer(_nativeWatchdogDelay, () {
      if (_wantListening && _nativeActive && !_nativeProducedText) {
        _nativeFailed = true;
        unawaited(_fallbackToPlugin('native path silent for ${_nativeWatchdogDelay.inSeconds}s'));
      }
    });
  }

  Future<void> _fallbackToPlugin(String reason) async {
    if (_restarting) return;
    _restarting = true;
    try {
      VoiceLog.d('system', 'switching to the plain system recognizer: $reason');
      _nativeWatchdog?.cancel();
      _nativeActive = false;
      _recorder.onChunk = null;
      await _native.cancel();
      await _recorder.cancel();
      if (_wantListening) await _listenWithPlugin();
    } catch (e) {
      VoiceLog.d('system', 'fallback to the plain recognizer failed: $e');
    } finally {
      _restarting = false;
    }
  }

  Future<void> _stopRecognizer() async {
    _nativeWatchdog?.cancel();
    if (_nativeActive) {
      _nativeActive = false;
      _recorder.onChunk = null;
      await _native.stop();
    } else {
      await _speech.stop();
    }
  }

  /// Use Yemeni Arabic when the installed recognizer offers it, rather than forcing a Saudi
  /// locale. That gives the cloud/system provider the best available chance with local names.
  Future<String> _arabicLocaleId() async {
    final cached = _localeId;
    if (cached != null) return cached;
    final sw = Stopwatch()..start();
    final found = await _lookupArabicLocale();
    _localeId = found;
    VoiceLog.d('system', 'locale resolved: $found in ${sw.elapsedMilliseconds}ms');
    return found;
  }

  Future<String> _lookupArabicLocale() async {
    final locales = await _speech.locales();
    final yemeni = locales.where((locale) => locale.localeId.toLowerCase() == 'ar_ye');
    if (yemeni.isNotEmpty) return yemeni.first.localeId;
    final arabic = locales.where((locale) => locale.localeId.toLowerCase().startsWith('ar'));
    return arabic.isNotEmpty ? arabic.first.localeId : 'ar_SA';
  }

  @override
  Future<void> pause() async {
    _wantListening = false;
    final wasNative = _nativeActive;
    await _stopRecognizer();
    if (wasNative || recordInParallel) await _recorder.pause();
  }

  @override
  Future<void> resume() => start();

  @override
  Future<(String transcript, String? recordingPath)> stop() async {
    _wantListening = false;
    final wasNative = _nativeActive;
    await _stopRecognizer();
    await _soundMuter.restore();
    return (_latestTranscript, wasNative || recordInParallel ? await _recorder.stop() : null);
  }

  @override
  Future<void> cancel() async {
    _nativeWatchdog?.cancel();
    _wantListening = false;
    _latestTranscript = '';
    _nativeActive = false;
    _recorder.onChunk = null;
    await _native.cancel();
    await _speech.cancel();
    await _recorder.cancel();
    await _soundMuter.restore();
  }

  @override
  Future<void> release() async {
    _nativeWatchdog?.cancel();
    _wantListening = false;
    _latestTranscript = '';
    _nativeActive = false;
    _recorder.onChunk = null;
    await _native.cancel();
    try {
      await _speech.cancel();
    } catch (_) {
      // Nothing to cancel is fine.
    }
    await _recorder.cancel();
    await _soundMuter.restore();
  }

  @override
  void dispose() {
    _nativeWatchdog?.cancel();
    _wantListening = false;
    unawaited(_native.cancel());
    unawaited(_nativeSub?.cancel());
    unawaited(_speech.cancel());
    unawaited(_recorder.cancel());
    unawaited(_soundMuter.restore());
    _partialController.close();
    _finalController.close();
    _errorController.close();
  }
}
