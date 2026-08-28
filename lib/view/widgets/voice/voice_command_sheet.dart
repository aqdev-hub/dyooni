import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/voice/voice_provider.dart';
import '../shared/direction_choice.dart';

/// Statuses rendered as "the mic circle + a headline/subtitle pair" (reference states 1–4, plus
/// the Bluetooth handshake steps until their own dedicated treatment lands). Every other status
/// swaps the circle out for a dedicated icon composition (processing/clarification/confirmation/
/// saving/success/error) — never both at once, matching the reference exactly.
bool _isMicFamily(VoiceStatus status) => const {
      VoiceStatus.idle,
      VoiceStatus.preparing,
      VoiceStatus.listening,
      VoiceStatus.paused,
      VoiceStatus.bluetoothConnecting,
      VoiceStatus.bluetoothConnected,
      VoiceStatus.bluetoothWaitingWakeWord,
      VoiceStatus.bluetoothWakeWordDetected,
      VoiceStatus.bluetoothListeningCommand,
    }.contains(status);

bool _showsTimer(VoiceStatus status) => const {
      VoiceStatus.idle,
      VoiceStatus.listening,
      VoiceStatus.paused,
      VoiceStatus.bluetoothListeningCommand,
    }.contains(status);

/// Resolves what tapping the mic circle should do for the CURRENT status — exhaustive over every
/// [VoiceStatus] so an in-between state (e.g. mid Bluetooth handshake) can never fall through to
/// the wrong action. Idle dispatches by entry mode (see VoiceController.setEntryMode); listening
/// states stop-and-analyze; every other status (preparing/processing/saving/paused/the Bluetooth
/// handshake steps/etc.) ignores taps — paused resumes via its own dedicated button, not the
/// circle, matching the reference (the circle shows a static pause glyph there, not a tappable
/// affordance).
VoidCallback? _resolveMicTap(VoiceState state, VoiceController controller) {
  return switch (state.status) {
    VoiceStatus.idle => state.bluetoothMode ? controller.startBluetoothMode : controller.startShortPress,
    VoiceStatus.listening || VoiceStatus.bluetoothListeningCommand => controller.stopAndAnalyze,
    _ => null,
  };
}

/// Whether the recognizer is actively engaged right now — used to disable the recognition
/// language toggle mid-session (switching languages mid-sentence wouldn't apply until the next
/// recording anyway, which would be confusing to allow).
bool _recognizerBusy(VoiceStatus status) => const {
      VoiceStatus.preparing,
      VoiceStatus.listening,
      VoiceStatus.paused,
      VoiceStatus.confirmationListening,
      VoiceStatus.saving,
      VoiceStatus.bluetoothConnecting,
      VoiceStatus.bluetoothConnected,
      VoiceStatus.bluetoothWaitingWakeWord,
      VoiceStatus.bluetoothWakeWordDetected,
      VoiceStatus.bluetoothListeningCommand,
    }.contains(status);

/// Maps an error status + code to the right localized message. `errorCode` is checked first (not
/// just the status) because both VoiceStatus.error and VoiceStatus.bluetoothDisconnected can now
/// carry any of these codes — see VoiceController._onSpeechError.
String _voiceErrorMessage(AppLocalizations l10n, String? code) => switch (code) {
      'connection' => l10n.voiceBluetoothDisconnected,
      'permission' => l10n.voiceNoSpeechPermission,
      'network' => l10n.voiceNetworkError,
      _ => l10n.voiceRecognitionError,
    };

class VoiceCommandSheet extends ConsumerWidget {
  const VoiceCommandSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final state = ref.watch(voiceProvider);
    final controller = ref.read(voiceProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMicFamily(state.status)) ...[
            if (state.status == VoiceStatus.idle) ...[
              const _IdleDecoration(),
              const SizedBox(height: 10),
            ],
            _MicHeadline(state: state),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _resolveMicTap(state, controller),
              child: _MicCircle(status: state.status),
            ),
            const SizedBox(height: 12),
            if (_showsTimer(state.status)) _RecordingTimer(state: state),
            if (state.transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TranscriptCard(text: state.transcript),
            ],
          ] else if (state.status == VoiceStatus.processing) ...[
            _WorkingIndicator(icon: Icons.psychology_alt_outlined, label: l10n.voiceProcessing),
          ] else if (state.status == VoiceStatus.saving) ...[
            _WorkingIndicator(icon: Icons.cloud_upload_outlined, label: l10n.voiceSavingHint),
          ] else if (state.status == VoiceStatus.needsClarification) ...[
            _ClarificationCard(state: state, controller: controller),
          ] else if (state.status == VoiceStatus.awaitingConfirmation || state.status == VoiceStatus.confirmationListening) ...[
            _ConfirmationCard(state: state, controller: controller),
          ] else if (state.status == VoiceStatus.success) ...[
            _SuccessCard(state: state, controller: controller),
          ] else if (state.status == VoiceStatus.error || state.status == VoiceStatus.bluetoothDisconnected) ...[
            _ErrorCard(state: state, controller: controller),
          ],
          const SizedBox(height: 22),
          _BottomToolbar(state: state, controller: controller),
        ],
      ),
    );
  }
}

