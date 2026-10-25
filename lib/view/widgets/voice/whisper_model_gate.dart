import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/voice/whisper_model_provider.dart';

/// Blocks the voice screen's content until a local (Whisper) speech model is on the device.
///
/// First run: asks which model to download (they are 190–540 MB, so nothing is downloaded without
/// the person choosing), then shows real byte-level progress. Every later run resolves instantly
/// from the files already on disk. A failure shows its details and a retry that RESUMES the
/// download.
class WhisperModelGate extends ConsumerWidget {
  const WhisperModelGate({required this.child, super.key});
  final Widget child;

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final state = ref.watch(whisperModelControllerProvider);

    return switch (state) {
      WhisperModelReady() => child,
      WhisperModelChecking() => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: shell.accent)),
        ),
      WhisperModelNeedsChoice() => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.whisperPickTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.whisperPickBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
              const SizedBox(height: 16),
              _OptionCard(
                title: l10n.whisperOptionFastTitle,
                subtitle: l10n.whisperOptionFastSubtitle,
                onTap: () => ref.read(whisperModelControllerProvider.notifier).choose(WhisperModelOption.fast),
              ),
              const SizedBox(height: 10),
              _OptionCard(
                title: l10n.whisperOptionBalancedTitle,
                subtitle: l10n.whisperOptionBalancedSubtitle,
                highlighted: true,
                onTap: () => ref.read(whisperModelControllerProvider.notifier).choose(WhisperModelOption.balanced),
              ),
              const SizedBox(height: 10),
              _OptionCard(
                title: l10n.whisperOptionAccurateTitle,
                subtitle: l10n.whisperOptionAccurateSubtitle,
                onTap: () => ref.read(whisperModelControllerProvider.notifier).choose(WhisperModelOption.accurate),
              ),
            ],
          ),
        ),
      WhisperModelDownloading(:final downloadedBytes, :final totalBytes) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalBytes != null && totalBytes > 0) ...[
                LinearProgressIndicator(
                  value: (downloadedBytes / totalBytes).clamp(0.0, 1.0),
                  color: shell.accent,
                  backgroundColor: shell.border,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Text(
                  '${((downloadedBytes / totalBytes) * 100).clamp(0, 100).toStringAsFixed(0)}% '
                  '(${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)})',
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                CircularProgressIndicator(color: shell.accent),
                const SizedBox(height: 10),
                Text(
                  _formatBytes(downloadedBytes),
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                l10n.whisperDownloadingHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
            ],
          ),
        ),
      WhisperModelFailed(:final message) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: shell.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(
                l10n.voiceModelDownloadFailedMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
              const SizedBox(height: 10),
              // Selectable and scrollable: the person can copy the whole technical message to
              // report it exactly.
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: shell.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: shell.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.read(whisperModelControllerProvider.notifier).retry(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.voiceRetry),
              ),
            ],
          ),
        ),
    };
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.title, required this.subtitle, required this.onTap, this.highlighted = false});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Material(
      color: shell.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: highlighted ? shell.accent : shell.border, width: highlighted ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.download_rounded, color: shell.accent),
            ],
          ),
        ),
      ),
    );
  }
}
