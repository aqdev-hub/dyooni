import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../core/voice/local_audio_recording_service.dart';
import '../../core/voice/bluetooth_audio_route_service.dart';
import '../../core/voice/speech_recognition_service.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
import '../transactions/transactions_provider.dart';
import 'voice_command_parser.dart';

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((ref) {
  final service = SpeechRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

final localAudioRecordingServiceProvider = Provider<LocalAudioRecordingService>((ref) {
  final service = LocalAudioRecordingService();
  ref.onDispose(service.dispose);
  return service;
});

final bluetoothAudioRouteServiceProvider = Provider<BluetoothAudioRouteService>((ref) => BluetoothAudioRouteService());

final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) => const VoiceCommandParser());

/// Which language the SPEECH RECOGNIZER listens for — deliberately independent of the app's
/// DISPLAY language (`localeProvider`, toggled elsewhere in Settings/the drawer). This is what
/// the "العربية" button on the voice screen controls (see VoiceCommandSheet). Session-only by
/// design: recognition language is a per-recording choice, not a persisted app setting, so
/// `.autoDispose` resets it once the voice screen is left.
final voiceRecognitionLanguageProvider = StateProvider.autoDispose<String>((ref) => 'ar');

final voiceProvider = StateNotifierProvider.autoDispose<VoiceController, VoiceState>((ref) {
  return VoiceController(ref);
});

enum VoiceStatus {
  idle,
  preparing,
  listening,
  paused,
  processing,
  needsClarification,
  awaitingConfirmation,
  confirmationListening,
  saving,
  success,
  bluetoothConnecting,
  bluetoothConnected,
  bluetoothWaitingWakeWord,
  bluetoothWakeWordDetected,
  bluetoothListeningCommand,
  bluetoothDisconnected,
  error,
}

class VoiceState {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.committedTranscript = '',
    this.draft,
    this.account,
    this.recordingPath,
    this.recordingStartedAt,
    this.elapsedBeforePause = Duration.zero,
    this.errorCode,
    this.bluetoothMode = false,
  });

  final VoiceStatus status;

  /// The full recognized text so far, INCLUDING anything said before a pause (see
  /// [committedTranscript]) — this is what gets parsed and what the transcript card shows.
  final String transcript;

  /// Snapshot of [transcript] taken at the moment recording was paused. A fresh `listen()`
  /// session started on resume only reports what's said AFTER resuming — without this, resuming
  /// would silently discard everything captured before the pause (see
  /// VoiceController._onSpeechResult).
  final String committedTranscript;

  final VoiceCommandDraft? draft;
  final Account? account;
  final String? recordingPath;
  final DateTime? recordingStartedAt;

  /// Total recording time accumulated across any PREVIOUS listen/pause cycles this session.
  /// Combined with `now - recordingStartedAt` while actively listening to display a continuous
  /// running timer that correctly freezes while paused (see the recording-timer widget).
  final Duration elapsedBeforePause;

  final String? errorCode;
  final bool bluetoothMode;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? committedTranscript,
    VoiceCommandDraft? draft,
    Account? account,
    String? recordingPath,
    DateTime? recordingStartedAt,
    Duration? elapsedBeforePause,
    String? errorCode,
    bool? bluetoothMode,
    bool clearDraft = false,
    bool clearAccount = false,
    bool clearError = false,
  }) => VoiceState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        committedTranscript: committedTranscript ?? this.committedTranscript,
        draft: clearDraft ? null : draft ?? this.draft,
        account: clearAccount ? null : account ?? this.account,
        recordingPath: recordingPath ?? this.recordingPath,
        recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
        elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
        errorCode: clearError ? null : errorCode ?? this.errorCode,
        bluetoothMode: bluetoothMode ?? this.bluetoothMode,
      );
}

