import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:uuid/uuid.dart';

import '../../core/voice/local_audio_recording_service.dart';
import '../../core/voice/bluetooth_audio_route_service.dart';
import '../../core/voice/speech_recognition_service.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
import '../settings/locale_provider.dart';
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

final voiceProvider = StateNotifierProvider.autoDispose<VoiceController, VoiceState>((ref) {
  return VoiceController(ref);
});

enum VoiceStatus {
  idle,
  preparing,
  listening,
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
    this.draft,
    this.account,
    this.recordingPath,
    this.recordingStartedAt,
    this.errorCode,
    this.bluetoothMode = false,
  });

  final VoiceStatus status;
  final String transcript;
  final VoiceCommandDraft? draft;
  final Account? account;
  final String? recordingPath;
  final DateTime? recordingStartedAt;
  final String? errorCode;
  final bool bluetoothMode;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    VoiceCommandDraft? draft,
    Account? account,
    String? recordingPath,
    DateTime? recordingStartedAt,
    String? errorCode,
    bool? bluetoothMode,
    bool clearDraft = false,
    bool clearAccount = false,
    bool clearError = false,
  }) => VoiceState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        draft: clearDraft ? null : draft ?? this.draft,
        account: clearAccount ? null : account ?? this.account,
        recordingPath: recordingPath ?? this.recordingPath,
        recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
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
    String? recordingPath;
    try {
      recordingPath = await _recorder.start('voice_${_uuid.v4()}');
    } catch (_) {
      // Recognition remains useful even if a specific device cannot record and
      // recognize at the same time. The UI never claims a recording exists.
    }
    state = state.copyWith(
      status: bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingPath: recordingPath,
      recordingStartedAt: startedAt,
      clearError: true,
    );
    await _startRecognizer();
  }

  Future<void> _startRecognizer() async {
    final languageCode = _ref.read(localeProvider).languageCode;
    final localeId = await _speech.resolveLocaleId(languageCode) ?? languageCode;
    await _speech.start(localeId: localeId);
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
      state = state.copyWith(transcript: text);
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
    if (state.status != VoiceStatus.bluetoothWaitingWakeWord || status != 'done') return;
    _ref.read(bluetoothAudioRouteServiceProvider).isHeadsetConnected().then((connected) {
      if (!connected || state.status != VoiceStatus.bluetoothWaitingWakeWord) return;
      _startRecognizer().catchError((_) => _onSpeechError('connection'));
    });
  }

  Future<void> stopAndAnalyze() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    final current = state;
    state = state.copyWith(status: VoiceStatus.processing);
    await _speech.stop();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    final draft = _ref.read(voiceCommandParserProvider).parse(current.transcript);
    final account = _matchAccount(draft.accountName, current.transcript);
    state = state.copyWith(draft: draft, account: account, recordingPath: path ?? current.recordingPath);
    if (draft.amount == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'amount');
    } else if (account == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'account');
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

  void selectAccount(Account account) {
    state = state.copyWith(account: account, status: VoiceStatus.awaitingConfirmation, clearError: true);
  }

  Future<void> confirm() async {
    final draft = state.draft;
    final account = state.account;
    if (draft == null || account == null || draft.amount == null) return;
    state = state.copyWith(status: VoiceStatus.saving);
    final id = _uuid.v4();
    final duration = state.recordingStartedAt == null ? 0 : DateTime.now().difference(state.recordingStartedAt!).inMilliseconds;
    final recording = state.recordingPath == null
        ? null
        : VoiceRecording(path: state.recordingPath!, durationMs: duration, transcript: draft.transcript, transactionId: id);
    await _ref.read(transactionsProvider.notifier).addTransaction(Transaction(
          id: id,
          accountId: account.id,
          amount: draft.amount!,
          currency: draft.currency,
          direction: draft.direction,
          date: draft.date,
          details: draft.details,
          voiceRecording: recording,
        ),
    );
    state = state.copyWith(status: VoiceStatus.success);
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

  void _onSpeechError(String _) {
    if (state.bluetoothMode) {
      state = state.copyWith(status: VoiceStatus.bluetoothDisconnected, errorCode: 'connection');
    } else {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
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
