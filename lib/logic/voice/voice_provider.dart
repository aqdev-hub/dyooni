import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/voice/bluetooth_audio_route_service.dart';
import '../../core/voice/offline_speech_engine.dart';
import '../../core/voice/vosk_model_provider.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
import '../transactions/transactions_provider.dart';
import 'voice_command_parser.dart';

/// Built once the Vosk model has finished loading (see vosk_model_provider.dart /
/// VoskModelGate) — `requireValue` is safe here specifically because every screen that can reach
/// this provider is already gated behind the model being ready; if that ever stops being true,
/// this throws loudly instead of silently listening with a broken engine.
final offlineSpeechEngineProvider = Provider<OfflineSpeechEngine>((ref) {
  final model = ref.watch(voskModelProvider).requireValue;
  final engine = OfflineSpeechEngine(model: model);
  ref.onDispose(engine.dispose);
  return engine;
});

final bluetoothAudioRouteServiceProvider = Provider<BluetoothAudioRouteService>((ref) => BluetoothAudioRouteService());

final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) => const VoiceCommandParser());

/// KNOWN LIMITATION (see vosk_model_provider.dart's doc comment): kept as UI state for the
/// language-toggle button, but the offline engine is Arabic-only for now — toggling this does not
/// yet change which model/recognizer is used. Wiring a second (English) model in is future work.
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

  /// Snapshot of [transcript] taken at the moment recording was paused. A fresh listen session
  /// started on resume only reports what's said AFTER resuming — without this, resuming would
  /// silently discard everything captured before the pause (see VoiceController.pauseRecording).
  final String committedTranscript;

  final VoiceCommandDraft? draft;
  final Account? account;
  final String? recordingPath;
  final DateTime? recordingStartedAt;

  /// Total recording time accumulated across any PREVIOUS listen/pause cycles this session.
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
    _partialSubscription = _engine.partialResults.listen(_onPartial);
    _finalSubscription = _engine.finalResults.listen(_onFinal);
  }

  static const wakeWord = 'ديوني';
  final Ref _ref;
  OfflineSpeechEngine get _engine => _ref.read(offlineSpeechEngineProvider);
  late final StreamSubscription<String> _partialSubscription;
  late final StreamSubscription<String> _finalSubscription;
  Timer? _bluetoothMonitor;
  final _uuid = const Uuid();

  /// Called once when the voice screen opens, for BOTH entry modes. Deliberately does nothing
  /// beyond recording which mode was requested — see VoiceCommandSheet for where the actual start
  /// happens (a tap on the mic circle).
  void setEntryMode({required bool bluetoothMode}) {
    state = VoiceState(bluetoothMode: bluetoothMode);
  }

  Future<void> startShortPress() async {
    await _beginListening(bluetoothMode: false);
  }

  /// Audio routing is performed by Android/iOS. This mode is intentionally a state machine, not a
  /// fake "always connected" flag; engine failures surface as an interrupted connection and can
  /// be retried.
  Future<void> startBluetoothMode() async {
    state = const VoiceState(status: VoiceStatus.bluetoothConnecting, bluetoothMode: true);
    if (!await _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected()) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
      return;
    }
    if (!await _engine.hasPermission()) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'permission');
      return;
    }
    state = state.copyWith(status: VoiceStatus.bluetoothConnected);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    state = state.copyWith(status: VoiceStatus.bluetoothWaitingWakeWord);
    _startBluetoothMonitor();
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'recognition');
    }
  }

  void _startBluetoothMonitor() {
    _bluetoothMonitor?.cancel();
    _bluetoothMonitor = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!await _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected()) {
        _bluetoothMonitor?.cancel();
        await _engine.cancel();
        state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
      }
    });
  }

  Future<void> _beginListening({required bool bluetoothMode}) async {
    state = VoiceState(status: VoiceStatus.preparing, bluetoothMode: bluetoothMode);
    if (!await _engine.hasPermission()) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      return;
    }
    final startedAt = DateTime.now();
    state = state.copyWith(
      status: bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: startedAt,
      clearError: true,
    );
    // A SINGLE microphone consumer handles both recognition and saving — see
    // OfflineSpeechEngine's doc comment for why this replaces the old two-mic-session design.
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
    }
  }

  /// Pauses the underlying recorder in place — the SAME file/recognizer session keeps running on
  /// [resumeRecording], so a paused-then-resumed recording stays ONE continuous session rather
  /// than producing two separate clips that would need stitching together.
  Future<void> pauseRecording() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    final startedAt = state.recordingStartedAt;
    final elapsedThisRun = startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
    await _engine.pause();
    state = state.copyWith(
      status: VoiceStatus.paused,
      committedTranscript: state.transcript,
      elapsedBeforePause: state.elapsedBeforePause + elapsedThisRun,
    );
  }

  Future<void> resumeRecording() async {
    if (state.status != VoiceStatus.paused) return;
    await _engine.resume();
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: DateTime.now(),
      clearError: true,
    );
  }

  /// Live partial text — updates continuously while the person is still speaking. Also carries
  /// the Bluetooth wake-word detection, which used to live inside `_onSpeechResult`.
  void _onPartial(String text) {
    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
      state = state.copyWith(transcript: text);
      return;
    }
    if (state.status == VoiceStatus.confirmationListening) {
      state = state.copyWith(transcript: text);
      return;
    }
    if (state.status == VoiceStatus.bluetoothWaitingWakeWord) {
      if (text.replaceAll(' ', '').contains(wakeWord)) {
        state = state.copyWith(status: VoiceStatus.bluetoothWakeWordDetected, transcript: text);
        unawaited(_engine.stop());
        unawaited(_beginListening(bluetoothMode: true));
      }
    }
  }

  /// Fires once per finished utterance — mirrors the old `finalResult: true` branch of
  /// `_onSpeechResult`, but the automatic "listening ended, start understanding it" transition now
  /// comes straight from the offline engine's own end-of-utterance detection instead of the OS
  /// recognizer's.
  void _onFinal(String text) {
    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
      state = state.copyWith(transcript: text);
      unawaited(_finishListening());
      return;
    }
    if (state.status == VoiceStatus.confirmationListening) {
      state = state.copyWith(transcript: text);
      unawaited(_engine.stop()); // release the mic; this secondary recording's file isn't kept
      _handleVoiceConfirmation(text);
    }
  }

  Future<void> startVoiceConfirmation() async {
    if (state.status != VoiceStatus.awaitingConfirmation) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true);
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
    }
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

  /// Manual escape hatch — ends listening early even if the engine hasn't emitted a final result
  /// yet. The automatic path via [_onFinal] is what fires in the ordinary case; this exists for
  /// whenever the user wants to stop sooner.
  Future<void> stopAndAnalyze() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    await _finishListening();
  }

  Future<void> _finishListening() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    final current = state;
    state = state.copyWith(status: VoiceStatus.processing);

    final (engineTranscript, recordingPath) = await _engine.stop();
    // Prefer whatever was already accumulated live in `state.transcript` (from partial/final
    // events as they streamed in); fall back to the engine's own final answer only if nothing
    // was ever captured on the state side.
    final effectiveTranscript = current.transcript.trim().isNotEmpty ? current.transcript : engineTranscript;

    if (effectiveTranscript.trim().isEmpty) {
      // Nothing was ever recognized — a fundamentally different situation from "something was
      // said but a field couldn't be understood" (see VoiceCommandSheet's clarification card).
      state = state.copyWith(
        status: VoiceStatus.needsClarification,
        errorCode: 'noSpeech',
        recordingPath: recordingPath ?? current.recordingPath,
      );
      return;
    }
    final draft = _ref.read(voiceCommandParserProvider).parse(effectiveTranscript);
    final account = _matchAccount(draft.accountName, effectiveTranscript);
    state = state.copyWith(draft: draft, account: account, recordingPath: recordingPath ?? current.recordingPath);
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

  /// After picking an account manually, the direction may STILL be unresolved — re-run the same
  /// advancement check instead of assuming confirmation is next.
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
  /// Bluetooth flow's "waiting for the wake word" framing — see VoiceCommandSheet's success-state
  /// branch. Bluetooth mode's own success screen instead keeps listening for the wake word again.
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
    await _engine.cancel();
    state = const VoiceState();
  }

  @override
  void dispose() {
    _bluetoothMonitor?.cancel();
    _partialSubscription.cancel();
    _finalSubscription.cancel();
    unawaited(_engine.cancel());
    super.dispose();
  }
}