/// Small decorative mic + sound-wave glyph shown ONLY above the idle prompt (reference state 1) —
/// purely cosmetic, matching the reference's top flourish.
class _IdleDecoration extends StatelessWidget {
  const _IdleDecoration();

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 16, color: shell.accent.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Icon(Icons.mic_none_rounded, size: 20, color: shell.accent),
        const SizedBox(width: 6),
        Icon(Icons.graphic_eq_rounded, size: 16, color: shell.accent.withValues(alpha: 0.6)),
      ],
    );
  }
}

/// Bold headline + gray subtitle pair for the mic-family states — text varies by exactly which
/// moment we're in (fresh idle / first recording / resumed recording / paused), matching the
/// reference's distinct copy for each rather than one generic "listening…" label throughout.
class _MicHeadline extends StatelessWidget {
  const _MicHeadline({required this.state});
  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final (String title, String subtitle) = switch (state.status) {
      VoiceStatus.idle => (l10n.voiceStartListening, l10n.voiceIdleSubtitle),
      VoiceStatus.preparing => (l10n.voicePreparing, l10n.voiceIdleSubtitle),
      VoiceStatus.paused => (l10n.voicePausedTitle, l10n.voicePausedHint),
      VoiceStatus.listening => state.elapsedBeforePause > Duration.zero
          ? (l10n.voiceRecordingResumedTitle, l10n.voiceContinueSpeakingHint)
          : (l10n.voiceRecordingTitle, l10n.voiceShortPressHint),
      VoiceStatus.bluetoothConnecting => (l10n.voiceBluetoothConnecting, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothConnected => (l10n.voiceBluetoothConnected, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothWaitingWakeWord => (l10n.voiceBluetoothWaitingWakeWord, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothWakeWordDetected => (l10n.voiceBluetoothWakeWordDetected, l10n.voiceIdleSubtitle),
      VoiceStatus.bluetoothListeningCommand => (l10n.voiceListening, l10n.voiceBluetoothListeningCommand),
      _ => (l10n.voiceStartListening, l10n.voiceIdleSubtitle),
    };
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 18)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
      ],
    );
  }
}

/// The one big circle, colored by exactly what's happening: navy at rest, red while actively
/// recording, orange while paused — matching the reference's three distinct fills (a fourth,
/// neutral "working" composition is used for processing/saving instead of this circle at all,
/// see [_WorkingIndicator]).
class _MicCircle extends StatelessWidget {
  const _MicCircle({required this.status});
  final VoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final isRecording = status == VoiceStatus.listening || status == VoiceStatus.bluetoothListeningCommand;
    final isPaused = status == VoiceStatus.paused;
    final fill = isRecording ? AppColors.voiceListening : (isPaused ? AppColors.voicePaused : AppColors.voiceIdle);
    final icon = isRecording ? Icons.stop_rounded : (isPaused ? Icons.pause_rounded : Icons.mic_rounded);
    final isBusy = status == VoiceStatus.preparing ||
        status == VoiceStatus.bluetoothConnecting ||
        status == VoiceStatus.bluetoothConnected ||
        status == VoiceStatus.bluetoothWaitingWakeWord ||
        status == VoiceStatus.bluetoothWakeWordDetected;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 122,
          height: 122,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            boxShadow: [BoxShadow(color: fill.withValues(alpha: isRecording ? .35 : .18), blurRadius: 20, spreadRadius: 4)],
          ),
          alignment: Alignment.center,
          child: isBusy
              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
              : Icon(icon, size: 50, color: Colors.white),
        ),
        if (isRecording) ...[
          const SizedBox(height: 10),
          _Waveform(color: fill),
        ],
        if (status == VoiceStatus.idle || status == VoiceStatus.preparing) ...[
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.voiceLongPressHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

/// A row of small bars under the circle while actively recording, echoing the reference's
/// waveform strip. Purely decorative (fixed heights, not driven by real audio amplitude — doing
/// that honestly would need a live amplitude stream the current recorder doesn't expose).
class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});
  final Color color;

  static const _heights = [6.0, 12.0, 18.0, 10.0, 16.0, 8.0, 14.0, 20.0, 9.0, 15.0, 7.0, 13.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in _heights)
            Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

