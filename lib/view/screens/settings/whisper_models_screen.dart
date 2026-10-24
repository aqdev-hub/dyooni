import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/voice/whisper_model_provider.dart';

/// "نماذج التعرف المحلي" — opened from الإعدادات. At any time the person can download either
/// Whisper model, switch the one in use, or delete a model to free space. The model in use keeps
/// working while another one downloads (see [whisperBackgroundDownloadProvider]).
class WhisperModelsScreen extends ConsumerWidget {
  const WhisperModelsScreen({super.key});

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final state = ref.watch(whisperModelControllerProvider);
    final background = ref.watch(whisperBackgroundDownloadProvider);
    final backgroundError = ref.watch(whisperBackgroundErrorProvider);
    final installed = ref.watch(whisperInstalledProvider).value ?? const <WhisperModelOption, int>{};
    final controller = ref.read(whisperModelControllerProvider.notifier);

    final active = state is WhisperModelReady ? state.files.option : null;
    final downloading = state is WhisperModelDownloading ? state : background;
    final failedMessage = state is WhisperModelFailed ? state.message : backgroundError;

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.whisperModelsTitle,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.whisperModelsHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (failedMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.debit.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.debit.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.voiceModelDownloadFailedMessage,
                            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            failedMessage,
                            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final option in WhisperModelOption.values) ...[
                    _ModelCard(
                      option: option,
                      isActive: active == option,
                      installedBytes: installed[option],
                      progress: downloading?.option == option ? downloading : null,
                      // One download at a time: the others wait for it to end.
                      anotherDownloading: downloading != null && downloading.option != option,
                      onDownload: () => controller.choose(option),
                      onUse: () => controller.switchTo(option),
                      onCancel: controller.cancelDownload,
                      onDelete: () => _confirmDelete(context, controller, option, lastOne: installed.length <= 1),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WhisperModelController controller,
    WhisperModelOption option, {
    required bool lastOne,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final shell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: shell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.whisperModelDeleteTitle, style: AppTextStyles.title(dialogContext).copyWith(color: shell.textPrimary)),
          content: Text(
            lastOne ? '${l10n.whisperModelDeleteBody}\n\n${l10n.whisperModelDeleteLastNote}' : l10n.whisperModelDeleteBody,
            style: AppTextStyles.body(dialogContext).copyWith(color: shell.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.whisperModelDelete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await controller.delete(option);
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.option,
    required this.isActive,
    required this.installedBytes,
    required this.progress,
    required this.anotherDownloading,
    required this.onDownload,
    required this.onUse,
    required this.onCancel,
    required this.onDelete,
  });

  final WhisperModelOption option;
  final bool isActive;
  final int? installedBytes;
  final WhisperModelDownloading? progress;
  final bool anotherDownloading;
  final VoidCallback onDownload;
  final VoidCallback onUse;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final isInstalled = installedBytes != null;
    final title = option == WhisperModelOption.balanced ? l10n.whisperOptionBalancedTitle : l10n.whisperOptionAccurateTitle;
    final subtitle = option == WhisperModelOption.balanced ? l10n.whisperOptionBalancedSubtitle : l10n.whisperOptionAccurateSubtitle;
    final status = isActive
        ? l10n.whisperModelActive
        : isInstalled
            ? '${l10n.whisperModelInstalled} (${WhisperModelsScreen.formatBytes(installedBytes!)})'
            : l10n.whisperModelNotInstalled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? shell.accent : shell.border, width: isActive ? 1.8 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (isActive ? shell.accent : shell.textSecondary).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.bodySecondary(context).copyWith(
                    color: isActive ? shell.accent : shell.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
          const SizedBox(height: 10),
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress!.totalBytes != null && progress!.totalBytes! > 0
                  ? (progress!.downloadedBytes / progress!.totalBytes!).clamp(0.0, 1.0)
                  : null,
              color: shell.accent,
              backgroundColor: shell.border,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              progress!.totalBytes != null
                  ? '${WhisperModelsScreen.formatBytes(progress!.downloadedBytes)} / ${WhisperModelsScreen.formatBytes(progress!.totalBytes!)}'
                  : WhisperModelsScreen.formatBytes(progress!.downloadedBytes),
              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(l10n.whisperModelCancelDownload),
              ),
            ),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!isInstalled)
                  FilledButton.icon(
                    onPressed: anotherDownloading ? null : onDownload,
                    style: FilledButton.styleFrom(backgroundColor: shell.accent, foregroundColor: Colors.white),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text('${l10n.whisperModelDownload} (~${option.approxMegabytes} MB)'),
                  ),
                if (isInstalled && !isActive)
                  FilledButton.icon(
                    onPressed: onUse,
                    style: FilledButton.styleFrom(backgroundColor: shell.accent, foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.whisperModelUse),
                  ),
                if (isInstalled)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.debit),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.whisperModelDelete),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
