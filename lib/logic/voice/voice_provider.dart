import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/voice/bluetooth_audio_route_service.dart';
import '../../core/voice/offline_speech_engine.dart';
import '../../core/voice/speech_engine.dart';
import '../../core/voice/system_speech_engine.dart';
import '../../core/voice/vosk_model_provider.dart';
import '../../core/voice/voice_output_service.dart';
import '../../data/models/account.dart';
import '../../data/models/general_settings.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
import '../settings/general_settings_provider.dart';
import '../transactions/transactions_provider.dart';
import 'arabic_number_parser.dart';
import 'voice_command_parser.dart';

/// Built once the Vosk model has finished loading (see vosk_model_provider.dart /
/// VoskModelGate) — `as VoskModelReady` is safe here specifically because every screen that can
/// reach this provider is already gated behind [voskModelControllerProvider] being in the
/// `VoskModelReady` state; if that ever stops being true, this throws loudly instead of silently
/// listening with a broken engine.
final offlineSpeechEngineProvider = Provider<OfflineSpeechEngine>((ref) {
  final modelState = ref.watch(voskModelControllerProvider);
  final model = (modelState as VoskModelReady).model;
  final engine = OfflineSpeechEngine(model: model);
  ref.onDispose(engine.dispose);
  return engine;
});

final systemSpeechEngineProvider = Provider<SystemSpeechEngine>((ref) {
  final engine = SystemSpeechEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// The dialogue reads this one provider only. Adding Whisper or a dedicated server provider
/// later means adding one adapter here; every parsing and saving path stays untouched.
final speechEngineProvider = Provider<SpeechEngine>((ref) {
  final mode = ref.watch(generalSettingsProvider).value?.voiceRecognitionMode ?? VoiceRecognitionMode.local;
  return switch (mode) {
    VoiceRecognitionMode.local => ref.watch(offlineSpeechEngineProvider),
    VoiceRecognitionMode.cloud => ref.watch(systemSpeechEngineProvider),
  };
});

final bluetoothAudioRouteServiceProvider = Provider<BluetoothAudioRouteService>((ref) => BluetoothAudioRouteService());

/// Speaks every step of the dialogue out loud — the confirmation question, clarification
/// questions, the final "saved" acknowledgement, edit prompts... This is what makes the whole
/// scenario work hands-free: without it, the person would have no way to know what the app
/// understood or what it's asking for next without looking at (and tapping) the screen.
final voiceOutputServiceProvider = Provider<VoiceOutputService>((ref) {
  final service = VoiceOutputService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) => const VoiceCommandParser());

/// KNOWN LIMITATION (see vosk_model_provider.dart's doc comment): kept as UI state for the
/// language-toggle button, but the offline engine is Arabic-only for now — toggling this does not
/// yet change which model/recognizer is used.
final voiceRecognitionLanguageProvider = StateProvider.autoDispose<String>((ref) => 'ar');

final voiceProvider = StateNotifierProvider.autoDispose<VoiceController, VoiceState>((ref) {
  return VoiceController(ref);
});

/// Whether the voice screen is showing the confirmation stage (the header swaps its title and
/// icon then). Deliberately SAFE to watch from the screen itself, i.e. ABOVE the Vosk model gate:
/// it never touches [voiceProvider] while the offline model isn't ready, because creating the
/// controller at that moment would throw (see [offlineSpeechEngineProvider]) and blank the page.
final voiceIsConfirmingProvider = Provider.autoDispose<bool>((ref) {
  final mode = ref.watch(generalSettingsProvider).value?.voiceRecognitionMode ?? VoiceRecognitionMode.local;
  if (mode == VoiceRecognitionMode.local && ref.watch(voskModelControllerProvider) is! VoskModelReady) {
    return false;
  }
  return ref.watch(
    voiceProvider.select(
      (s) => s.status == VoiceStatus.awaitingConfirmation || s.status == VoiceStatus.confirmationListening,
    ),
  );
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
    this.clarifyingField,
    this.suggestedAccount,
    this.processingStep = 0,
  });

  final VoiceStatus status;

  /// The full recognized text so far — this is what gets parsed and what the transcript card
  /// shows.
  final String transcript;

  /// Snapshot of [transcript] taken at the moment recording was paused.
  final String committedTranscript;

  final VoiceCommandDraft? draft;

  /// The matched EXISTING account, if any. `null` has two different meanings depending on
  /// [status]: while still gathering fields it means "not resolved yet"; once the dialogue has
  /// reached [VoiceStatus.awaitingConfirmation]/[VoiceStatus.confirmationListening] it means
  /// "no existing account matched this name — a brand-new one will be created with
  /// [VoiceCommandDraft.accountName] the moment the person confirms" (see
  /// VoiceController.confirm and _ConfirmationCard in voice_command_sheet.dart).
  final Account? account;
  final String? recordingPath;
  final DateTime? recordingStartedAt;
  final Duration elapsedBeforePause;
  final String? errorCode;
  final bool bluetoothMode;

  /// Which single field a `listening`/`bluetoothListeningCommand` session is currently gathering
  /// a spoken ANSWER for — `'amount'`, `'account'`, `'accountName'`, `'currency'`, `'direction'`,
  /// or `null` when this is an ordinary fresh command (not a follow-up clarification). This is
  /// what lets [VoiceController._onFinal] tell "the person just spoke a whole new command" apart
  /// from "the person just answered the one specific question I asked them a moment ago" — the
  /// two need completely different handling (re-parse everything vs. merge one field into the
  /// existing draft) even though both arrive through the exact same `listening` status.
  final String? clarifyingField;

  /// An EXISTING account whose name is very close to what was just heard — set while the
  /// `'sameAccount'` question ("هل تقصد الحساب …؟") is pending.
  final Account? suggestedAccount;

  /// Real progress of the `processing` status: 0 = turning audio into text (the recognizer is
  /// finalising), 1 = extracting name/amount/direction, 2 = validating against saved accounts.
  /// Driven by what the controller is actually doing — never by a timer.
  final int processingStep;

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
    String? clarifyingField,
    Account? suggestedAccount,
    int? processingStep,
    bool clearSuggestedAccount = false,
    bool clearDraft = false,
    bool clearAccount = false,
    bool clearError = false,
    bool clearClarifyingField = false,
    bool clearRecordingPath = false,
  }) => VoiceState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        committedTranscript: committedTranscript ?? this.committedTranscript,
        draft: clearDraft ? null : draft ?? this.draft,
        account: clearAccount ? null : account ?? this.account,
        recordingPath: clearRecordingPath ? null : recordingPath ?? this.recordingPath,
        recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
        elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
        errorCode: clearError ? null : errorCode ?? this.errorCode,
        bluetoothMode: bluetoothMode ?? this.bluetoothMode,
        clarifyingField: clearClarifyingField ? null : clarifyingField ?? this.clarifyingField,
        suggestedAccount: clearSuggestedAccount ? null : suggestedAccount ?? this.suggestedAccount,
        processingStep: processingStep ?? this.processingStep,
      );
}

