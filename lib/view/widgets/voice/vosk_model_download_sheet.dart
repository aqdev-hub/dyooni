import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/voice/vosk_model_provider.dart';

/// Blocks entry to the voice screen's actual content only ONCE per device — after the Arabic
/// Vosk model is cached locally by [voskModelProvider], it resolves instantly on every later
/// app run, so this gate becomes an invisible no-op after the very first successful download.
class VoskModelGate extends ConsumerWidget {
  const VoskModelGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final modelAsync = ref.watch(voskModelProvider);

    return modelAsync.when(
      data: (_) => child,
      loading: () => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: shell.accent),
            const SizedBox(height: 16),
            Text(
              l10n.voiceModelDownloadingHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
            ),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: shell.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.voiceModelDownloadFailedMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(voskModelProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.voiceRetry),
            ),
          ],
        ),
      ),
    );
  }
}