/// Continuously-ticking mm:ss display. Ticks only while actually recording (listening); freezes
/// at whatever value was reached the instant a pause happens, by construction of how
/// [VoiceState.elapsedBeforePause] + `recordingStartedAt` combine (see VoiceController.
/// pauseRecording/resumeRecording).
class _RecordingTimer extends StatefulWidget {
  const _RecordingTimer({required this.state});
  final VoiceState state;

  @override
  State<_RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<_RecordingTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _RecordingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  bool get _isRunning => widget.state.status == VoiceStatus.listening || widget.state.status == VoiceStatus.bluetoothListeningCommand;

  void _syncTicker() {
    if (_isRunning && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_isRunning && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final startedAt = widget.state.recordingStartedAt;
    final liveElapsed = _isRunning && startedAt != null ? DateTime.now().difference(startedAt) : Duration.zero;
    final total = widget.state.elapsedBeforePause + liveElapsed;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: shell.textSecondary),
        const SizedBox(width: 4),
        Text('$minutes:$seconds', style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// The "something is happening in the background" moments (transcribing+understanding, saving) —
/// a neutral ring + a gold icon, deliberately NOT the mic circle, matching the reference's
/// distinct visual language for "working" versus "recording".
///
/// Disclosed simplification: the reference mocks show transcription and understanding as two
/// separate sequential cards. In this app both happen synchronously in one parser call with no
/// real time gap between them — showing two timed screens back to back would mean inventing an
/// artificial delay purely for show, which is exactly the kind of "make it look like it's working
/// harder than it is" shortcut this project explicitly rules out. They're combined into one
/// honest "processing" moment instead.
class _WorkingIndicator extends StatelessWidget {
  const _WorkingIndicator({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.voiceProcessing)),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, color: shell.surface),
                child: Icon(icon, size: 34, color: AppColors.voiceProcessing),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(label, textAlign: TextAlign.center, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: shell.background, border: Border.all(color: shell.border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.voiceTranscriptLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
        const SizedBox(height: 4),
        Text(text, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
      ],),
    );
  }
}

/// Reference state 7 — a question-mark badge, the clarification question, and (for account/
/// direction ambiguity) the actual choices to resolve it, all inside one bordered card.
class _ClarificationCard extends StatelessWidget {
  const _ClarificationCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final message = switch (state.errorCode) {
      'amount' => l10n.voiceNeedAmount,
      'direction' => l10n.voiceNeedDirection,
      _ => l10n.voiceNeedAccount,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: shell.surface, border: Border.all(color: shell.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.voiceProcessing.withValues(alpha: 0.14)),
            child: const Icon(Icons.help_outline_rounded, color: AppColors.voiceProcessing, size: 28),
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
          if (state.errorCode == 'account') ...[
            const SizedBox(height: 10),
            _AccountChoices(onSelected: controller.selectAccount),
          ],
          if (state.errorCode == 'direction') ...[
            const SizedBox(height: 10),
            _DirectionChoices(onSelected: controller.selectDirection),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: controller.retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.voiceRetry)),
        ],
      ),
    );
  }
}

class _AccountChoices extends ConsumerWidget {
  const _AccountChoices({required this.onSelected});
  final ValueChanged<Account> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: [
      for (final account in accounts) ActionChip(label: Text(account.name), onPressed: () => onSelected(account)),
    ]);
  }
}

/// Reuses the same ring-toggle used on Add Transaction/Add Account so this doesn't introduce a
/// third visual style for the same له/عليه choice.
class _DirectionChoices extends StatelessWidget {
  const _DirectionChoices({required this.onSelected});
  final ValueChanged<AccountDirection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DirectionChoice(label: l10n.directionCredit, color: AppColors.credit, selected: false, onTap: () => onSelected(AccountDirection.credit)),
        const SizedBox(width: 24),
        DirectionChoice(label: l10n.directionDebit, color: AppColors.debit, selected: false, onTap: () => onSelected(AccountDirection.debit)),
      ],
    );
  }
}

