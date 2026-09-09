import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dyooni_picker_theme.dart';
import '../../../data/models/general_settings.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../../logic/settings/direction_labels.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../widgets/shared/app_snackbar.dart';

/// شاشة "الإعدادات العامة" — مطابقة لهوية ديوني البصرية (نفس AppShellColors المستخدمة في كل
/// شاشات ما بعد تسجيل الدخول). كل زر هنا مرتبط بمنطق حقيقي في
/// logic/settings/general_settings_provider.dart، وليس مجرد واجهة.
class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  Future<void> _toggleBiometric(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      final supported = await ref.read(biometricAuthServiceProvider).isDeviceSupported();
      if (!supported) {
        if (mounted) AppSnackBar.showError(context, l10n.generalSettingsBiometricNotSupported);
        return;
      }
      final ok = await ref
          .read(biometricAuthServiceProvider)
          .authenticate(reason: l10n.generalSettingsBiometricEnableReason);
      if (!ok) return;
    }
    await ref.read(generalSettingsProvider.notifier).setBiometricEnabled(value);
    if (mounted) AppSnackBar.showSuccess(context, l10n.generalSettingsSettingsSavedMessage);
  }

  Future<void> _togglePassword(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      final password = await showDialog<String>(context: context, builder: (_) => const _SetPasswordDialog());
      if (password == null || !mounted) return; // ألغى المستخدم — لا تفعيل بلا كلمة مرور فعلية
      await ref.read(generalSettingsProvider.notifier).setPassword(password);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final dShell = dialogContext.shellColors;
          return AlertDialog(
            backgroundColor: dShell.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              l10n.generalSettingsDisablePasswordConfirmTitle,
              style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary),
            ),
            content: Text(
              l10n.generalSettingsDisablePasswordConfirmBody,
              style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.generalSettingsDisableAction, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
      await ref.read(generalSettingsProvider.notifier).disablePassword();
    }
    if (mounted) AppSnackBar.showSuccess(context, l10n.generalSettingsSettingsSavedMessage);
  }

  Future<void> _editLabel({required bool isCredit, required String current}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            isCredit ? l10n.generalSettingsEditCreditLabelTitle : l10n.generalSettingsEditDebitLabelTitle,
            style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary),
          ),
          content: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            autofocus: true,
            style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textPrimary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: dShell.accent),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(l10n.saveButton),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(generalSettingsProvider.notifier);
    if (isCredit) {
      await notifier.setCreditLabel(result.isEmpty ? null : result);
    } else {
      await notifier.setDebitLabel(result.isEmpty ? null : result);
    }
    if (mounted) AppSnackBar.showSuccess(context, l10n.generalSettingsSettingsSavedMessage);
  }

  Future<void> _pickAnnualClosingDate(DateTime? current) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: dyooniPickerTheme,
    );
    if (picked == null || !mounted) return;
    await ref.read(generalSettingsProvider.notifier).setAnnualClosingDate(picked);
    if (mounted) AppSnackBar.showSuccess(context, l10n.generalSettingsSettingsSavedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final settingsAsync = ref.watch(generalSettingsProvider);
    final googleEmail = ref.read(googleSignInProvider).currentUser?.email;

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [shell.headerTop, shell.headerBottom]),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18), onPressed: () => context.pop()),
                  Expanded(
                    child: Text(
                      l10n.generalSettingsScreenTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: settingsAsync.when(
                data: (settings) => _Body(settings: settings, googleEmail: googleEmail, screenState: this),
                loading: () => Center(child: CircularProgressIndicator(color: shell.accent)),
                error: (_, __) => Center(child: Text(l10n.unexpectedError, style: AppTextStyles.bodySecondary(context))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.settings, required this.googleEmail, required this.screenState});
  final GeneralSettings settings;
  final String? googleEmail;
  final _GeneralSettingsScreenState screenState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final creditLabel = resolveCreditLabel(l10n, settings);
    final debitLabel = resolveDebitLabel(l10n, settings);
    final notifier = ref.read(generalSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: shell.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.generalSettingsDriveEditHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.generalSettingsDriveConnectedLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                          Text(
                            googleEmail ?? l10n.generalSettingsDriveNotConnected,
                            style: AppTextStyles.body(context).copyWith(fontWeight: FontWeight.w800, color: shell.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: Icon(Icons.edit_rounded, color: shell.accent), onPressed: () => context.push('/drive-backup')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _ToggleRow(label: l10n.generalSettingsBiometricProtection, value: settings.biometricEnabled, onChanged: screenState._toggleBiometric),
        _ToggleRow(label: l10n.generalSettingsPasswordProtection, value: settings.passwordEnabled, onChanged: screenState._togglePassword),
        _ToggleRow(label: l10n.generalSettingsPinAccountsOnSearch, value: settings.pinMatchingAccountsOnSearch, onChanged: notifier.setPinMatchingAccountsOnSearch),
        _ToggleRow(label: l10n.generalSettingsShowAmountInWords, value: settings.showAmountInWordsWhileTyping, onChanged: notifier.setShowAmountInWordsWhileTyping),
        _ToggleRow(label: l10n.generalSettingsShowAccountCeiling, value: settings.showAccountCeilingOnAdd, onChanged: notifier.setShowAccountCeilingOnAdd),
        _ToggleRow(label: l10n.generalSettingsVoiceNotifications, value: settings.voiceNotificationsEnabled, onChanged: notifier.setVoiceNotificationsEnabled),
        _ToggleRow(label: l10n.generalSettingsShowTimeInOperations, value: settings.showTimeInOperations, onChanged: notifier.setShowTimeInOperations),

        const SizedBox(height: 10),
        InkWell(
          onTap: () => screenState._pickAnnualClosingDate(settings.annualClosingDate),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: shell.accent.withValues(alpha: 0.15)),
                  child: Icon(Icons.edit_calendar_outlined, color: shell.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settings.annualClosingDate == null
                        ? l10n.generalSettingsAnnualClosingTitle
                        : l10n.generalSettingsAnnualClosingWithDate(_formatDate(settings.annualClosingDate!)),
                    textAlign: TextAlign.end,
                    style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: shell.border)),
          child: Column(
            children: [
              _LabelEditRow(
                value: debitLabel,
                caption: l10n.generalSettingsChangeDebitLabel,
                onTap: () => screenState._editLabel(isCredit: false, current: settings.customDebitLabel ?? ''),
              ),
              const SizedBox(height: 10),
              _LabelEditRow(
                value: creditLabel,
                caption: l10n.generalSettingsChangeCreditLabel,
                onTap: () => screenState._editLabel(isCredit: true, current: settings.customCreditLabel ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          l10n.generalSettingsDefaultDirectionTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 10),
        _DefaultDirectionRow(
          label: debitLabel,
          selected: settings.defaultDirection == DefaultDirectionOption.debit,
          onTap: () => notifier.setDefaultDirection(DefaultDirectionOption.debit),
        ),
        _DefaultDirectionRow(
          label: creditLabel,
          selected: settings.defaultDirection == DefaultDirectionOption.credit,
          onTap: () => notifier.setDefaultDirection(DefaultDirectionOption.credit),
        ),
        _DefaultDirectionRow(
          label: l10n.generalSettingsKeepLastOperation,
          selected: settings.defaultDirection == DefaultDirectionOption.keepLast,
          onTap: () => notifier.setDefaultDirection(DefaultDirectionOption.keepLast),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, textAlign: TextAlign.end, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary))),
          const SizedBox(width: 10),
          Switch(value: value, onChanged: onChanged, activeThumbColor: shell.accent),
        ],
      ),
    );
  }
}

class _LabelEditRow extends StatelessWidget {
  const _LabelEditRow({required this.value, required this.caption, required this.onTap});
  final String value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: shell.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: shell.border)),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: shell.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(caption, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DefaultDirectionRow extends StatelessWidget {
  const _DefaultDirectionRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, textAlign: TextAlign.end, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary))),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: selected ? shell.accent : shell.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// يجمع كلمة مرور جديدة مرتين (منع الخطأ الإملائي) قبل تفعيل الحماية. يعيد كلمة المرور، أو
/// `null` عند الإلغاء.
class _SetPasswordDialog extends StatefulWidget {
  const _SetPasswordDialog();
  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
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
      title: Text(l10n.generalSettingsSetPasswordTitle, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: l10n.generalSettingsPasswordFieldHint,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 4) ? l10n.generalSettingsPasswordMinLengthMessage : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: l10n.generalSettingsConfirmPasswordFieldHint),
              validator: (v) {
                if (v == null || v.trim().length < 4) return l10n.generalSettingsPasswordMinLengthMessage;
                if (v != _passwordController.text) return l10n.passwordsDontMatch;
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: shell.accent),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_passwordController.text);
          },
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}
