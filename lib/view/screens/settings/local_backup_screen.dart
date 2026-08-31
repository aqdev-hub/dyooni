import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/backup/backup_repository.dart';
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
      'backupWrongPassword' => l10n.localBackupWrongPasswordMessage,
      'networkUnreachable' => l10n.networkUnreachable,
      _ => l10n.unexpectedError,
    };
  }

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordSetupDialog(),
    );
    if (password == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final result = await ref.read(localBackupProvider.notifier).createBackup(password);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        result.savedToDownloads ? l10n.localBackupSavedToDownloadsMessage : l10n.localBackupSavedToAppFolderMessage,
      );
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
      allowedExtensions: ['dyoonibackup'],
    );
    final pickedPath = picked?.files.single.path;
    if (pickedPath == null || !mounted) return; // person backed out of the picker

    final choice = await showDialog<(String, RestoreMode)>(
      context: context,
      builder: (_) => const _RestoreOptionsDialog(),
    );
    if (choice == null || !mounted) return;
    final (password, mode) = choice;

    setState(() => _isBusy = true);
    try {
      await ref.read(localBackupProvider.notifier).restoreFromFile(pickedPath, password, mode);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.localBackupRestoredSuccessMessage);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, _errorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareLastBackup(String path) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final infoAsync = ref.watch(localBackupProvider);

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
                    infoAsync.when(
                      data: (info) => info.lastBackupAt == null
                          ? Text(
                              l10n.localBackupNeverLabel,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    l10n.localBackupLastLabel(_formatDate(info.lastBackupAt!)),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                                  ),
                                ),
                                if (info.lastBackupPath != null) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: Icon(Icons.ios_share_rounded, size: 18, color: shell.accent),
                                    tooltip: l10n.localBackupShareLastTooltip,
                                    onPressed: () => _shareLastBackup(info.lastBackupPath!),
                                  ),
                                ],
                              ],
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

/// Collects a mandatory password (≥5 characters — letters, digits, or a mix, per the confirmed
/// requirement) TWICE before creating a backup, so a typo doesn't lock the person out of their
/// own data. Returns the password, or `null` if cancelled.
class _PasswordSetupDialog extends StatefulWidget {
  const _PasswordSetupDialog();

  @override
  State<_PasswordSetupDialog> createState() => _PasswordSetupDialogState();
}

class _PasswordSetupDialogState extends State<_PasswordSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.localBackupSetPasswordTitle, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.localBackupSetPasswordHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: l10n.localBackupPasswordLabel,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 5) ? l10n.localBackupPasswordTooShort : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: l10n.localBackupConfirmPasswordLabel),
              validator: (v) {
                if (v == null || v.trim().length < 5) return l10n.localBackupPasswordTooShort;
                if (v != _passwordController.text) return l10n.localBackupPasswordsDontMatch;
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: shell.accent),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_passwordController.text.trim());
          },
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

/// Lets the person pick [RestoreMode.merge] (safe, non-destructive — the default) or
/// [RestoreMode.replace] (destructive — clearly marked in red, with its own warning line) plus
/// the password the file was encrypted with. Returns `(password, mode)`, or `null` if cancelled.
class _RestoreOptionsDialog extends StatefulWidget {
  const _RestoreOptionsDialog();

  @override
  State<_RestoreOptionsDialog> createState() => _RestoreOptionsDialogState();
}

class _RestoreOptionsDialogState extends State<_RestoreOptionsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  RestoreMode _mode = RestoreMode.merge;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final isReplace = _mode == RestoreMode.replace;

    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.localBackupRestoreConfirmTitle, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<RestoreMode>(
                groupValue: _mode,
                onChanged: (v) {
                  if (v != null) setState(() => _mode = v);
                },
                child: Column(
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: l10n.localBackupPasswordLabel,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 5) ? l10n.localBackupPasswordTooShort : null,
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((_passwordController.text.trim(), _mode));
          },
          child: Text(isReplace ? l10n.localBackupModeReplace : l10n.localBackupModeMerge),
        ),
      ],
    );
  }
}
