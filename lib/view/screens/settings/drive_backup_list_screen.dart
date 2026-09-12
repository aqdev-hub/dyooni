import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/drive_backup_metadata.dart';
import '../../../data/repositories/backup/backup_repository.dart' show RestoreMode;
import '../../../logic/settings/drive_backup_controller.dart';
import '../../widgets/shared/app_snackbar.dart';

class DriveBackupListScreen extends ConsumerStatefulWidget {
  const DriveBackupListScreen({super.key});

  @override
  ConsumerState<DriveBackupListScreen> createState() => _DriveBackupListScreenState();
}

class _DriveBackupListScreenState extends ConsumerState<DriveBackupListScreen> {
  late Future<List<DriveBackupMetadata>> _future;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(driveBackupControllerProvider.notifier).fetchBackupsList();
  }

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

  Future<void> _restore(DriveBackupMetadata backup) async {
    final l10n = AppLocalizations.of(context)!;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (_) => const _DriveRestoreConfirmDialog(),
    );
    if (mode == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(driveBackupControllerProvider.notifier).restore(backup.fileId, mode);
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
                      l10n.driveBackupListTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DriveBackupMetadata>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(child: CircularProgressIndicator(color: shell.accent));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(l10n.unexpectedError, style: AppTextStyles.bodySecondary(context)));
                  }
                  final backups = snapshot.data ?? const [];
                  if (backups.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.driveBackupListEmpty,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: backups.length,
                        itemBuilder: (context, index) {
                          final backup = backups[index];
                          final isDaily = backup.type == DriveBackupType.daily;
                          return Card(
                            color: shell.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: shell.border)),
                            child: ListTile(
                              leading: Icon(isDaily ? Icons.event_repeat_rounded : Icons.touch_app_outlined, color: shell.accent),
                              title: Text(
                                _formatDate(backup.updatedAt),
                                style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                isDaily ? l10n.driveBackupTypeDaily : l10n.driveBackupTypeManual,
                                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                              ),
                              trailing: Icon(Icons.restore_outlined, color: shell.accent),
                              onTap: _isBusy ? null : () => _restore(backup),
                            ),
                          );
                        },
                      ),
                      if (_isBusy)
                        Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: Center(child: CircularProgressIndicator(color: shell.accent)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same merge/replace choice UI as the local backup feature's restore dialog — deliberately no
/// password field here, since Drive backups aren't password-encrypted (see the class doc comment
/// on DriveBackupRepositoryImpl for why).
class _DriveRestoreConfirmDialog extends StatefulWidget {
  const _DriveRestoreConfirmDialog();

  @override
  State<_DriveRestoreConfirmDialog> createState() => _DriveRestoreConfirmDialogState();
}

class _DriveRestoreConfirmDialogState extends State<_DriveRestoreConfirmDialog> {
  RestoreMode _mode = RestoreMode.merge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final isReplace = _mode == RestoreMode.replace;

    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.localBackupRestoreConfirmTitle, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: SingleChildScrollView(
        child: RadioGroup<RestoreMode>(
          groupValue: _mode,
          onChanged: (v) {
            if (v != null) setState(() => _mode = v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<RestoreMode>(
                value: RestoreMode.merge,
                activeColor: shell.accent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.localBackupModeMerge,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  l10n.localBackupModeMergeHint,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                ),
              ),
              RadioListTile<RestoreMode>(
                value: RestoreMode.replace,
                activeColor: AppColors.error,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.localBackupModeReplace,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  l10n.localBackupModeReplaceHint,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: isReplace ? AppColors.error : shell.accent),
          onPressed: () => Navigator.of(context).pop(_mode),
          child: Text(isReplace ? l10n.localBackupModeReplace : l10n.localBackupModeMerge),
        ),
      ],
    );
  }
}
