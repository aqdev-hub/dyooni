import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/voice/vosk_model_provider.dart';

/// Blocks entry to the voice screen's actual content until the Arabic Vosk model is ready.
/// Shows a REAL progress bar (percentage + downloaded/total size) while downloading, a distinct
/// "preparing" spinner while extracting, and — critically, fixing the reported bug — a retry
/// button that actually resumes the download instead of doing nothing.
class VoskModelGate extends ConsumerWidget {
  const VoskModelGate({required this.child, super.key});
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
    final modelState = ref.watch(voskModelControllerProvider);

    return switch (modelState) {
      VoskModelReady() => child,
      VoskModelIdle() => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: shell.accent)),
        ),
      VoskModelDownloading(:final downloadedBytes, :final totalBytes) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalBytes != null) ...[
                LinearProgressIndicator(
                  value: downloadedBytes / totalBytes,
                  color: shell.accent,
                  backgroundColor: shell.border,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Text(
                  '${((downloadedBytes / totalBytes) * 100).toStringAsFixed(0)}% '
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
                l10n.voiceModelDownloadingHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
            ],
          ),
        ),
      VoskModelExtracting() => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: shell.accent),
              const SizedBox(height: 12),
              Text(
                l10n.voiceModelExtracting,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
            ],
          ),
        ),
      VoskModelFailed(:final message) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: shell.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(
                // Generic, cause-neutral wording now — the earlier version always said "check
                // your internet connection", which was actively misleading for failures that
                // have nothing to do with the network (e.g. a corrupted extraction).
                l10n.voiceModelDownloadFailedMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
              const SizedBox(height: 10),
              // Selectable + scrollable (not truncated with an ellipsis like the earlier
              // version) — this can now carry real diagnostic detail (e.g. a directory listing
              // of what extraction actually produced, see OfflineSpeechEngine's error wrapping),
              // and the person needs to be able to copy the WHOLE thing to report it accurately.
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
                // Calls the controller's own retry() — NOT ref.invalidate(). Invalidating a
                // plain FutureProvider (the earlier, broken design) just threw away all downloaded
                // bytes and started over on every tap; this NotifierProvider's retry() re-runs the
                // same pipeline, which skips straight past whatever's already on disk (the partial
                // .zip.part file included) — a real resume, not a reset.
                onPressed: () => ref.read(voskModelControllerProvider.notifier).retry(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.voiceRetry),
              ),
            ],
          ),
        ),
    };
  }
}
