import 'dart:async';
import 'dart:io';

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
      );
}

/// The result of trying to interpret something said DURING confirmation as an EDIT instruction
/// (e.g. "عدّل المبلغ إلى 3500") rather than a plain yes/no/cancel reply. [accountNameHint] is
/// kept separate from [draft] because re-matching a spoken account name against the real account
/// list needs [VoiceController._matchAccount], which this pure parsing step has no access to.
class _VoiceEditResult {
  const _VoiceEditResult({this.draft, this.accountNameHint});
  final VoiceCommandDraft? draft;
  final String? accountNameHint;
  bool get isEmpty => draft == null && accountNameHint == null;
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
  Timer? _bluetoothMonitor;
  Timer? _speechSilenceTimer;
  final _uuid = const Uuid();
  int _session = 0;

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
    _engine = _ref.read(speechEngineProvider);
    _partialSubscription = _engine.partialResults.listen(_onPartial);
    _finalSubscription = _engine.finalResults.listen(_onFinal);
  }

  /// Provider changes are intentionally limited to idle state. This releases the old engine
  /// before rebinding streams, so a single utterance can never be split between recognizers.
  Future<void> setRecognitionMode(VoiceRecognitionMode mode) async {
    if (state.status != VoiceStatus.idle) return;
    final current = _ref.read(generalSettingsProvider).value?.voiceRecognitionMode ?? VoiceRecognitionMode.local;
    if (current == mode) return;
    await _ref.read(generalSettingsProvider.notifier).setVoiceRecognitionMode(mode);
    _bindEngine();
  }

  // ─────────────────────────── Phrase builders (all spoken aloud) ───────────────────────────

  /// [accountName] is a plain string rather than an [Account] — by the time this is spoken,
  /// there may not be a real matched account yet at all (see [VoiceState.account]'s doc comment
  /// on what a `null` match means once confirmation is reached: a new account will be created).
  String _confirmationSpeech(VoiceCommandDraft draft, String accountName, String languageCode, {bool editApplied = false}) {
    final amountText = draft.amount!.toStringAsFixed(0);
    if (languageCode == 'en') {
      final prefix = editApplied ? 'Updated. ' : '';
      final directionWord = draft.direction == AccountDirection.debit ? 'as a debit for' : 'as a credit for';
      final details = draft.details != null ? ', details ${draft.details}' : '';
      return "${prefix}I'll add $amountText ${draft.currency} $directionWord $accountName$details. Should I save it?";
    }
    final prefix = editApplied ? 'تم التعديل. ' : '';
    final directionWord = draft.direction == AccountDirection.debit ? 'على' : 'لـ';
    final details = draft.details != null ? '، التفاصيل ${draft.details}' : '';
    return '$prefixسأضيف $directionWord $accountName مبلغ $amountText ${draft.currency}$details. هل تريد الحفظ؟';
  }

  String _clarificationSpeech(String field, String languageCode) {
    if (languageCode == 'en') {
      return switch (field) {
        'amount' => "I couldn't understand the amount. Please say the amount clearly.",
        'account' => "I couldn't match an account. Please say the account name clearly.",
        'accountName' =>
          "The account name needs a first and last name. Please say the full account name.",
        'currency' =>
          "That currency isn't supported. Please say a supported one — Yemeni Rial, Saudi Riyal, "
              "US Dollar, Dirham, Pound, or Dinar.",
        'direction' => 'Is this credit or debit? Please say credit or debit.',
        _ => "I didn't hear anything. Please try speaking clearly.",
      };
    }
    return switch (field) {
      'amount' => 'لم أتعرف على المبلغ. من فضلك قل المبلغ بوضوح.',
      'account' => 'لم أتعرف على اسم الحساب. من فضلك قل اسم الحساب بوضوح.',
      'accountName' => 'اسم الحساب يجب أن يتكون من اسمين على الأقل. من فضلك قل الاسم الكامل.',
      'currency' => 'هذه العملة غير مدعومة. من فضلك قل عملة مدعومة، مثل ريال يمني أو سعودي أو دولار أو درهم أو جنيه أو دينار.',
      'direction' => 'لم أفهم هل هذا الدين له أم عليه. من فضلك قل له أو عليه.',
      _ => 'لم ألتقط أي صوت. من فضلك حاول التحدث بوضوح.',
    };
  }

  String _successSpeech(String languageCode) => languageCode == 'en' ? 'Entry saved successfully.' : 'تم حفظ العملية بنجاح.';

  String _notUnderstoodSpeech(String languageCode) =>
      languageCode == 'en' ? "I didn't understand. Say yes to save, or edit to change something." : 'لم أفهم. قل نعم للحفظ، أو عدّل لتغيير شيء.';

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
    final session = ++_session;
    state = VoiceState(status: VoiceStatus.preparing, bluetoothMode: bluetoothMode);
    if (!await _engine.hasPermission()) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      return;
    }
    state = state.copyWith(
      status: bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      recordingStartedAt: DateTime.now(),
      clearError: true,
    );
    try {
      await _engine.start();
      if (session != _session) {
        await _engine.cancel();
        return;
      }
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
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
    state = state.copyWith(status: VoiceStatus.processing);

    final (engineTranscript, recordingPath) = await _engine.stop();
    if (session != _session || state.status != VoiceStatus.processing) {
      await _deleteRecording(recordingPath);
      return;
    }
    final effectiveTranscript = _chooseMoreCompleteTranscript(current.transcript, engineTranscript);

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
        await _engine.start();
        _armSpeechEndTimer(_noSpeechAfter);
      } catch (_) {
        state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      }
      return;
    }

    final draft = _ref.read(voiceCommandParserProvider).parse(effectiveTranscript);
    final account = _matchAccount(draft.accountName, effectiveTranscript);
    state = state.copyWith(
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
    state = state.copyWith(status: VoiceStatus.processing);
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
        await _engine.start();
        _armSpeechEndTimer(_noSpeechAfter);
      } catch (_) {
        state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
      }
      return;
    }

    var updatedDraft = draft;
    var updatedAccount = current.account;
    switch (field) {
      case 'amount':
        final reparsed = _ref.read(voiceCommandParserProvider).parse(effective);
        if (reparsed.amount != null) updatedDraft = draft.copyWith(amount: reparsed.amount);
      case 'account':
        // The person restated the whole account name — try matching it against an existing
        // account first; if none matches, keep the freshly-spoken name as-is (a brand-new
        // account will be created from it once it passes the full-name check below).
        final matched = _matchAccount(effective, effective);
        updatedAccount = matched;
        updatedDraft = draft.copyWith(accountName: matched?.name ?? effective.trim());
      case 'accountName':
        // The person is only adding the missing last name — merge it the same way as 'account'
        // above rather than treating it as a brand-new, unrelated command.
        final matched = _matchAccount(effective, effective);
        updatedAccount = matched;
        updatedDraft = draft.copyWith(accountName: matched?.name ?? effective.trim());
      case 'currency':
        final reparsedCurrency = _ref.read(voiceCommandParserProvider).parse(effective);
        if (!reparsedCurrency.currencyUnsupported) {
          updatedDraft = draft.copyWith(currency: reparsedCurrency.currency, currencyUnsupported: false);
        }
        // If still unsupported, currencyUnsupported stays true on `draft` unchanged, and
        // _advanceAfterParsing below will simply ask again.
      case 'direction':
        final lower = effective.toLowerCase();
        if (['عليه', 'على', 'مدين', 'دين', 'عنده', 'تسلف', 'استلف', 'مديون', 'debit'].any(lower.contains)) {
          updatedDraft = draft.copyWith(direction: AccountDirection.debit);
        } else if (['له', 'دائن', 'سدد', 'سلم', 'سلّم', 'وصل', 'رجع', 'ارجع', 'credit'].any(lower.contains)) {
          updatedDraft = draft.copyWith(direction: AccountDirection.credit);
        }
    }

    state = state.copyWith(
      draft: updatedDraft,
      account: updatedAccount,
      clearAccount: updatedAccount == null,
      recordingPath: current.recordingPath,
      clearClarifyingField: true,
    );
    await _advanceAfterParsing(draft: updatedDraft, account: updatedAccount);
  }

  /// Amount → currency → account name → full-name check → direction, in that order. Every
  /// branch SPEAKS its question (or the confirmation summary) and then immediately starts
  /// listening again on its own — the person never has to touch anything to move the dialogue
  /// forward. Reaching the final `else` no longer requires an EXISTING account match — see
  /// [VoiceState.account]'s doc comment: a `null` match at this point simply means a brand-new
  /// account will be created from [VoiceCommandDraft.accountName] once the person confirms.
  Future<void> _advanceAfterParsing({required VoiceCommandDraft draft, required Account? account}) async {
    final accountName = draft.accountName;
    if (draft.amount == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'amount', clarifyingField: 'amount');
      await _speakThenListenForClarification('amount');
    } else if (draft.currencyUnsupported) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'currency', clarifyingField: 'currency');
      await _speakThenListenForClarification('currency');
    } else if (accountName == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'account', clarifyingField: 'account');
      await _speakThenListenForClarification('account');
    } else if (!VoiceCommandParser.hasFullName(accountName)) {
      // A name was heard, but it's only a single word (e.g. just "عبدالقدوس") — per the same
      // rule the manual Add Account form enforces, an account needs a first AND a last name.
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'accountName', clarifyingField: 'accountName');
      await _speakThenListenForClarification('accountName');
    } else if (draft.direction == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'direction', clarifyingField: 'direction');
      await _speakThenListenForClarification('direction');
    } else {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, clearError: true, clearClarifyingField: true);
      await _speakThenListenForConfirmation();
    }
  }

  Future<void> _speakThenListenForClarification(String field) async {
    final session = _session;
    _clearSpeechEndTimer();
    await _speak(_clarificationSpeech(field, _ref.read(voiceRecognitionLanguageProvider)));
    if (session != _session) return;
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      clearError: true,
      transcript: '',
      // This is a follow-up answer, not the primary recorded command. Keep the original start
      // timestamp so the recording metadata remains associated with the first command.
    );
    try {
      await _engine.start();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
    }
  }

  Future<void> _speakThenListenForConfirmation({bool editApplied = false}) async {
    final session = _session;
    _clearSpeechEndTimer();
    final draft = state.draft;
    final accountName = state.account?.name ?? draft?.accountName;
    if (draft == null || accountName == null || draft.amount == null || draft.direction == null) return;
    final languageCode = _ref.read(voiceRecognitionLanguageProvider);
    await _speak(_confirmationSpeech(draft, accountName, languageCode, editApplied: editApplied));
    if (session != _session) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _engine.start();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
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

    final edit = _tryParseEdit(spoken, draft);
    if (edit != null && !edit.isEmpty) {
      await _applyEditAndReconfirm(edit);
      return;
    }

    final normalized = spoken.toLowerCase().replaceAll('أ', 'ا');
    const yesWords = {'نعم', 'ايوه', 'ايوا', 'صحيح', 'احفظ', 'موافق', 'تمام', 'yes', 'correct', 'save', 'ok'};
    const noWords = {'الغ', 'إلغاء', 'الغاء', 'لا', 'cancel', 'no'};
    const editWords = {'تعديل', 'عدل', 'غير', 'edit', 'change'};

    if (yesWords.any(normalized.contains)) {
      await confirm();
      return;
    }
    if (noWords.any(normalized.contains)) {
      await _cancelWithSpeech();
      return;
    }
    if (editWords.any(normalized.contains)) {
      await _askWhatToEditThenListen();
      return;
    }
    await _confirmationNotUnderstood();
  }

  Future<void> _applyEditAndReconfirm(_VoiceEditResult edit) async {
    final draft = state.draft;
    if (draft == null) return;
    var updatedDraft = edit.draft ?? draft;
    var updatedAccount = state.account;
    if (edit.accountNameHint != null) {
      final matched = _matchAccount(edit.accountNameHint, edit.accountNameHint!);
      updatedAccount = matched;
      updatedDraft = updatedDraft.copyWith(accountName: matched?.name ?? edit.accountNameHint);
    }
    state = state.copyWith(draft: updatedDraft, account: updatedAccount, clearAccount: updatedAccount == null, clearError: true);
    await _speakThenListenForConfirmation(editApplied: true);
  }

  Future<void> _askWhatToEditThenListen() async {
    final session = _session;
    _clearSpeechEndTimer();
    await _speak(_askEditSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    if (session != _session) return;
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _engine.start();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
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
      await _engine.start();
      _armSpeechEndTimer(_noSpeechAfter);
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
    }
  }

  Future<void> _cancelWithSpeech() async {
    await _speak(_cancelledSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    state = const VoiceState();
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

  /// Best-effort natural-language edit parser for the confirmation step. Deliberately
  /// pattern/keyword based rather than a full NLU model — it recognizes the field being
  /// mentioned (المبلغ / التفاصيل / الحساب / النوع) plus a new value near it. Returns `null` (not
  /// an empty result) when [text] doesn't look like an edit at all, so the caller falls through
  /// to yes/no/cancel handling instead of misfiring on an unrelated sentence.
  _VoiceEditResult? _tryParseEdit(String text, VoiceCommandDraft draft) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();

    if (normalized.contains('المبلغ') || normalized.contains('القيمة')) {
      final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(normalized);
      if (amountMatch != null) {
        final newAmount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.'));
        if (newAmount != null) return _VoiceEditResult(draft: draft.copyWith(amount: newAmount));
      }
      // Do not limit editing to digits. The same Arabic number parser used for a new command
      // also understands speech-engine output such as "ثلاثة آلاف".
      final spokenAmount = _ref.read(voiceCommandParserProvider).parse(normalized).amount;
      if (spokenAmount != null) return _VoiceEditResult(draft: draft.copyWith(amount: spokenAmount));
    }

    final detailsMatch = RegExp(r'التفاصيل\s+(?:الى|إلى)?\s*(.+)').firstMatch(normalized);
    if (detailsMatch != null) {
      final newDetails = detailsMatch.group(1)?.trim();
      if (newDetails != null && newDetails.isNotEmpty) {
        return _VoiceEditResult(draft: draft.copyWith(details: newDetails));
      }
    }

    final mentionsDirectionContext =
        normalized.contains('النوع') || normalized.contains('اجعل') || normalized.contains('خلي') || normalized.contains('خله');
    if (mentionsDirectionContext || lower.contains('debit') || lower.contains('credit')) {
      if (normalized.contains('عليه') || lower.contains('debit')) {
        return _VoiceEditResult(draft: draft.copyWith(direction: AccountDirection.debit));
      }
      if (normalized.contains('له') || lower.contains('credit')) {
        return _VoiceEditResult(draft: draft.copyWith(direction: AccountDirection.credit));
      }
    }

    final accountMatch = RegExp(r'الحساب\s+(?:الى|إلى)?\s*(.+)').firstMatch(normalized);
    if (accountMatch != null) {
      final name = accountMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty) return _VoiceEditResult(accountNameHint: name);
    }

    return null;
  }

  /// Tries to match [parsedName] (falling back to the whole [transcript]) against an existing
  /// account. Prefers an EXACT match (trimmed, case-insensitive) first — that's what "the
  /// account already exists" really means, not just a name that happens to share a substring.
  /// Falls back to a substring match only when the STORED name itself looks like a real full
  /// name (2+ words), so a short, generic first name can never accidentally match an unrelated
  /// account and silently add the entry to the wrong person.
  Account? _matchAccount(String? parsedName, String transcript) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final candidateRaw = (parsedName ?? transcript).trim();
    if (candidateRaw.isEmpty) return null;
    final candidate = candidateRaw.toLowerCase();

    for (final account in accounts) {
      if (account.name.trim().toLowerCase() == candidate) return account;
    }
    for (final account in accounts) {
      final storedName = account.name.trim().toLowerCase();
      final looksLikeFullName = storedName.split(RegExp(r'\s+')).length >= 2;
      if (looksLikeFullName && candidate.contains(storedName)) return account;
    }
    return null;
  }

  // ───────────────────────── Manual tap fallbacks (kept working) ─────────────────────────

  /// Manual chip-tap fallback (see VoiceCommandSheet's _AccountChoices) — the voice-driven
  /// clarification loop is the primary path now, but tapping still works if recognition fails
  /// repeatedly for a particular name.
  void selectAccount(Account account) {
    final draft = state.draft;
    if (draft == null) return;
    final updated = draft.copyWith(accountName: account.name);
    state = state.copyWith(draft: updated, account: account, clearError: true, clearClarifyingField: true);
    unawaited(_advanceAfterParsing(draft: updated, account: account));
  }

  void selectDirection(AccountDirection direction) {
    final draft = state.draft;
    if (draft == null) return;
    final updated = draft.copyWith(direction: direction);
    state = state.copyWith(draft: updated, clearError: true, clearClarifyingField: true);
    unawaited(_advanceAfterParsing(draft: updated, account: state.account));
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
    unawaited(_engine.cancel());
    super.dispose();
  }
}