/// Reference state 8 — a warm gold-tinted card listing what was understood in the exact field
/// order shown there (name, amount, type, details, date), then the yes/edit actions plus an
/// optional voice-confirmation mic.
class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final draft = state.draft!;
    // Safe by construction: this card only renders in awaitingConfirmation/confirmationListening,
    // and the controller never reaches either status while draft.direction is still null (see
    // VoiceController._advanceAfterParsing / selectDirection).
    final direction = draft.direction! == AccountDirection.credit ? l10n.directionCredit : l10n.directionDebit;
    final isListeningForConfirmation = state.status == VoiceStatus.confirmationListening;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text(l10n.voiceConfirmTitle, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _Line(l10n.voiceAccountLabel, state.account!.name),
            _Line(l10n.amountLabel, '${draft.amount!.toStringAsFixed(0)} ${draft.currency}'),
            _Line(l10n.voiceDirectionLabel, direction),
            if (draft.details != null) _Line(l10n.detailsLabel, draft.details!),
            _Line(l10n.dateLabel, '${draft.date.year}-${draft.date.month.toString().padLeft(2, '0')}-${draft.date.day.toString().padLeft(2, '0')}'),
            const SizedBox(height: 8),
            Text(l10n.voiceConfirmQuestion, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
          isListeningForConfirmation
              ? l10n.voiceConfirmationListening
              : state.errorCode == 'confirmation'
                  ? l10n.voiceConfirmationNotUnderstood
                  : l10n.voiceConfirmationHint,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(l10n.voiceEdit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: isListeningForConfirmation ? null : controller.confirm,
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: shell.headerBottom),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.voiceConfirm),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: isListeningForConfirmation ? null : controller.startVoiceConfirmation,
          icon: Icon(Icons.mic_rounded, color: shell.accent),
          tooltip: l10n.voiceConfirmationHint,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('$label: ', style: AppTextStyles.bodySecondary(context)),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: AppTextStyles.bodySecondary(context).copyWith(fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Reference state 10 — green checkmark, then the SHORT-PRESS-ONLY "start another recording"
/// action. Bluetooth mode deliberately keeps its own different framing here (continuing to
/// listen for the wake word is genuinely correct for hands-free use) — see
/// VoiceController.startAnother's doc comment for why the two modes diverge on purpose.
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
        const SizedBox(height: 10),
        Text(l10n.voiceSaved, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (state.bluetoothMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(l10n.voiceBluetoothWaitingWakeWord, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary)),
          )
        else
          FilledButton.icon(
            onPressed: controller.startAnother,
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: Text(l10n.voiceRecordAnother),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(_voiceErrorMessage(l10n, state.errorCode), textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: controller.retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.voiceBluetoothRetry)),
      ],
    );
  }
}

/// The fixed bottom pair shown in every state of the reference: the recognition-language toggle
/// on one side, and the pause/resume control on the other (idle-styled and disabled whenever
/// there's nothing to pause or resume).
class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RecognitionLanguageButton(disabled: _recognizerBusy(state.status)),
        _PauseResumeButton(state: state, controller: controller),
      ],
    );
  }
}

/// Toggles which language the RECOGNIZER listens for — independent of the app's display
/// language. Shows the currently-active recognition language; tapping switches to the other one.
class _RecognitionLanguageButton extends ConsumerWidget {
  const _RecognitionLanguageButton({required this.disabled});
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final language = ref.watch(voiceRecognitionLanguageProvider);
    final isArabic = language == 'ar';

    return OutlinedButton.icon(
      onPressed: disabled
          ? null
          : () => ref.read(voiceRecognitionLanguageProvider.notifier).state = isArabic ? 'en' : 'ar',
      style: OutlinedButton.styleFrom(foregroundColor: shell.textPrimary, side: BorderSide(color: shell.border)),
      icon: const Icon(Icons.language_rounded, size: 16),
      label: Text(isArabic ? l10n.voiceLanguageArabic : l10n.voiceLanguageEnglish),
    );
  }
}

/// The right-hand toolbar button: pauses while actively recording, resumes while paused, and is
/// simply disabled (showing the idle "مؤقت التسجيل" label) at every other moment — there being
/// nothing to pause or resume outside those two statuses.
class _PauseResumeButton extends StatelessWidget {
  const _PauseResumeButton({required this.state, required this.controller});
  final VoiceState state;
  final VoiceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final isRecording = state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand;
    final isPaused = state.status == VoiceStatus.paused;

    final (IconData icon, String label, VoidCallback? onTap) = switch (true) {
      _ when isRecording => (Icons.pause_rounded, l10n.voicePauseAction, controller.pauseRecording),
      _ when isPaused => (Icons.play_arrow_rounded, l10n.voiceResumeAction, controller.resumeRecording),
      _ => (Icons.schedule_rounded, l10n.voiceRecordingTimerIdleLabel, null),
    };

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: shell.textPrimary, side: BorderSide(color: shell.border)),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
