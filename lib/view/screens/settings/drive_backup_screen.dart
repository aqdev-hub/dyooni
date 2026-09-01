import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/settings/drive_backup_controller.dart';
import '../../widgets/shared/app_snackbar.dart';

class DriveBackupScreen extends ConsumerStatefulWidget {
  const DriveBackupScreen({super.key});

  @override
  ConsumerState<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

class _DriveBackupScreenState extends ConsumerState<DriveBackupScreen> {
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    // Forces a fresh opportunistic check every time this screen is opened — see
    // DriveBackupController's doc comment for why this, plus Home's own one-per-session read,
    // are the two real trigger points in this implementation.
    Future.microtask(() => ref.read(driveBackupControllerProvider.notifier).refresh());
  }

  String _errorMessage(AppLocalizations l10n, Object error) {
    // ignore: avoid_dynamic_calls — AppException is sealed; `code` always exists on this type.
    final code = (error as dynamic).code as String;
    return switch (code) {
      'driveBackupNoGoogleAccount' => l10n.driveBackupNoAccountMessage,
      'backupFileInvalid' => l10n.localBackupInvalidFileMessage,
      'backupIncompatible' => l10n.localBackupIncompatibleMessage,
      'networkUnreachable' => l10n.networkUnreachable,
      _ => l10n.unexpectedError,
    };
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    try {
      await ref.read(driveBackupControllerProvider.notifier).connectGoogleAccount();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    try {
      await ref.read(driveBackupControllerProvider.notifier).saveNow();
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.driveBackupSavedSuccessMessage);
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
    final stateAsync = ref.watch(driveBackupControllerProvider);

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
                      l10n.driveBackupScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: stateAsync.when(
                data: (state) => SingleChildScrollView(
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
                          l10n.driveBackupExplanation,
                          style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: shell.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: shell.border),
                        ),
                        child: Column(
                          children: [
                            _StatusRow(
                              label: l10n.driveBackupStatusLabel,
                              value: state.hasGoogleAccess ? l10n.driveBackupStatusEnabled : l10n.driveBackupStatusNeedsAccount,
                            ),
                            Divider(color: shell.border, height: 1),
                            _StatusRow(
                              label: l10n.driveBackupLastSuccessLabel,
                              value: state.lastBackupAt == null ? l10n.localBackupNeverLabel : _formatDate(state.lastBackupAt!),
                            ),
                            Divider(color: shell.border, height: 1),
                            _StatusRow(
                              label: l10n.driveBackupTodayLabel,
                              value: state.hasTodayBackup ? l10n.driveBackupTodayReady : '—',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!state.hasGoogleAccess)
                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.backgroundTop,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.link_rounded),
                          label: Text(l10n.driveBackupConnectButton, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
                        )
                      else ...[
                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _saveNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.backgroundTop,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(l10n.driveBackupSaveNowButton, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : () => context.push('/drive-backup/list'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: shell.accent,
                            side: BorderSide(color: shell.accent),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.history_rounded),
                          label: Text(l10n.driveBackupRestoreButton, style: AppTextStyles.button(context).copyWith(color: shell.accent)),
                        ),
                      ],
                      if (_isBusy) ...[
                        const SizedBox(height: 20),
                        Center(child: CircularProgressIndicator(color: shell.accent)),
                      ],
                    ],
                  ),
                ),
                loading: () => Center(child: CircularProgressIndicator(color: shell.accent)),
                error: (_, __) => Center(
                  child: Text(l10n.unexpectedError, style: AppTextStyles.bodySecondary(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
