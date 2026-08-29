import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/settings/local_backup_provider.dart';
import '../../widgets/shared/app_snackbar.dart';

class LocalBackupScreen extends ConsumerStatefulWidget {
  const LocalBackupScreen({super.key});

  @override
  ConsumerState<LocalBackupScreen> createState() => _LocalBackupScreenState();
}

class _LocalBackupScreenState extends ConsumerState<LocalBackupScreen> {
  bool _isBusy = false;

  String _errorMessage(AppLocalizations l10n, Object error) {
    // ignore: avoid_dynamic_calls — AppException is sealed; `code` always exists on this type.
    final code = (error as dynamic).code as String;
    return switch (code) {
      'backupFileInvalid' => l10n.localBackupInvalidFileMessage,
      'backupIncompatible' => l10n.localBackupIncompatibleMessage,
      'networkUnreachable' => l10n.networkUnreachable,
      _ => l10n.unexpectedError,
    };
  }

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    try {
      final path = await ref.read(localBackupProvider.notifier).createBackup();
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.localBackupCreatedSuccessMessage);
      // Opens the OS's general share sheet so the file can be saved anywhere the person
      // chooses (Drive, WhatsApp, a Files app...) — same mechanism already used for report
      // exports, see reports_screen.dart's _handleGenerateExcel.
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final pickedPath = picked?.files.single.path;
    if (pickedPath == null || !mounted) return; // person backed out of the picker

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            l10n.localBackupRestoreConfirmTitle,
            style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary),
          ),
          content: Text(
            l10n.localBackupRestoreConfirmBody,
            style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.localBackupRestoreButton,
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(localBackupProvider.notifier).restoreFromFile(pickedPath);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.localBackupRestoredSuccessMessage);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final lastBackupAsync = ref.watch(localBackupProvider);

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.localBackupScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: shell.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: shell.border),
                      ),
                      child: Text(
                        l10n.localBackupExplanation,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    lastBackupAsync.when(
                      data: (lastBackupAt) => Text(
                        lastBackupAt == null
                            ? l10n.localBackupNeverLabel
                            : l10n.localBackupLastLabel(_formatDate(lastBackupAt)),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                      ),
                      loading: () => Center(child: CircularProgressIndicator(color: shell.accent)),
                      error: (_, __) => Text(
                        l10n.unexpectedError,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isBusy ? null : _createBackup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundTop,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: Text(
                        l10n.localBackupCreateButton,
                        style: AppTextStyles.button(context).copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _restore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: shell.accent,
                        side: BorderSide(color: shell.accent),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(
                        l10n.localBackupRestoreButton,
                        style: AppTextStyles.button(context).copyWith(color: shell.accent),
                      ),
                    ),
                    if (_isBusy) ...[
                      const SizedBox(height: 20),
                      Center(child: CircularProgressIndicator(color: shell.accent)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