class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._ref) : super(const VoiceState()) {
    _resultsSubscription = _speech.results.listen(_onSpeechResult);
    _statusSubscription = _speech.statuses.listen(_onSpeechStatus);
  }

  static const wakeWord = 'ديوني';
  final Ref _ref;
  SpeechRecognitionService get _speech => _ref.read(speechRecognitionServiceProvider);
  LocalAudioRecordingService get _recorder => _ref.read(localAudioRecordingServiceProvider);
  late final StreamSubscription<SpeechRecognitionResult> _resultsSubscription;
  late final StreamSubscription<String> _statusSubscription;
  Timer? _bluetoothMonitor;
  final _uuid = const Uuid();

  /// Called once when the voice screen opens, for BOTH entry modes. Deliberately does nothing
  /// beyond recording which mode was requested — the reference design's idle state ("اضغط لبدء
  /// التسجيل") is the first thing the user sees whether they short-pressed or long-pressed the
  /// mic on Home; actually starting to listen (short-press) or searching for a headset
  /// (Bluetooth) only happens once they tap the mic circle on THIS screen (see
  /// VoiceCommandSheet's tap dispatch).
  void setEntryMode({required bool bluetoothMode}) {
    state = VoiceState(bluetoothMode: bluetoothMode);
  }

  Future<void> startShortPress() async {
    await _beginListening(bluetoothMode: false);
  }

  /// Audio routing is performed by Android/iOS. This mode is intentionally a
  /// state machine, not a fake "always connected" flag; native recognizer
  /// errors surface as an interrupted connection and can be retried.
  Future<void> startBluetoothMode() async {
    state = const VoiceState(status: VoiceStatus.bluetoothConnecting, bluetoothMode: true);
    if (!await _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected()) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
      return;
    }
    final ready = await _speech.initialize(onError: _onSpeechError);
    if (!ready) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'permission');
      return;
    }
    state = state.copyWith(status: VoiceStatus.bluetoothConnected);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    state = state.copyWith(status: VoiceStatus.bluetoothWaitingWakeWord);
    _startBluetoothMonitor();
    await _startRecognizer();
  }

  void _startBluetoothMonitor() {
    _bluetoothMonitor?.cancel();
    _bluetoothMonitor = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!await _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected()) {
        _bluetoothMonitor?.cancel();
        await _speech.cancel();
        state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
      }
    });
  }

  Future<void> _beginListening({required bool bluetoothMode}) async {
    state = VoiceState(status: VoiceStatus.preparing, bluetoothMode: bluetoothMode);
    final ready = await _speech.initialize(onError: _onSpeechError);
    if (!ready) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      return;
    }
    final startedAt = DateTime.now();
    state = state.copyWith(
      status: bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: startedAt,
      clearError: true,
    );
    // Recognition starts FIRST and owns the microphone — it is the functionally critical path
    // (nothing works at all without it). The raw recorder starts AFTER and is best-effort: on
    // some devices two simultaneous mic sessions don't both get real audio, and a saved-but-empty
    // recording is a far smaller loss than the recognizer hearing nothing.
    await _startRecognizer();
    try {
      final recordingPath = await _recorder.start('voice_${_uuid.v4()}');
      state = state.copyWith(recordingPath: recordingPath);
    } catch (e, st) {
      appLogger.e('Voice raw audio recorder failed to start (recognition continues without a saved recording)', error: e, stackTrace: st);
    }
  }

  /// Falls back to a fully-qualified regional tag when the device doesn't report one matching
  /// [languageCode] via [SpeechRecognitionService.resolveLocaleId] — passing a bare language code
  /// like `'ar'` (no region) to the native recognizer can silently fail to configure it correctly
  /// on some platforms, which looks identical to "the recognizer heard nothing" from the outside.
  String _fallbackLocaleId(String languageCode) => switch (languageCode) {
        'ar' => 'ar-SA',
        'en' => 'en-US',
        _ => languageCode,
      };

  Future<void> _startRecognizer() async {
    final languageCode = _ref.read(voiceRecognitionLanguageProvider);
    final localeId = await _speech.resolveLocaleId(languageCode) ?? _fallbackLocaleId(languageCode);
    await _speech.start(localeId: localeId);
  }

  /// Pauses BOTH the recognizer and the raw audio recording in place, without finishing or
  /// analyzing anything — resuming continues the SAME recording (see
  /// LocalAudioRecordingService.pause's doc comment) and the same sentence.
  Future<void> pauseRecording() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    final startedAt = state.recordingStartedAt;
    final elapsedThisRun = startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
    await _speech.stop();
    try {
      await _recorder.pause();
    } catch (e, st) {
      appLogger.e('Voice raw audio recorder failed to pause', error: e, stackTrace: st);
    }
    state = state.copyWith(
      status: VoiceStatus.paused,
      committedTranscript: state.transcript,
      elapsedBeforePause: state.elapsedBeforePause + elapsedThisRun,
    );
  }

  Future<void> resumeRecording() async {
    if (state.status != VoiceStatus.paused) return;
    try {
      await _recorder.resume();
    } catch (e, st) {
      appLogger.e('Voice raw audio recorder failed to resume', error: e, stackTrace: st);
    }
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: DateTime.now(),
      clearError: true,
    );
    await _startRecognizer();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    if (state.status == VoiceStatus.bluetoothWaitingWakeWord) {
      if (text.replaceAll(' ', '').contains(wakeWord)) {
        state = state.copyWith(status: VoiceStatus.bluetoothWakeWordDetected, transcript: text);
        _speech.stop().whenComplete(() => _beginListening(bluetoothMode: true));
      }
      return;
    }
    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
      final combined = state.committedTranscript.isEmpty ? text : '${state.committedTranscript} $text'.trim();
      state = state.copyWith(transcript: combined);
      // The recognizer itself has decided the utterance is complete (silence timeout via
      // `pauseFor`, or the max `listenFor` duration reached) — move straight into understanding
      // it, with NO manual step required. This is the automatic "الاستماع ← انتهاء الكلام ←
      // الحصول على النص" transition the spec calls for; previously `finalResult` was received and
      // silently ignored here, so nothing ever happened until the user also tapped the mic
      // circle to stop manually — a real gap, not a stylistic choice.
      if (result.finalResult) unawaited(_finishListening());
      return;
    }
    if (state.status == VoiceStatus.confirmationListening) {
      state = state.copyWith(transcript: text);
      if (result.finalResult) _handleVoiceConfirmation(text);
    }
  }

  Future<void> startVoiceConfirmation() async {
    if (state.status != VoiceStatus.awaitingConfirmation) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true);
    final ready = await _speech.initialize(onError: _onSpeechError);
    if (!ready) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
      return;
    }
    await _startRecognizer();
  }

  void _handleVoiceConfirmation(String spoken) {
    final normalized = spoken.toLowerCase().replaceAll('أ', 'ا');
    if (['نعم', 'ايوه', 'ايوا', 'صحيح', 'احفظ', 'yes', 'correct', 'save'].any(normalized.contains)) {
      unawaited(confirm());
      return;
    }
    if (['تعديل', 'اعد', 'غير', 'لا', 'edit', 'again', 'no'].any(normalized.contains)) {
      unawaited(retry());
      return;
    }
    state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'confirmation');
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' && (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand)) {
      unawaited(_finishListening());
      return;
    }
    if (state.status != VoiceStatus.bluetoothWaitingWakeWord || status != 'done') return;
    _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected().then((connected) {
      if (!connected || state.status != VoiceStatus.bluetoothWaitingWakeWord) return;
      _startRecognizer().catchError((_) => _onSpeechError('connection'));
    });
  }

  /// Manual escape hatch — ends listening early even if the recognizer hasn't reported
  /// `finalResult` yet (e.g. `pauseFor`'s silence window hasn't elapsed). The automatic path via
  /// `_onSpeechResult`'s `finalResult` handling is what fires in the ordinary case; this exists
  /// for whenever the user wants to stop sooner, or as a fallback if a platform never reports a
  /// final result for some reason.
  Future<void> stopAndAnalyze() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    await _finishListening();
  }

  Future<void> _finishListening() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    final current = state;
    state = state.copyWith(status: VoiceStatus.processing);
    await _speech.stop();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      appLogger.e('Voice raw audio recorder failed to stop', error: e, stackTrace: st);
    }
    if (current.transcript.trim().isEmpty) {
      // Nothing was ever recognized — a fundamentally different situation from "something was
      // said but a field couldn't be understood" (see VoiceCommandSheet's clarification card,
      // which now shows this distinctly and never claims an amount was misheard when nothing was
      // heard at all).
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'noSpeech', recordingPath: path ?? current.recordingPath);
      return;
    }
    final draft = _ref.read(voiceCommandParserProvider).parse(current.transcript);
    final account = _matchAccount(draft.accountName, current.transcript);
    state = state.copyWith(draft: draft, account: account, recordingPath: path ?? current.recordingPath);
    _advanceAfterParsing(draft: draft, account: account);
  }

  /// Amount → account → direction, in that order: an account can't be matched without at least
  /// trying, and asking "له أم عليه؟" before we even know WHO the money is for/from would be a
  /// confusing question to lead with.
  void _advanceAfterParsing({required VoiceCommandDraft draft, required Account? account}) {
    if (draft.amount == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'amount');
    } else if (account == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'account');
    } else if (draft.direction == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'direction');
    } else {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation);
    }
  }

  Account? _matchAccount(String? parsedName, String transcript) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final candidate = (parsedName ?? transcript).toLowerCase();
    for (final account in accounts) {
      if (candidate.contains(account.name.toLowerCase())) return account;
    }
    return null;
  }

  /// After picking an account manually, the direction may STILL be unresolved (e.g. "أضف 3200
  /// ريال دجاجة" has neither an account nor a له/عليه marker) — re-run the same advancement check
  /// instead of assuming confirmation is next.
  void selectAccount(Account account) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(account: account, clearError: true);
    _advanceAfterParsing(draft: draft, account: account);
  }

  void selectDirection(AccountDirection direction) {
    final draft = state.draft;
    if (draft == null) return;
    final updated = draft.copyWith(direction: direction);
    state = state.copyWith(draft: updated, status: VoiceStatus.awaitingConfirmation, clearError: true);
  }

  Future<void> confirm() async {
    final draft = state.draft;
    final account = state.account;
    if (draft == null || account == null || draft.amount == null || draft.direction == null) return;
    state = state.copyWith(status: VoiceStatus.saving);
    final id = _uuid.v4();
    final duration = state.recordingStartedAt == null
        ? state.elapsedBeforePause.inMilliseconds
        : (state.elapsedBeforePause + DateTime.now().difference(state.recordingStartedAt!)).inMilliseconds;
    final recording = state.recordingPath == null
        ? null
        : VoiceRecording(path: state.recordingPath!, durationMs: duration, transcript: draft.transcript, transactionId: id);
    await _ref.read(transactionsProvider.notifier).addTransaction(Transaction(
          id: id,
          accountId: account.id,
          amount: draft.amount!,
          currency: draft.currency,
          direction: draft.direction!,
          date: draft.date,
          details: draft.details,
          voiceRecording: recording,
        ),
    );
    state = state.copyWith(status: VoiceStatus.success);
  }

  /// Short-press only: leaves the "saved" screen to start a brand new recording, WITHOUT the
  /// Bluetooth flow's "waiting for the wake word" framing that would be wrong here — see
  /// VoiceCommandSheet's success-state branch. Bluetooth mode's own success screen instead keeps
  /// listening for the wake word again (genuinely correct for hands-free use), unaffected by
  /// this method.
  void startAnother() {
    if (state.status != VoiceStatus.success || state.bluetoothMode) return;
    state = const VoiceState(bluetoothMode: false);
  }

  Future<void> retry() async {
    final wasBluetoothMode = state.bluetoothMode;
    await cancel();
    if (wasBluetoothMode) {
      await startBluetoothMode();
    } else {
      await startShortPress();
    }
  }

  Future<void> cancel() async {
    _bluetoothMonitor?.cancel();
    await _speech.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    state = const VoiceState();
  }

  /// Classifies the recognizer's error string and decides whether it's even worth surfacing.
  ///
  /// `speech_to_text` reports errors using a small, documented set of codes (error_no_match,
  /// error_speech_timeout, error_busy, error_network[_timeout], error_insufficient_permissions,
  /// error_audio, error_server, error_client...). Previously EVERY one of these — including the
  /// completely normal "I heard a brief silence" (`error_no_match`) that happens constantly
  /// during natural speech — was mapped straight to a generic "microphone/permission" message and
  /// tore down the whole listening session. That combination was the main reason real speech was
  /// never actually understood: the very first pause in a sentence ended the session before the
  /// sentence finished.
  void _onSpeechError(String errorMsg) {
    // Internal sentinel from `_onSpeechStatus`'s wake-word restart path — not a real
    // speech_to_text error code, so it skips the message-based classification entirely.
    if (errorMsg == 'connection') {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
      return;
    }
    final code = errorMsg.toLowerCase();
    final isTransient = code.contains('no_match') || code.contains('speech_timeout') || code.contains('busy');
    final activelyListening = state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.bluetoothListeningCommand ||
        state.status == VoiceStatus.bluetoothWaitingWakeWord ||
        state.status == VoiceStatus.confirmationListening;
    // A transient hiccup while a session is healthy and ongoing must not kill it — with
    // cancelOnError now false (see SpeechRecognitionService), the native recognizer itself keeps
    // listening through these; the app must not override that by jumping to an error screen on
    // every single one.
    if (isTransient && activelyListening) return;

    final errorCode = code.contains('permission')
        ? 'permission'
        : code.contains('network')
            ? 'network'
            : 'recognition';
    appLogger.w('Speech recognition error: $errorMsg (classified as $errorCode)');
    if (state.bluetoothMode) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: errorCode);
    } else {
      state = state.copyWith(status: VoiceStatus.error, errorCode: errorCode);
    }
  }

  @override
  void dispose() {
    _bluetoothMonitor?.cancel();
    _resultsSubscription.cancel();
    _statusSubscription.cancel();
    _speech.cancel();
    _recorder.cancel();
    super.dispose();
  }
}
