import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/voice/bluetooth_audio_route_service.dart';
import '../../core/voice/offline_speech_engine.dart';
import '../../core/voice/vosk_model_provider.dart';
import '../../core/voice/voice_output_service.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
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
  final Account? account;
  final String? recordingPath;
  final DateTime? recordingStartedAt;
  final Duration elapsedBeforePause;
  final String? errorCode;
  final bool bluetoothMode;

  /// Which single field a `listening`/`bluetoothListeningCommand` session is currently gathering
  /// a spoken ANSWER for — `'amount'`, `'account'`, `'direction'`, or `null` when this is an
  /// ordinary fresh command (not a follow-up clarification). This is what lets
  /// [VoiceController._onFinal] tell "the person just spoke a whole new command" apart from "the
  /// person just answered the one specific question I asked them a moment ago" — the two need
  /// completely different handling (re-parse everything vs. merge one field into the existing
  /// draft) even though both arrive through the exact same `listening` status.
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
    _partialSubscription = _engine.partialResults.listen(_onPartial);
    _finalSubscription = _engine.finalResults.listen(_onFinal);
  }

  static const wakeWord = 'ديوني';
  final Ref _ref;
  OfflineSpeechEngine get _engine => _ref.read(offlineSpeechEngineProvider);
  VoiceOutputService get _voiceOutput => _ref.read(voiceOutputServiceProvider);
  late final StreamSubscription<String> _partialSubscription;
  late final StreamSubscription<String> _finalSubscription;
  Timer? _bluetoothMonitor;
  final _uuid = const Uuid();

  // ─────────────────────────── Phrase builders (all spoken aloud) ───────────────────────────

  String _confirmationSpeech(VoiceCommandDraft draft, Account account, String languageCode, {bool editApplied = false}) {
    final amountText = draft.amount!.toStringAsFixed(0);
    if (languageCode == 'en') {
      final prefix = editApplied ? 'Updated. ' : '';
      final directionWord = draft.direction == AccountDirection.debit ? 'as a debit for' : 'as a credit for';
      final details = draft.details != null ? ', details ${draft.details}' : '';
      return "${prefix}I'll add $amountText ${draft.currency} $directionWord ${account.name}$details. Should I save it?";
    }
    final prefix = editApplied ? 'تم التعديل. ' : '';
    final directionWord = draft.direction == AccountDirection.debit ? 'على' : 'لـ';
    final details = draft.details != null ? '، التفاصيل ${draft.details}' : '';
    return '$prefixسأضيف $directionWord ${account.name} مبلغ $amountText ${draft.currency}$details. هل تريد الحفظ؟';
  }

  String _clarificationSpeech(String field, String languageCode) {
    if (languageCode == 'en') {
      return switch (field) {
        'amount' => "I couldn't understand the amount. Please say the amount clearly.",
        'account' => "I couldn't match an account. Please say the account name clearly.",
        'direction' => 'Is this credit or debit? Please say credit or debit.',
        _ => "I didn't hear anything. Please try speaking clearly.",
      };
    }
    return switch (field) {
      'amount' => 'لم أتعرف على المبلغ. من فضلك قل المبلغ بوضوح.',
      'account' => 'لم أتعرف على اسم الحساب. من فضلك قل اسم الحساب بوضوح.',
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
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
    }
  }

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

  // ───────────────────────── Recognition result routing ─────────────────────────

  void _onPartial(String text) {
    if (state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.bluetoothListeningCommand ||
        state.status == VoiceStatus.confirmationListening) {
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

  /// The instant the person stops talking and the engine settles on a final transcript, this
  /// fires and moves the dialogue forward immediately — no button, no delay beyond the analysis
  /// itself, matching "بمجرد أن ينتهي المستخدم من التحدث يرد مباشرة".
  void _onFinal(String text) {
    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand) {
      state = state.copyWith(transcript: text);
      if (state.clarifyingField != null) {
        unawaited(_finishClarificationListening());
      } else {
        unawaited(_finishListening());
      }
      return;
    }
    if (state.status == VoiceStatus.confirmationListening) {
      state = state.copyWith(transcript: text);
      unawaited(_engine.stop());
      unawaited(_handleVoiceConfirmation(text));
    }
  }

  Future<void> stopAndAnalyze() async {
    if (state.status != VoiceStatus.listening && state.status != VoiceStatus.bluetoothListeningCommand) return;
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
    final current = state;
    state = state.copyWith(status: VoiceStatus.processing);

    final (engineTranscript, recordingPath) = await _engine.stop();
    final effectiveTranscript = current.transcript.trim().isNotEmpty ? current.transcript : engineTranscript;

    if (effectiveTranscript.trim().isEmpty) {
      state = state.copyWith(
        status: VoiceStatus.needsClarification,
        errorCode: 'noSpeech',
        recordingPath: recordingPath ?? current.recordingPath,
      );
      await _speak(_clarificationSpeech('noSpeech', _ref.read(voiceRecognitionLanguageProvider)));
      state = state.copyWith(
        status: current.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
        transcript: '',
        clearError: true,
      );
      try {
        await _engine.start();
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
    final current = state;
    final field = current.clarifyingField;
    final draft = current.draft;
    state = state.copyWith(status: VoiceStatus.processing);
    final (engineTranscript, recordingPath) = await _engine.stop();
    final effective = current.transcript.trim().isNotEmpty ? current.transcript : engineTranscript;

    if (draft == null || field == null) {
      state = state.copyWith(status: VoiceStatus.idle);
      return;
    }

    if (effective.trim().isEmpty) {
      state = state.copyWith(recordingPath: recordingPath ?? current.recordingPath);
      await _speak(_clarificationSpeech('noSpeech', _ref.read(voiceRecognitionLanguageProvider)));
      state = state.copyWith(
        status: current.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
        transcript: '',
        clearError: true,
      );
      try {
        await _engine.start();
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
        final matched = _matchAccount(effective, effective);
        if (matched != null) updatedAccount = matched;
      case 'direction':
        final lower = effective.toLowerCase();
        if (['عليه', 'على', 'مدين', 'debit'].any(lower.contains)) {
          updatedDraft = draft.copyWith(direction: AccountDirection.debit);
        } else if (['له', 'دائن', 'credit'].any(lower.contains)) {
          updatedDraft = draft.copyWith(direction: AccountDirection.credit);
        }
    }

    state = state.copyWith(
      draft: updatedDraft,
      account: updatedAccount,
      clearAccount: updatedAccount == null,
      recordingPath: recordingPath ?? current.recordingPath,
      clearClarifyingField: true,
    );
    await _advanceAfterParsing(draft: updatedDraft, account: updatedAccount);
  }

  /// Amount → account → direction, in that order — an account can't be matched without at least
  /// trying, and asking "له أم عليه؟" before we even know WHO the money is for/from would be a
  /// confusing question to lead with. Every branch now SPEAKS its question (or the confirmation
  /// summary) and then immediately starts listening again on its own — the person never has to
  /// touch anything to move the dialogue forward.
  Future<void> _advanceAfterParsing({required VoiceCommandDraft draft, required Account? account}) async {
    if (draft.amount == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'amount', clarifyingField: 'amount');
      await _speakThenListenForClarification('amount');
    } else if (account == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'account', clarifyingField: 'account');
      await _speakThenListenForClarification('account');
    } else if (draft.direction == null) {
      state = state.copyWith(status: VoiceStatus.needsClarification, errorCode: 'direction', clarifyingField: 'direction');
      await _speakThenListenForClarification('direction');
    } else {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, clearError: true, clearClarifyingField: true);
      await _speakThenListenForConfirmation();
    }
  }

  Future<void> _speakThenListenForClarification(String field) async {
    await _speak(_clarificationSpeech(field, _ref.read(voiceRecognitionLanguageProvider)));
    state = state.copyWith(
      status: state.bluetoothMode ? VoiceStatus.bluetoothListeningCommand : VoiceStatus.listening,
      clearError: true,
      transcript: '',
      recordingStartedAt: DateTime.now(),
    );
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.error, errorCode: 'permission');
    }
  }

  Future<void> _speakThenListenForConfirmation({bool editApplied = false}) async {
    final draft = state.draft;
    final account = state.account;
    if (draft == null || account == null || draft.amount == null || draft.direction == null) return;
    final languageCode = _ref.read(voiceRecognitionLanguageProvider);
    await _speak(_confirmationSpeech(draft, account, languageCode, editApplied: editApplied));
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _engine.start();
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
      if (matched != null) updatedAccount = matched;
    }
    state = state.copyWith(draft: updatedDraft, account: updatedAccount, clearError: true);
    await _speakThenListenForConfirmation(editApplied: true);
  }

  Future<void> _askWhatToEditThenListen() async {
    await _speak(_askEditSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
    }
  }

  Future<void> _confirmationNotUnderstood() async {
    state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'confirmation');
    await _speak(_notUnderstoodSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    state = state.copyWith(status: VoiceStatus.confirmationListening, clearError: true, transcript: '');
    try {
      await _engine.start();
    } catch (_) {
      state = state.copyWith(status: VoiceStatus.awaitingConfirmation, errorCode: 'permission');
    }
  }

  Future<void> _cancelWithSpeech() async {
    await _speak(_cancelledSpeech(_ref.read(voiceRecognitionLanguageProvider)));
    state = const VoiceState();
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

  Account? _matchAccount(String? parsedName, String transcript) {
    final accounts = _ref.read(accountsProvider).value ?? const <Account>[];
    final candidate = (parsedName ?? transcript).toLowerCase();
    for (final account in accounts) {
      if (candidate.contains(account.name.toLowerCase())) return account;
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
    state = state.copyWith(account: account, clearError: true, clearClarifyingField: true);
    unawaited(_advanceAfterParsing(draft: draft, account: account));
  }

  void selectDirection(AccountDirection direction) {
    final draft = state.draft;
    if (draft == null) return;
    final updated = draft.copyWith(direction: direction);
    state = state.copyWith(draft: updated, clearError: true, clearClarifyingField: true);
    unawaited(_advanceAfterParsing(draft: updated, account: state.account));
  }

  // ───────────────────────────────── Saving ─────────────────────────────────

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
