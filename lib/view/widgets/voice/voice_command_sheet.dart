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

/// Resolves what tapping the mic circle should do for the CURRENT status — exhaustive over every
/// [VoiceStatus] so an in-between state (e.g. mid Bluetooth handshake) can never fall through to
/// the wrong action. Idle dispatches by entry mode (see VoiceController.setEntryMode); listening
/// states stop-and-analyze; every other status (preparing/processing/saving/the Bluetooth
/// handshake steps/etc.) ignores taps entirely rather than accidentally restarting a different
/// flow underneath an in-progress one.
VoidCallback? _resolveMicTap(VoiceState state, VoiceController controller) {
  return switch (state.status) {
    VoiceStatus.idle => state.bluetoothMode ? controller.startBluetoothMode : controller.startShortPress,
    VoiceStatus.listening || VoiceStatus.bluetoothListeningCommand => controller.stopAndAnalyze,
    _ => null,
  };
}

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
    final isActive = state.status == VoiceStatus.listening || state.status == VoiceStatus.bluetoothListeningCommand;
    final isBusy = state.status == VoiceStatus.preparing || state.status == VoiceStatus.processing || state.status == VoiceStatus.saving;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(onPressed: () { controller.cancel(); Navigator.of(context).pop(); }, icon: Icon(Icons.close_rounded, color: shell.textSecondary)),
                Expanded(child: Text(l10n.voiceRecordingTitle, textAlign: TextAlign.center, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            _StatusText(state: state),
            const SizedBox(height: 16),
            Tooltip(
              message: l10n.voiceLongPressHint,
              child: GestureDetector(
                onTap: _resolveMicTap(state, controller),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shell.headerBottom,
                  border: Border.all(color: isActive ? shell.accent : shell.border, width: isActive ? 4 : 2),
                  boxShadow: [BoxShadow(color: shell.accent.withValues(alpha: isActive ? .28 : .12), blurRadius: 18, spreadRadius: 4)],
                ),
                child: Icon(isActive ? Icons.stop_rounded : Icons.mic_rounded, size: 54, color: shell.accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(isActive ? l10n.voiceListening : l10n.voiceShortPressHint, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.voiceUseAppLanguage, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary), textAlign: TextAlign.center),
            if (state.transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TranscriptCard(text: state.transcript),
            ],
            if (state.status == VoiceStatus.needsClarification) ...[
              const SizedBox(height: 14),
              _Clarification(state: state),
              if (state.errorCode == 'account') _AccountChoices(onSelected: controller.selectAccount),
              if (state.errorCode == 'direction') _DirectionChoices(onSelected: controller.selectDirection),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: controller.retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.voiceRetry)),
            ],
            if (state.status == VoiceStatus.awaitingConfirmation || state.status == VoiceStatus.confirmationListening) ...[
              const SizedBox(height: 14),
              _ConfirmationCard(state: state),
              const SizedBox(height: 12),
              Text(
                state.status == VoiceStatus.confirmationListening
                    ? l10n.voiceConfirmationListening
                    : state.errorCode == 'confirmation'
                    ? l10n.voiceConfirmationNotUnderstood
                    : l10n.voiceConfirmationHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: controller.retry, child: Text(l10n.voiceEdit))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.status == VoiceStatus.confirmationListening ? null : controller.confirm,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.voiceConfirm),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: state.status == VoiceStatus.confirmationListening ? null : controller.startVoiceConfirmation,
                icon: Icon(Icons.mic_rounded, color: shell.accent),
                tooltip: l10n.voiceConfirmationHint,
              ),
            ],
            if (state.status == VoiceStatus.success) ...[
              const SizedBox(height: 14),
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 42),
              const SizedBox(height: 6),
              Text(l10n.voiceSaved, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary)),
            ],
            if (state.status == VoiceStatus.error || state.status == VoiceStatus.bluetoothDisconnected) ...[
              const SizedBox(height: 14),
              Text(_voiceErrorMessage(l10n, state.errorCode), textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error)),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: controller.retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.voiceBluetoothRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.state});
  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final text = switch (state.status) {
      VoiceStatus.preparing => l10n.voiceProcessing,
      VoiceStatus.listening => l10n.voiceListening,
      VoiceStatus.processing => l10n.voiceProcessing,
      VoiceStatus.confirmationListening => l10n.voiceConfirmationListening,
      VoiceStatus.bluetoothConnecting => l10n.voiceBluetoothConnecting,
      VoiceStatus.bluetoothConnected => l10n.voiceBluetoothConnected,
      VoiceStatus.bluetoothWaitingWakeWord => l10n.voiceBluetoothWaitingWakeWord,
      VoiceStatus.bluetoothWakeWordDetected => l10n.voiceBluetoothWakeWordDetected,
      VoiceStatus.bluetoothListeningCommand => l10n.voiceBluetoothListeningCommand,
      _ => l10n.voiceStartListening,
    };
    return Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary));
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

class _Clarification extends StatelessWidget {
  const _Clarification({required this.state});
  final VoiceState state;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (state.errorCode) {
      'amount' => l10n.voiceNeedAmount,
      'direction' => l10n.voiceNeedDirection,
      _ => l10n.voiceNeedAccount,
    };
    return Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error));
  }
}

class _AccountChoices extends ConsumerWidget {
  const _AccountChoices({required this.onSelected});
  final ValueChanged<Account> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 4, children: [for (final account in accounts) ActionChip(label: Text(account.name), onPressed: () => onSelected(account))]),
    );
  }
}

/// Shown when the parser understood everything except له/عليه (see VoiceCommandParser.direction's
/// doc comment) — reuses the same [DirectionChoice] ring-toggle already used on Add Transaction
/// and Add Account so this new state never introduces a third visual style for the same choice.
class _DirectionChoices extends StatelessWidget {
  const _DirectionChoices({required this.onSelected});
  final ValueChanged<AccountDirection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DirectionChoice(
            label: l10n.directionCredit,
            color: AppColors.credit,
            selected: false,
            onTap: () => onSelected(AccountDirection.credit),
          ),
          const SizedBox(width: 24),
          DirectionChoice(
            label: l10n.directionDebit,
            color: AppColors.debit,
            selected: false,
            onTap: () => onSelected(AccountDirection.debit),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.state});
  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final draft = state.draft!;
    // Safe by construction: this card only renders in awaitingConfirmation/confirmationListening,
    // and the controller never reaches either status while draft.direction is still null (see
    // VoiceController._advanceAfterParsing / selectDirection).
    final direction = draft.direction! == AccountDirection.credit ? l10n.directionCredit : l10n.directionDebit;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: shell.background, border: Border.all(color: shell.border), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(l10n.voiceConfirmTitle, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _Line(l10n.voiceAccountLabel, state.account!.name),
        _Line(l10n.amountLabel, '${draft.amount!.toStringAsFixed(0)} ${draft.currency}'),
        _Line(l10n.voiceDirectionLabel, direction),
        _Line(l10n.dateLabel, '${draft.date.year}-${draft.date.month.toString().padLeft(2, '0')}-${draft.date.day.toString().padLeft(2, '0')}'),
        if (draft.details != null) _Line(l10n.detailsLabel, draft.details!),
        const SizedBox(height: 6),
        Text(l10n.voiceConfirmQuestion, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
      ],),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Text('$label: ', style: AppTextStyles.bodySecondary(context)), Expanded(child: Text(value, textAlign: TextAlign.end, style: AppTextStyles.bodySecondary(context).copyWith(fontWeight: FontWeight.w700)))]),
      );
}