/// The result of trying to interpret something said DURING confirmation as an EDIT instruction
/// (e.g. "عدّل المبلغ إلى 3500") rather than a plain yes/no/cancel reply. [accountNameHint] is
/// kept separate from [draft] because re-matching a spoken account name against the real account
/// list needs [VoiceController._matchAccount], which this pure parsing step has no access to.
class _VoiceEditResult {
  const _VoiceEditResult({this.draft, this.accountNameHint, this.field, this.needsAmount = false});
  final VoiceCommandDraft? draft;
  final String? accountNameHint;

  /// Which field was edited: `'amount'`, `'name'`, `'details'`, `'direction'` or `'date'`.
  final String? field;

  /// The person asked to change the amount but the new amount was unclear/garbled.
  final bool needsAmount;
  bool get isEmpty => draft == null && accountNameHint == null && !needsAmount;
}

class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._ref) : super(const VoiceState()) {
    _bindEngine();
  }

  static const wakeWord = 'ديوني';
  final Ref _ref;
  late SpeechEngine _engine;
  VoiceOutputService get _voiceOutput => _ref.read(voiceOutputServiceProvider);
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _finalSubscription;
  StreamSubscription<SpeechEngineError>? _errorSubscription;
  Timer? _bluetoothMonitor;
  Timer? _speechSilenceTimer;
  final _uuid = const Uuid();
  int _session = 0;

  /// How many consecutive NETWORK-class errors (see speech_engine.dart's
  /// [SpeechEngineErrorType.network]) the current listening attempt has silently absorbed and
  /// retried. THIS is the fix for "a medium/good-but-not-excellent connection means the app
  /// hears nothing": those errors used to be swallowed with no action at all (see the old
  /// `SystemSpeechEngine`'s `onError: (_) {}`), so the person just waited out the full silence
  /// timeout and was told — wrongly — that they hadn't said anything. Each retry restarts the
  /// recognizer with a short growing backoff; the person is never shown anything is wrong unless
  /// every retry in a row fails, exactly mirroring the same silent-retry philosophy already used
  /// for the Vosk model download (see vosk_model_provider.dart's `_downloadWithRetries`).
  static const _maxNetworkRetries = 4;
  int _networkRetryCount = 0;


  /// `true` once the person has answered (or no question was needed) for the account-name
  /// similarity check of the CURRENT command — prevents asking "same account?" twice.
  bool _nameDecided = false;

  /// Which field the last voice edit changed — consumed by the next confirmation speech so it can
  /// say "تم تعديل المبلغ إلى …" instead of a generic message.
  String? _lastEditedField;

  static const _speechEndAfter = Duration(seconds: 2);
  static const _noSpeechAfter = Duration(seconds: 8);

  void _armSpeechEndTimer([Duration? delay]) {
    _speechSilenceTimer?.cancel();
    _speechSilenceTimer = Timer(delay ?? _speechEndAfter, () {
      if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
        unawaited(stopAndAnalyze());
      } else if (state.status == VoiceStatus.confirmationListening) {
        unawaited(_finishVoiceConfirmation(state.transcript));
      }
    });
  }

  void _clearSpeechEndTimer() {
    _speechSilenceTimer?.cancel();
    _speechSilenceTimer = null;
  }

  void _bindEngine() {
    _partialSubscription?.cancel();
    _finalSubscription?.cancel();
    _errorSubscription?.cancel();
    _engine = _ref.read(speechEngineProvider);
    _partialSubscription = _engine.partialResults.listen(_onPartial);
    _finalSubscription = _engine.finalResults.listen(_onFinal);
    _errorSubscription = _engine.errors.listen(_onEngineError);
  }

  /// Routes a structured recognizer error (see speech_engine.dart). Only NETWORK-class errors
  /// are acted on here — everything else (genuine silence, permission problems) is left to the
  /// existing silence-timeout / permission-check paths, which already handle those correctly.
  void _onEngineError(SpeechEngineError error) {
    if (error.type == SpeechEngineErrorType.network) {
      unawaited(_retryAfterNetworkBlip());
    }
  }

  /// Silently restarts the SAME listening step after a connectivity error — never surfaced to
  /// the person unless [_maxNetworkRetries] consecutive attempts all fail, at which point (and
  /// only then) a real, honest error is shown instead of the misleading "no speech captured".
  /// A stray error that arrives after the session already moved on (e.g. the person already
  /// confirmed and the engine is idle) is ignored — this only ever resurrects an ACTIVE listen.
  Future<void> _retryAfterNetworkBlip() async {
    final listening = state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.bluetoothListeningCommand ||
        state.status == VoiceStatus.confirmationListening;
    if (!listening) return;

    if (_networkRetryCount >= _maxNetworkRetries) {
      _networkRetryCount = 0;
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'network');
      return;
    }
    _networkRetryCount++;
    final keptTranscript = state.transcript;
    final wasConfirmationListening = state.status == VoiceStatus.confirmationListening;
    try {
      await _engine.cancel();
    } catch (_) {
      // Best effort — the restart below is what actually matters.
    }
    await Future<void>.delayed(Duration(milliseconds: 300 * _networkRetryCount));
    // The session may have moved on (person cancelled, screen closed) while we waited.
    final stillListening = state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.bluetoothListeningCommand ||
        (wasConfirmationListening && state.status == VoiceStatus.confirmationListening);
    if (!stillListening) return;
    try {
      await _startEngine();
      state = state.copyWith(transcript: keptTranscript);
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      // Another error event (or the outer silence timeout) will take it from here.
    }
  }

  /// The recognizer must be listening within this time or it is treated as stuck.
  static const _engineStartTimeout = Duration(seconds: 6);

  /// Starts the engine with a HARD time limit. Reported symptom: the screen stayed on "listening"
  /// for minutes and never failed, succeeded or asked anything — that is `start()` never
  /// returning (so the silence timer was never even armed). Now a start that does not complete in
  /// [_engineStartTimeout] releases the engine and tries exactly once more; if that also times
  /// out the exception reaches the caller, which shows a real error instead of waiting forever.
  Future<void> _startEngine() async {
    try {
      await _engine.start().timeout(_engineStartTimeout);
    } on TimeoutException {
      debugPrint('[voice] engine start timed out - releasing and retrying once');
      try {
        await _engine.release().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Best effort — the retry below is what matters.
      }
      await _engine.start().timeout(_engineStartTimeout);
    }
  }

  /// A timeout means the recognizer itself is stuck ("recognition"); anything else here is the
  /// permission/availability failure the old code assumed for every exception.
  String _startFailureCode(Object error) => error is TimeoutException ? 'recognition' : 'permission';

  /// Provider changes are intentionally limited to idle state. This releases the old engine
  /// before rebinding streams, so a single utterance can never be split between recognizers.
  Future<void> setRecognitionMode(VoiceRecognitionMode mode) async {
    if (state.status != VoiceStatus.idle) return;
    final current = _ref.read(generalSettingsProvider).value?.voiceRecognitionMode ?? VoiceRecognitionMode.local;
    if (current == mode) return;
    // Free the microphone and native recognizer of the engine being left BEFORE the other one is
    // used. Root cause of "cloud hears nothing after a local session": the old engine's native
    // resources were never released on a switch, so the OS recognizer started against a busy or
    // stale audio path and its error was ignored.
    final leaving = _engine;
    try {
      await leaving.release();
    } catch (_) {
      // Releasing is best effort; the new engine below re-initialises itself anyway.
    }
    await _ref.read(generalSettingsProvider.notifier).setVoiceRecognitionMode(mode);
    _bindEngine();
  }

  // ─────────────────────────── Phrase builders (all spoken aloud) ───────────────────────────

  /// Spoken currency names — the raw code ("LOCAL", "YER") must never reach the speech engine.
  String _currencySpoken(String code, String languageCode) {
    if (languageCode == 'en') {
      return switch (code) {
        'YER' => 'Yemeni rial',
        'USD' => 'US dollars',
        'SAR' => 'Saudi riyals',
        'AED' => 'dirhams',
        'EGP' => 'Egyptian pounds',
        'KWD' => 'dinars',
        _ => 'local currency',
      };
    }
    return switch (code) {
      'YER' => 'ريال يمني',
      'USD' => 'دولار',
      'SAR' => 'ريال سعودي',
      'AED' => 'درهم',
      'EGP' => 'جنيه',
      'KWD' => 'دينار',
      _ => 'محلي',
    };
  }

  String _formatAmount(double amount) =>
      amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

  /// [accountName] is a plain string rather than an [Account] — by the time this is spoken,
  /// there may not be a real matched account yet at all (see [VoiceState.account]'s doc comment
  /// on what a `null` match means once confirmation is reached: a new account will be created).
  /// [editedField] (see [_VoiceEditResult.field]) switches to the "تم تعديل …" wording.
  String _confirmationSpeech(VoiceCommandDraft draft, String accountName, String languageCode, {String? editedField}) {
    final amountText = _formatAmount(draft.amount!);
    final currency = _currencySpoken(draft.currency, languageCode);
    final isDebit = draft.direction == AccountDirection.debit;
    if (languageCode == 'en') {
      if (editedField != null) {
        final what = switch (editedField) {
          'amount' => 'The amount is now $amountText $currency',
          'name' => 'The account is now $accountName',
          'details' => 'The details are now ${draft.details ?? 'empty'}',
          'direction' => 'The type is now ${isDebit ? 'debit' : 'credit'}',
          _ => 'The date is now ${draft.date.year}-${draft.date.month}-${draft.date.day}',
        };
        return '$what. Would you like to save or edit?';
      }
      final directionWord = isDebit ? 'as a debit for' : 'as a credit for';
      final details = draft.details != null ? ', details ${draft.details}' : '';
      return "I'll add $amountText $currency $directionWord $accountName$details. Would you like to save or edit?";
    }
    if (editedField != null) {
      final what = switch (editedField) {
        'amount' => 'تم تعديل المبلغ إلى $amountText $currency',
        'name' => 'تم تعديل الحساب إلى $accountName',
        'details' => draft.details == null ? 'تم حذف التفاصيل' : 'تم تعديل التفاصيل إلى ${draft.details}',
        'direction' => 'تم تعديل النوع إلى ${isDebit ? 'عليه' : 'له'}',
        _ => 'تم تعديل التاريخ إلى ${draft.date.year}-${draft.date.month}-${draft.date.day}',
      };
      return '$what، هل تريد الحفظ أو التعديل؟';
    }
    final directionWord = isDebit ? 'على' : 'لـ';
    final details = draft.details != null ? '، التفاصيل ${draft.details}' : '';
    return 'سأضيف $directionWord $accountName مبلغ $amountText $currency$details. هل تريد الحفظ أو التعديل؟';
  }

  /// [detail] carries the one dynamic value some questions need (the suggested account name).
  String _clarificationSpeech(String field, String languageCode, {String? detail}) {
    if (languageCode == 'en') {
      return switch (field) {
        'amount' => "I couldn't understand the amount. Please say the amount clearly.",
        'amountUncertain' => "I wasn't sure about the amount. Please say only the amount again.",
        'account' => "I couldn't match an account. Please say the account name clearly.",
        'accountName' =>
          "The account name needs a first and last name. Please say the full account name.",
        'sameAccount' => 'Do you mean the existing account $detail? Say yes or no.',
        'currency' =>
          "That currency isn't supported. Please say a supported one — Yemeni Rial, Saudi Riyal, "
              "US Dollar, Dirham, Pound, or Dinar.",
        'direction' => 'Is this credit or debit? Please say credit or debit.',
        'editWhat' => 'Please say your edit.',
        _ => "I didn't hear anything. Please try speaking clearly.",
      };
    }
    return switch (field) {
      'amount' => 'لم أتعرف على المبلغ. من فضلك قل المبلغ بوضوح.',
      'amountUncertain' => 'لم أتأكد من المبلغ. من فضلك قل المبلغ فقط مرة أخرى.',
      'account' => 'لم أتعرف على اسم الحساب. من فضلك قل اسم الحساب بوضوح.',
      'accountName' => 'اسم الحساب يجب أن يتكون من اسمين على الأقل. من فضلك أكمل الاسم الناقص.',
      'sameAccount' => 'هل تقصد الحساب الموجود $detail؟ قل نعم أو لا.',
      'currency' => 'هذه العملة غير مدعومة. من فضلك قل عملة مدعومة، مثل ريال يمني أو سعودي أو دولار أو درهم أو جنيه أو دينار.',
      'direction' => 'لم أفهم هل هذا الدين له أم عليه. من فضلك قل له أو عليه.',
      _ => 'لم ألتقط أي صوت. من فضلك حاول التحدث بوضوح.',
    };
  }

  String _successSpeech(String languageCode) => languageCode == 'en' ? 'Entry saved successfully.' : 'تم حفظ العملية بنجاح.';

  String _notUnderstoodSpeech(String languageCode) =>
      languageCode == 'en' ? "I didn't understand. Say save, edit, or cancel." : 'لم أفهم. قل حفظ، أو تعديل، أو إلغاء.';

  String _askEditSpeech(String languageCode) => languageCode == 'en' ? 'Please say your edit.' : 'من فضلك قل تعديلك.';

  String _cancelledSpeech(String languageCode) => languageCode == 'en' ? 'Cancelled.' : 'تم الإلغاء.';

  Future<void> _speak(String text) async {
    final languageCode = _ref.read(voiceRecognitionLanguageProvider);
    await _voiceOutput.speak(text, languageCode: languageCode);
  }

  // ─────────────────────────────────── Entry points ───────────────────────────────────

  /// Called once when the voice screen opens, for BOTH entry modes.
  void setEntryMode({required bool bluetoothMode}) {
    ++_session;
    _networkRetryCount = 0;
    state = VoiceState(bluetoothMode: bluetoothMode);
  }

  Future<void> startShortPress() async {
    await _beginListening(bluetoothMode: false);
  }

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
      await _startEngine();
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
    final session = ++_session;
    _networkRetryCount = 0;
    state = VoiceState(status: VoiceStatus.preparing, bluetoothMode: bluetoothMode);
    // Bounded too: a recognizer whose initialisation never answers must not freeze the screen.
    final granted = await _engine.hasPermission().timeout(const Duration(seconds: 8), onTimeout: () => false);
    if (!granted) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      return;
    }
    state = state.copyWith(
      status: bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: DateTime.now(),
      clearError: true,
    );
    try {
      await _startEngine();
      if (session != _session) {
        await _engine.cancel();
        return;
      }
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: _startFailureCode(e));
    }
  }

  Future<void> pauseRecording() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    _clearSpeechEndTimer();
    final startedAt = state.recordingStartedAt;
    final elapsedThisRun = startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
    try {
      await _engine.pause();
    } catch (_) {
      if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
        state = state.copyWith(status: VoiceStatus.error, errorCode: 'recognition');
      }
      return;
    }
    state = state.copyWith(
      status: VoiceStatus.paused,
      committedTranscript: state.transcript,
      elapsedBeforePause: state.elapsedBeforePause + elapsedThisRun,
    );
  }

  Future<void> resumeRecording() async {
    if (state.status != VoiceStatus.paused) return;
    final session = ++_session;
    try {
      await _engine.resume();
    } catch (_) {
      if (session == _session) state = state.copyWith(status: VoiceStatus.error, errorCode: 'recognition');
      return;
    }
    if (session != _session || state.status != VoiceStatus.paused) return;
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: DateTime.now(),
      clearError: true,
    );
  }

  // ───────────────────────── Recognition result routing ─────────────────────────

  void _onPartial(String text) {
    if (state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.bluetoothListeningCommand ||
        state.status == VoiceStatus.confirmationListening) {
      // A real partial result arrived — the connection is clearly fine again, so forgive any
      // earlier retried network blip for this session instead of letting it count toward the
      // next unrelated listen.
      _networkRetryCount = 0;
      state = state.copyWith(transcript: text);
      _armSpeechEndTimer();
      return;
    }
    if (state.status == VoiceStatus.bluetoothWaitingWakeWord) {
      if (text.replaceAll(' ', '').contains(wakeWord)) {
        state = state.copyWith(status: VoiceStatus.bluetoothWakeWordDetected, transcript: text);
        unawaited(_restartAfterWakeWord());
      }
    }
  }

  Future<void> _restartAfterWakeWord() async {
    final (_, wakeWordRecordingPath) = await _engine.stop();
    await _deleteRecording(wakeWordRecordingPath);
    if (state.status == VoiceStatus.bluetoothWakeWordDetected) {
      await _beginListening(bluetoothMode: true);
    }
  }

  /// The instant the person stops talking and the engine settles on a final transcript, this
  /// fires and moves the dialogue forward immediately — no button, no delay beyond the analysis
  /// itself, matching "بمجرد أن ينتهي المستخدم من التحدث يرد مباشرة".
  void _onFinal(String text) {
    _networkRetryCount = 0;
    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
      state = state.copyWith(transcript: text);
      _armSpeechEndTimer();
      // Vosk returns a final result after an ordinary short pause. Treating that as the end of
      // the command used to discard everything said afterwards, including amounts. The mic tap
      // remains the explicit end-of-command action, while the final text stays visible live.
      if (_engine.endsSessionOnFinal) {
        if (state.clarifyingField != null) {
          unawaited(_finishClarificationListening());
        } else {
          unawaited(_finishListening());
        }
      }
      return;
    }
    if (state.status == VoiceStatus.confirmationListening) {
      state = state.copyWith(transcript: text);
      unawaited(_finishVoiceConfirmation(text));
    }
  }

  Future<void> _finishVoiceConfirmation(String text) async {
    _clearSpeechEndTimer();
    final (_, confirmationRecordingPath) = await _engine.stop();
    await _deleteRecording(confirmationRecordingPath);
    final effective = text.trim().isNotEmpty ? text : state.transcript;
    if (effective.trim().isEmpty) {
      await _confirmationNotUnderstood();
      return;
    }
    await _handleVoiceConfirmation(effective);
  }

  Future<void> stopAndAnalyze() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    _clearSpeechEndTimer();
    if (state.clarifyingField != null) {
      await _finishClarificationListening();
    } else {
      await _finishListening();
    }
  }

  /// Fresh top-level command finished — parse EVERYTHING from scratch. If nothing was heard at
  /// all, this now asks again OUT LOUD and starts listening again automatically instead of
  /// stopping and waiting for a manual tap.
  Future<void> _finishListening() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
    _clearSpeechEndTimer();
    final current = state;
    final session = _session;
    state = state.copyWith(status: VoiceStatus.processing, processingStep: 0);

    final (engineTranscript, recordingPath) = await _engine.stop();
    if (session != _session || state.status != VoiceStatus.processing) {
      await _deleteRecording(recordingPath);
      return;
    }
    final effectiveTranscript = _pickBestTranscript(
      _chooseMoreCompleteTranscript(current.transcript, engineTranscript),
      _engine.lastAlternatives,
    );

    if (effectiveTranscript.trim().isEmpty) {
      await _deleteRecording(recordingPath);
      state = state.copyWith(
        status: VoiceStatus.needsClarification,
        errorCode: 'noSpeech',
        clearRecordingPath: true,
      );
      await _speak(_clarificationSpeech('noSpeech', _ref.read(voiceRecognitionLanguageProvider)));
      state = state.copyWith(
        status: current.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
        transcript: '',
        clearError: true,
      );
      try {
        await _startEngine();
        _armSpeechEndTimer(_noSpeechAfter);
      } catch (e) {
        state = state.copyWith(status: VoiceStatus.error, errorCode: _startFailureCode(e));
      }
      return;
    }

    state = state.copyWith(processingStep: 1);
    var draft = _ref.read(voiceCommandParserProvider).parse(effectiveTranscript);
    if (_amountDoubtedByAlternatives(effectiveTranscript, _engine.lastAlternatives)) {
      // Same audio, different hypotheses about the number → the recognizer itself is not sure.
      // Ask for the amount instead of saving a guess.
      draft = draft.withUncertainAmount();
    }
    state = state.copyWith(processingStep: 2);
    _nameDecided = false;
    _lastEditedField = null;
    final account = _matchAccount(draft.accountName, effectiveTranscript);
    state = state.copyWith(
      transcript: effectiveTranscript,
      draft: draft,
      account: account,
      clearAccount: account == null,
      recordingPath: recordingPath ?? current.recordingPath,
    );
    await _advanceAfterParsing(draft: draft, account: account);
  }

  /// A follow-up answer to ONE specific clarification question finished — merge just that field
  /// into the EXISTING draft (never re-parse the whole thing from scratch, which would throw
  /// away every other field already understood correctly).
  Future<void> _finishClarificationListening() async {
    _clearSpeechEndTimer();
    final current = state;
    final session = _session;
    final field = current.clarifyingField;
    final draft = current.draft;
    state = state.copyWith(status: VoiceStatus.processing, processingStep: 0);
    final (engineTranscript, recordingPath) = await _engine.stop();
    if (session != _session || state.status != VoiceStatus.processing) {
      await _deleteRecording(recordingPath);
      return;
    }
    final effective = _chooseMoreCompleteTranscript(current.transcript, engineTranscript);

    // Follow-up audio is only used to complete the text field; the original command remains the
    // sole audio attachment for the financial entry.
    await _deleteRecording(recordingPath);

    if (draft == null || field == null) {
      state = state.copyWith(status: VoiceStatus.idle);
      return;
    }

    if (effective.trim().isEmpty) {
      await _speak(_clarificationSpeech('noSpeech', _ref.read(voiceRecognitionLanguageProvider)));
      state = state.copyWith(
        status: current.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
        transcript: '',
        clearError: true,
      );
      try {
        await _startEngine();
        _armSpeechEndTimer(_noSpeechAfter);
      } catch (e) {
        state = state.copyWith(status: VoiceStatus.error, errorCode: _startFailureCode(e));
      }
      return;
    }

    var updatedDraft = draft;
    var updatedAccount = current.account;
    switch (field) {
      case 'amount':
        // The answer is JUST an amount phrase — evaluated by the same number engine as a full
        // command. Cloud alternatives are tried too, so one garbled hypothesis doesn't force a
        // re-ask when another one is clean. An uncertain/garbled answer changes nothing, and
        // _advanceAfterParsing asks again.
        final parser = _ref.read(voiceCommandParserProvider);
        for (final candidate in [effective, ..._engine.lastAlternatives]) {
          final extraction = parser.parseAmount(candidate);
          if (extraction.value != null) {
            updatedDraft = draft.copyWith(amount: extraction.value);
            final explicitCurrency = _explicitCurrency(candidate);
            if (explicitCurrency != null) {
              updatedDraft = updatedDraft.copyWith(currency: explicitCurrency);
            }
            break;
          }
        }
      case 'account':
        // The person restated the whole account name — try matching it against an existing
        // account first; if none matches, keep the freshly-spoken name as-is (a brand-new
        // account will be created from it once it passes the full-name check below).
        final matched = _matchAccount(effective, effective);
        updatedAccount = matched;
        updatedDraft = draft.copyWith(accountName: matched?.name ?? effective.trim());
      case 'accountName':
        // FIX: the person was only ever asked for this because the FIRST attempt already had a
        // partial name (e.g. just "عبدالقدوس") that failed the two-word minimum — see
        // VoiceCommandParser.hasFullName, the same rule add_account_screen.dart enforces
        // manually. The previous version of this branch replaced the name OUTRIGHT with
        // whatever was said next, which silently DISCARDED the part already understood: saying
        // only the missing last name ("محمد") produced the account name "محمد" alone — still a
        // single word, so it failed the same check again and looped forever asking the same
        // question. The fix: APPEND the new answer to whatever name fragment is already on the
        // draft, so "عبدالقدوس" + "محمد" becomes "عبدالقدوس محمد" — exactly completing the name
        // instead of replacing it. If the person instead restates the FULL name on their own
        // (common when asked to "say the account name clearly"), the combined string still
        // matches correctly against the saved account list below.
        final existingFragment = (draft.accountName ?? '').trim();
        final spoken = effective.trim();
        final combinedName = existingFragment.isEmpty
            ? spoken
            : (spoken.toLowerCase().contains(existingFragment.toLowerCase()) ? spoken : '$existingFragment $spoken');
        final matched = _matchAccount(combinedName, combinedName);
        updatedAccount = matched;
        updatedDraft = draft.copyWith(accountName: matched?.name ?? combinedName);
      case 'currency':
        final reparsedCurrency = _ref.read(voiceCommandParserProvider).parse(effective);
        if (!reparsedCurrency.currencyUnsupported) {
          updatedDraft = draft.copyWith(currency: reparsedCurrency.currency, currencyUnsupported: false);
        }
        // If still unsupported, currencyUnsupported stays true on `draft` unchanged, and
        // _advanceAfterParsing below will simply ask again.
      case 'direction':
        final spokenDirection = _ref.read(voiceCommandParserProvider).parseDirection(effective);
        if (spokenDirection != null) updatedDraft = draft.copyWith(direction: spokenDirection);
      case 'sameAccount':
        final answer = _yesNo(effective);
        final suggested = current.suggestedAccount;
        if (answer == true && suggested != null) {
          updatedAccount = suggested;
          updatedDraft = draft.copyWith(accountName: suggested.name);
          _nameDecided = true;
        } else if (answer == false) {
          _nameDecided = true; // a genuinely different person — a new account will be created.
        }
        // No clear yes/no → still undecided; _advanceAfterParsing simply asks again.
    }

    state = state.copyWith(
      draft: updatedDraft,
      account: updatedAccount,
      clearAccount: updatedAccount == null,
      recordingPath: current.recordingPath,
      clearClarifyingField: true,
      clearSuggestedAccount: true,
    );
    await _advanceAfterParsing(draft: updatedDraft, account: updatedAccount);
  }

  /// Name (missing / one word) → "same account?" check → direction → amount → currency, then
  /// confirmation. The order follows what the person is most likely to be able to repair by
  /// voice: who it is, which side, then the number. Only the UNCLEAR field is ever asked about —
  /// everything already understood stays on the draft. Every branch SPEAKS its question and then
  /// listens again on its own. A `null` [VoiceState.account] at confirmation simply means a
  /// brand-new account will be created from [VoiceCommandDraft.accountName].
  Future<void> _advanceAfterParsing({required VoiceCommandDraft draft, required Account? account}) async {
    final accountName = draft.accountName;
    if (accountName == null) {
      await _ask('account', 'account');
    } else if (!VoiceCommandParser.hasFullName(accountName)) {
      // A name was heard, but it's only a single word — an account needs a first AND last name.
      await _ask('accountName', 'accountName');
    } else if (account == null && !_nameDecided && _similarAccount(accountName) != null) {
      final similar = _similarAccount(accountName)!;
      state = state.copyWith(suggestedAccount: similar);
      await _ask('sameAccount', 'sameAccount', detail: similar.name);
    } else if (draft.direction == null) {
      await _ask('direction', 'direction');
    } else if (draft.amount == null) {
      await _ask('amount', draft.amountUncertain ? 'amountUncertain' : 'amount');
    } else if (draft.currencyUnsupported) {
      await _ask('currency', 'currency');
    } else {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, clearError: true, clearClarifyingField: true);
      await _speakThenListenForConfirmation();
    }
  }

  /// [field] is the dialogue slot being filled; [speechKey] picks the exact wording (the amount
  /// slot has a distinct "I wasn't sure" phrasing for garbled numbers).
  Future<void> _ask(String field, String speechKey, {String? detail}) async {
    state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: field, clarifyingField: field);
    await _speakThenListenForClarification(speechKey, detail: detail);
  }

  Future<void> _speakThenListenForClarification(String field, {String? detail}) async {
    final session = _session;
    _clearSpeechEndTimer();
    await _speak(_clarificationSpeech(field, _ref.read(voiceRecognitionLanguageProvider), detail: detail));
    if (session != _session) return;
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      clearError: true,
      transcript: '',
      // This is a follow-up answer, not the primary recorded command. Keep the original start
      // timestamp so the recording metadata remains associated with the first command.
    );
    try {
      await _startEngine();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: _startFailureCode(e));
    }
  }

  Future<void> _speakThenListenForConfirmation() async {
    final session = _session;
    _clearSpeechEndTimer();
    final draft = state.draft;
    final accountName = state.account?.name ?? draft?.accountName;
    if (draft == null || accountName == null || draft.amount == null || draft.direction == null) return;
    final languageCode = _ref.read(voiceRecognitionLanguageProvider);
    final editedField = _lastEditedField;
    _lastEditedField = null;
    await _speak(_confirmationSpeech(draft, accountName, languageCode, editedField: editedField));
    if (session != _session) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _startEngine();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: _startFailureCode(e));
    }
  }

  /// Manual mic-tap fallback (see VoiceCommandSheet) — kept working even though the confirmation
  /// question is now asked and listened for automatically; this covers the rare case where the
  /// automatic listen failed to start (e.g. a transient permission hiccup) and the person wants
  /// to retry it themselves without restarting the whole command.
  Future<void> startVoiceConfirmation() async {
    if (state.status != VoiceStatus.awaitingConfirmation) return;
    await _speakThenListenForConfirmation();
  }

  // ───────────────────────── Confirmation: yes / cancel / edit ─────────────────────────

  /// Handles whatever the person says in reply to the confirmation question. Tries, IN ORDER:
  /// (1) a fully-specified edit ("عدّل المبلغ إلى 3500") — applied directly, no extra round trip;
  /// (2) a plain yes → save; (3) a plain no/cancel → abort; (4) a bare "عدّل"/"تعديل" with no
  /// specifics → ask what to change, then listen again; (5) anything else → say "لم أفهم" and
  /// listen again. This ordering is what lets both of the scenario's edit paths work: the
  /// one-step "عدل المبلغ الى 3500" AND the two-step "تعديل" → "من فضلك قل تعديلك" → "المبلغ 3500".
  Future<void> _handleVoiceConfirmation(String spoken) async {
    final draft = state.draft;
    if (draft == null) return;
    final tokens = _speechTokens(spoken);

    // 1. Cancel is checked FIRST and acts immediately — never gated behind another question.
    const strongCancel = {'الغ', 'الغاء', 'الغي', 'الغيه', 'cancel', 'توقف', 'كنسل'};
    const weakCancel = {'لا', 'no', 'رجوع'};
    if (tokens.any(strongCancel.contains) || (tokens.length <= 2 && tokens.any(weakCancel.contains))) {
      await _cancelWithSpeech();
      return;
    }

    // 2. A fully-specified edit ("عدل المبلغ إلى خمسة ألف وخمسمائة") — applied directly.
    final edit = _tryParseEdit(spoken, draft);
    if (edit != null && !edit.isEmpty) {
      await _applyEdit(edit);
      return;
    }

    // 3. Save on the FIRST utterance of any ordinary "yes"/"save" word.
    if (_isYes(tokens)) {
      await confirm();
      return;
    }

    // 4. A bare "تعديل" — ask what to change.
    const editWords = {'تعديل', 'عدل', 'غير', 'غيير', 'تغيير', 'بدل', 'edit', 'change'};
    if (tokens.any(editWords.contains)) {
      await _askWhatToEditThenListen();
      return;
    }
    await _confirmationNotUnderstood();
  }

  /// Lower-cased tokens with diacritics removed, alef variants unified and ة→ه — used ONLY for
  /// comparing against small keyword sets (never for text that is stored or shown).
  List<String> _speechTokens(String text) => [
        for (final t in text.trim().split(RegExp(r'\s+')))
          if (t.isNotEmpty) ArabicNumberParser.normalizeWord(t),
      ];

  static const _yesTokens = {
    'نعم', 'ايوه', 'ايوا', 'ايه', 'اي', 'صحيح', 'صح', 'موافق', 'تمام', 'اكد', 'تاكيد', 'اوك',
    'yes', 'correct', 'save', 'ok', 'okay', 'yeah',
  };

  bool _isYes(List<String> tokens) =>
      tokens.any((t) => _yesTokens.contains(t) || t.startsWith('حفظ') || t.startsWith('احفظ'));

  /// `true` = yes, `false` = no, `null` = neither (used for the "same account?" question).
  bool? _yesNo(String text) {
    final tokens = _speechTokens(text);
    if (tokens.any(const {'لا', 'no', 'مختلف', 'ليس'}.contains)) return false;
    if (_isYes(tokens)) return true;
    return null;
  }

  Future<void> _applyEdit(_VoiceEditResult edit) async {
    final draft = state.draft;
    if (draft == null) return;
    if (edit.needsAmount) {
      // "عدل المبلغ" was said but the new amount was unclear — ask for ONLY the amount.
      _lastEditedField = 'amount';
      await _ask('amount', 'amountUncertain');
      return;
    }
    var updatedDraft = edit.draft ?? draft;
    var updatedAccount = state.account;
    if (edit.accountNameHint != null) {
      final matched = _matchAccount(edit.accountNameHint, edit.accountNameHint!);
      updatedAccount = matched;
      updatedDraft = updatedDraft.copyWith(accountName: matched?.name ?? edit.accountNameHint);
      _nameDecided = false;
    }
    _lastEditedField = edit.field;
    state = state.copyWith(
      draft: updatedDraft,
      account: updatedAccount,
      clearAccount: updatedAccount == null,
      clearError: true,
      clearClarifyingField: true,
      clearSuggestedAccount: true,
    );
    await _advanceAfterParsing(draft: updatedDraft, account: updatedAccount);
  }

  Future<void> _askWhatToEditThenListen() async {
    final session = _session;
    _clearSpeechEndTimer();
    await _speak(_askEditSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    if (session != _session) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _startEngine();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: _startFailureCode(e));
    }
  }

  /// Explicit UI edit action. Unlike retry, this keeps the recognized draft intact and asks
  /// only for the requested amendment.
  Future<void> startEdit() async {
    if (state.draft == null || (state.status != VoiceStatus.awaitingConfirmation && state.status != VoiceStatus.confirmationListening)) return;
    ++_session;
    _clearSpeechEndTimer();
    state = state.copyWith(status: VoiceStatus.awaitingConfirmation, transcript: '');
    await _engine.cancel();
    await _askWhatToEditThenListen();
  }

  Future<void> _confirmationNotUnderstood() async {
    final session = _session;
    _clearSpeechEndTimer();
    state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'confirmation');
    await _speak(_notUnderstoodSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    if (session != _session) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _startEngine();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: _startFailureCode(e));
    }
  }

  /// Cancel is immediate: the screen resets FIRST, the spoken "تم الإلغاء" follows without
  /// blocking anything.
  Future<void> _cancelWithSpeech() async {
    ++_session;
    _clearSpeechEndTimer();
    _nameDecided = false;
    _lastEditedField = null;
    final path = state.recordingPath;
    state = const VoiceState();
    unawaited(_deleteRecording(path));
    unawaited(_speak(_cancelledSpeech(_ref.read(voiceRecognitionLanguageProvider))));
  }

  Future<void> _deleteRecording(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Audio cleanup is best effort; never block saving/cancelling a financial entry for it.
    }
  }

  /// Some recognizers emit a short partial just before stopping and a fuller final transcript
  /// afterwards. Prefer the result carrying more words, so a final amount is never discarded
  /// merely because a partial arrived first.
  String _chooseMoreCompleteTranscript(String live, String finalResult) {
    final liveTrimmed = live.trim();
    final finalTrimmed = finalResult.trim();
    if (finalTrimmed.split(RegExp(r'\s+')).length > liveTrimmed.split(RegExp(r'\s+')).length) return finalTrimmed;
    return liveTrimmed.isNotEmpty ? liveTrimmed : finalTrimmed;
  }

  /// Edit parser for the confirmation step. It looks for the FIELD word the person named (المبلغ /
  /// الاسم·الحساب / التفاصيل / النوع / التاريخ) and takes the value that follows it, so all of
  /// these work in one sentence: "عدل المبلغ إلى خمسة ألف وخمسمائة"، "غير الاسم إلى أحمد علي"،
  /// "تعديل التفاصيل حق كهرباء"، "عدل النوع له"، "غير التاريخ إلى أمس" — with or without the edit
  /// verb (after a bare "تعديل" the person just says "المبلغ خمسة ألف"). When several field words
  /// occur, the FIRST one wins. Returns `null` when the text names no field at all, so the caller
  /// falls through to yes/cancel handling instead of misfiring on an unrelated sentence.
  _VoiceEditResult? _tryParseEdit(String text, VoiceCommandDraft draft) {
    final raw = text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (raw.isEmpty) return null;
    final norm = [for (final t in raw) ArabicNumberParser.normalizeWord(t)];

    const fields = <String, Set<String>>{
      'amount': {'المبلغ', 'مبلغ', 'القيمه', 'قيمه', 'الرقم', 'السعر'},
      'name': {'الاسم', 'اسم', 'الحساب', 'حساب', 'صاحب'},
      'details': {'التفاصيل', 'تفاصيل', 'الملاحظات', 'ملاحظات', 'البيان', 'بيان', 'الوصف'},
      'direction': {'النوع', 'نوع', 'الاتجاه'},
      'date': {'التاريخ', 'تاريخ'},
    };
    String? field;
    var fieldIndex = -1;
    for (var i = 0; i < norm.length && field == null; i++) {
      for (final entry in fields.entries) {
        if (entry.value.contains(norm[i])) {
          field = entry.key;
          fieldIndex = i;
          break;
        }
      }
    }

    const connectors = {'الى', 'ل', 'لي', 'يصير', 'يكون', 'خله', 'خلي', 'اجعله', 'اجعل', 'هو', 'يبقى', 'بدل', 'من'};
    List<String> valueTokens(int from) {
      var i = from;
      while (i < raw.length && connectors.contains(norm[i])) {
        i++;
      }
      return raw.sublist(i);
    }

    final parser = _ref.read(voiceCommandParserProvider);
    switch (field) {
      case 'amount':
      {
        final valueText = valueTokens(fieldIndex + 1).join(' ');
        final extraction = parser.parseAmount(valueText);
        final value = extraction.value;
        if (value == null) return const _VoiceEditResult(needsAmount: true);
        var updated = draft.copyWith(amount: value);
        final explicitCurrency = _explicitCurrency(valueText);
        if (explicitCurrency != null) updated = updated.copyWith(currency: explicitCurrency);
        return _VoiceEditResult(draft: updated, field: 'amount');
      }
      case 'name':
      {
        final words = valueTokens(fieldIndex + 1).take(4).toList();
        if (words.isEmpty) return null;
        return _VoiceEditResult(accountNameHint: words.join(' '), field: 'name');
      }
      case 'details':
      {
        final value = valueTokens(fieldIndex + 1).join(' ').trim();
        if (value.isEmpty) return null;
        return _VoiceEditResult(draft: draft.copyWith(details: value), field: 'details');
      }
      case 'direction':
      {
        final direction = parser.parseDirection(valueTokens(fieldIndex + 1).join(' '));
        if (direction == null) return null;
        return _VoiceEditResult(draft: draft.copyWith(direction: direction), field: 'direction');
      }
      case 'date':
      {
        final valueText = valueTokens(fieldIndex + 1).join(' ');
        if (valueText.isEmpty) return null;
        return _VoiceEditResult(draft: draft.copyWith(date: parser.parse(valueText).date), field: 'date');
      }
    }

    // No field word: a bare direction edit such as "خله عليه" / "اجعله له".
    const directionVerbs = {'خله', 'خلي', 'اجعله', 'اجعل', 'غير', 'عدل', 'تعديل'};
    if (norm.any(directionVerbs.contains)) {
      final direction = parser.parseDirection(text);
      if (direction != null && direction != draft.direction) {
        return _VoiceEditResult(draft: draft.copyWith(direction: direction), field: 'direction');
      }
    }
    return null;
  }

  /// A currency the speaker NAMED explicitly (a bare "ريال" does not count — it must never
  /// silently change the currency of an amount that is only being corrected).
  String? _explicitCurrency(String text) {
    if (!RegExp('يمني|سعودي|دولار|درهم|جنيه|دينار|اماراتي|إماراتي|مصري|كويتي').hasMatch(text)) return null;
    final parsed = _ref.read(voiceCommandParserProvider).parse(text);
    return parsed.currencyUnsupported ? null : parsed.currency;
  }

  /// Cloud recognizers return several ranked hypotheses. Keep the first unless a LATER one parses
  /// strictly better — a readable amount (+4), a two-word name (+2), an explicit direction (+1);
  /// a garbled amount costs 2. Ties keep the recognizer's own top choice.
  /// `true` when the chosen transcript's amount is a bare "ألف"/"مليون" while another hypothesis
  /// of the SAME audio holds a noisy or different number phrase. Example: Vosk's top result is
  /// "أحمد عليه ألف ريال" but its 2nd is "أحمد عليه إلا ألف ريال" — the person most likely said
  /// "خمسة ألف" and the best hypothesis simply lost the word. Saving 1000 there is the
  /// reported "التعويض بألف"; asking is the honest behaviour.
  bool _amountDoubtedByAlternatives(String chosen, List<String> alternatives) {
    if (alternatives.length < 2) return false;
    final parser = _ref.read(voiceCommandParserProvider);
    final main = parser.parseAmount(chosen);
    if (main.value == null || !main.bare) return false;
    for (final candidate in alternatives) {
      if (candidate == chosen) continue;
      final other = parser.parseAmount(candidate);
      if (other.uncertain) return true;
      if (other.value != null && other.value != main.value) return true;
    }
    return false;
  }

  String _pickBestTranscript(String primary, List<String> alternatives) {
    if (alternatives.length < 2) return primary;
    final parser = _ref.read(voiceCommandParserProvider);
    int score(String text) {
      final d = parser.parse(text);
      var v = 0;
      if (d.amount != null) {
        // A bare "ألف" is what is left when the number word before it was dropped, so it must
        // never beat a hypothesis that kept the uncertainty — that was the silent "1000".
        v += parser.parseAmount(text).bare ? -2 : 4;
      } else if (d.amountUncertain) {
        v -= 2;
      }
      final name = d.accountName;
      if (name != null && VoiceCommandParser.hasFullName(name)) v += 2;
      if (d.direction != null) v += 1;
      return v;
    }

    var best = primary;
    var bestScore = score(primary);
    for (final candidate in alternatives) {
      final candidateScore = score(candidate);
      if (candidateScore > bestScore) {
        best = candidate;
        bestScore = candidateScore;
      }
    }
    return best;
  }

  String _canonicalName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Exact match only (case-, alef- and extra-space-insensitive). A name that is merely CLOSE to a
  /// saved one is NOT silently merged into it — see [_similarAccount], which makes the dialogue
  /// ask "هل تقصد الحساب …؟" instead, so two different people can never be fused by a guess.
  /// The substring pass only fires when the STORED name is itself a full name (2+ words) found
  /// inside the spoken text.
  Account? _matchAccount(String? parsedName, String transcript) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final candidateRaw = (parsedName ?? transcript).trim();
    if (candidateRaw.isEmpty) return null;
    final candidate = _canonicalName(candidateRaw);

    for (final account in accounts) {
      if (_canonicalName(account.name) == candidate) return account;
    }
    for (final account in accounts) {
      final storedName = _canonicalName(account.name);
      final looksLikeFullName = storedName.split(' ').length >= 2;
      if (looksLikeFullName && candidate.contains(storedName)) return account;
    }
    return null;
  }

  /// An existing account whose name is very close to [name] but not identical: the same letters
  /// split differently ("عبد القدوس محمد" vs "عبدالقدوس محمد"), a small spelling difference, or a
  /// missing leading part ("القدوس محمد" vs "عبدالقدوس محمد"). Closest wins; `null` when nothing
  /// is close enough to be worth asking about.
  Account? _similarAccount(String name) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final candidate = _canonicalName(name).replaceAll(' ', '');
    if (candidate.length < 4) return null;
    Account? best;
    var bestDistance = 1 << 30;
    for (final account in accounts) {
      final stored = _canonicalName(account.name).replaceAll(' ', '');
      if (stored.isEmpty) continue;
      if (stored == candidate) {
        // Same letters, different spacing — the closest possible "not exact" case.
        return account;
      }
      final contained = (candidate.length >= 5 && stored.contains(candidate)) ||
          (stored.length >= 5 && candidate.contains(stored));
      final distance = contained ? 1 : _editDistance(candidate, stored);
      final limit = (stored.length * 0.2).floor().clamp(1, 3);
      if (distance <= limit && distance < bestDistance) {
        best = account;
        bestDistance = distance;
      }
    }
    return best;
  }

  int _editDistance(String a, String b) {
    if (a == b) return 0;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final best = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost].reduce((x, y) => x < y ? x : y);
        current[j] = best;
      }
      previous = current;
    }
    return previous[b.length];
  }

  // ───────────────────────── Manual tap fallbacks (kept working) ─────────────────────────

  /// Manual chip-tap fallback (see VoiceCommandSheet's _AccountChoices) — the voice-driven
  /// clarification loop is the primary path now, but tapping still works if recognition fails
  /// repeatedly for a particular name.
  /// A manual tap must win over whatever the voice loop is doing: stop the question being spoken,
  /// the open microphone and any pending silence timer, and invalidate the old session so a late
  /// callback can't act on a question that was just answered by hand.
  void _interruptForManualChoice() {
    ++_session;
    _clearSpeechEndTimer();
    unawaited(_voiceOutput.stop());
    unawaited(_engine.cancel());
  }

  void selectAccount(Account account) {
    final draft = state.draft;
    if (draft == null) return;
    _interruptForManualChoice();
    _nameDecided = true;
    final updated = draft.copyWith(accountName: account.name);
    state = state.copyWith(
      draft: updated,
      account: account,
      clearError: true,
      clearClarifyingField: true,
      clearSuggestedAccount: true,
    );
    unawaited(_advanceAfterParsing(draft: updated, account: account));
  }

  void selectDirection(AccountDirection direction) {
    final draft = state.draft;
    if (draft == null) return;
    _interruptForManualChoice();
    final updated = draft.copyWith(direction: direction);
    state = state.copyWith(draft: updated, clearError: true, clearClarifyingField: true);
    unawaited(_advanceAfterParsing(draft: updated, account: state.account));
  }

  /// Tap on the confirmation's save button: stops the question/listening first, then saves.
  Future<void> confirmByTap() async {
    if (state.draft == null) return;
    _interruptForManualChoice();
    await confirm();
  }

  /// Tap answer to "هل تقصد الحساب الموجود …؟": [same] `true` reuses the suggested account,
  /// `false` keeps the spoken name as a brand-new account.
  void answerSameAccount({required bool same}) {
    final draft = state.draft;
    if (draft == null) return;
    _interruptForManualChoice();
    _nameDecided = true;
    final suggested = state.suggestedAccount;
    if (same && suggested != null) {
      final updated = draft.copyWith(accountName: suggested.name);
      state = state.copyWith(
        draft: updated,
        account: suggested,
        clearError: true,
        clearClarifyingField: true,
        clearSuggestedAccount: true,
      );
      unawaited(_advanceAfterParsing(draft: updated, account: suggested));
    } else {
      state = state.copyWith(clearError: true, clearClarifyingField: true, clearSuggestedAccount: true);
      unawaited(_advanceAfterParsing(draft: draft, account: state.account));
    }
  }

  // ───────────────────────────────── Saving ─────────────────────────────────

  /// Saves the confirmed draft. If no existing account was matched, a brand-new [Account] is
  /// created FIRST, using exactly the full name the person spoke (already guaranteed to be 2+
  /// words by [_advanceAfterParsing]'s check before confirmation was ever reached) — the
  /// transaction is then attached to that new account, never a mismatched or placeholder one.
  ///
  /// DISCLOSED SIMPLIFICATION: a voice command never states whether the person is a "عميل" or
  /// "مورد" — a newly-created account defaults to [AccountCategory.client], the same default the
  /// manual Add Account form starts on. The person can reclassify it afterwards from that
  /// account's own edit screen if it should actually be a supplier.
  Future<void> confirm() async {
    final draft = state.draft;
    var account = state.account;
    if (draft == null || draft.amount == null || draft.direction == null) return;
    final accountName = account?.name ?? draft.accountName;
    if (accountName == null) return;

    state = state.copyWith(status: VoiceStatus.saving);

    if (account == null) {
      account = Account(
        id: _uuid.v4(),
        name: accountName,
        category: AccountCategory.client,
        createdDate: draft.date,
      );
      await _ref.read(accountsProvider.notifier).addAccount(account);
      state = state.copyWith(account: account);
    }

    final id = _uuid.v4();
    final duration = await _recordingDurationMs(state.recordingPath) ??
        (state.recordingStartedAt == null
            ? state.elapsedBeforePause.inMilliseconds
            : (state.elapsedBeforePause + DateTime.now().difference(state.recordingStartedAt!)).inMilliseconds);
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
        ));
    // Mic stops here — state becomes `success` and nothing auto-starts listening again, matching
    // "ثم يتوقف الميكروفون عن التشغيل" from the spec. [startAnother] is the only way back in.
    state = state.copyWith(status: VoiceStatus.success);
    await _speak(_successSpeech(_ref.read(voiceRecognitionLanguageProvider)));
  }

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
    ++_session;
    _networkRetryCount = 0;
    _clearSpeechEndTimer();
    _bluetoothMonitor?.cancel();
    await _voiceOutput.stop();
    try {
      await _engine.cancel();
    } catch (_) {
      // Cancellation must always return the interface to idle, even if a platform recognizer
      // has already disposed its native session.
    }
    await _deleteRecording(state.recordingPath);
    state = const VoiceState();
  }

  Future<int?> _recordingDurationMs(String? path) async {
    if (path == null) return null;
    try {
      final length = await File(path).length();
      if (length < 44) return null;
      // PCM16 mono at 16 kHz: 32,000 bytes per second, excluding the WAV header.
      return ((length - 44) * 1000 / 32000).round();
    } on FileSystemException {
      return null;
    }
  }

  @override
  void dispose() {
    _clearSpeechEndTimer();
    _bluetoothMonitor?.cancel();
    _partialSubscription?.cancel();
    _finalSubscription?.cancel();
    _errorSubscription?.cancel();
    unawaited(_engine.cancel());
    super.dispose();
  }
}
