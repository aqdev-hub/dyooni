import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/personal_data.dart';
import '../../../logic/settings/personal_data_provider.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/app_snackbar.dart';

class PersonalDataScreen extends ConsumerStatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  ConsumerState<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressArController = TextEditingController();
  final _addressEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _signatureEnabled = true;
  bool _stampEnabled = true;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressArController.dispose();
    _addressEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _applyData(PersonalData data) {
    _nameArController.text = data.nameAr;
    _nameEnController.text = data.nameEn;
    _addressArController.text = data.addressAr;
    _addressEnController.text = data.addressEn;
    _phoneController.text = data.phone;
    _emailController.text = data.email;
    _signatureEnabled = data.signatureEnabled;
    _stampEnabled = data.stampEnabled;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    final data = PersonalData(
      nameAr: _nameArController.text.trim(),
      nameEn: _nameEnController.text.trim(),
      addressAr: _addressArController.text.trim(),
      addressEn: _addressEnController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      signatureEnabled: _signatureEnabled,
      stampEnabled: _stampEnabled,
    );
    try {
      await ref.read(personalDataProvider.notifier).save(data);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.personalDataSavedMessage);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final dataAsync = ref.watch(personalDataProvider);

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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.drawerPersonalData,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context).copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (!_initialized) {
                    _applyData(data);
                    _initialized = true;
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: shell.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: shell.border),
                          ),
                          child: Text(
                            l10n.personalDataFeatureNote,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.personalDataLogoLabel,
                          style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 160,
                            height: 160,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: shell.surface,
                              border: Border.all(color: shell.accent, width: 2),
                            ),
                            child: const AppLogo(size: 120),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PillButton(
                              label: l10n.personalDataChangeLogo,
                              onTap: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                            ),
                            const SizedBox(width: 10),
                            _PillButton(
                              label: l10n.personalDataDeleteLogo,
                              onTap: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.personalDataReportHeaderNote,
                          style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        _ProfileField(label: l10n.nameArLabel, controller: _nameArController),
                        _ProfileField(label: l10n.nameEnLabel, controller: _nameEnController),
                        _ProfileField(label: l10n.addressArLabel, controller: _addressArController),
                        _ProfileField(label: l10n.addressEnLabel, controller: _addressEnController),
                        _ProfileField(label: l10n.phoneLabel, controller: _phoneController, keyboardType: TextInputType.phone),
                        _ProfileField(label: l10n.emailLabel, controller: _emailController, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 10),
                        _ToggleRow(
                          label: l10n.personalDataAddSignature,
                          value: _signatureEnabled,
                          onChanged: (v) => setState(() => _signatureEnabled = v),
                          preview: const _SignaturePreview(),
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          label: l10n.personalDataChooseStamp,
                          value: _stampEnabled,
                          onChanged: (v) => setState(() => _stampEnabled = v),
                          preview: const _StampPreview(),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.backgroundTop,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : Text(l10n.saveButton, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
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

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: shell.accent,
        side: BorderSide(color: shell.accent),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      child: Text(label, style: AppTextStyles.bodySecondary(context).copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// Label sits at the trailing (right, in Arabic) edge and the field takes the rest — matches the
/// reference's row layout, built the same RTL-first way as the rest of the codebase (first Row
/// child renders at the visual right in RTL; see transaction_table.dart's column-order comment
/// for the established precedent).
class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.controller, this.keyboardType});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: shell.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: shell.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged, required this.preview});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: shell.border),
      ),
      child: Row(
        children: [
          Switch(value: value, onChanged: onChanged, activeThumbColor: shell.accent),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          if (value) preview,
        ],
      ),
    );
  }
}

/// Dyooni's own placeholder signature — a stylized rendering of the app name in the brand gold,
/// NOT a real uploaded signature image (no such asset exists yet; the actual upload flow is an
/// honest "coming soon" placeholder here, same as several other spots in the app already).
class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'ديوني',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: AppColors.gold,
      ),
    );
  }
}

/// Dyooni's own placeholder stamp — a simple drawn badge, not a real uploaded stamp image (see
/// the doc comment on _SignaturePreview for why).
class _StampPreview extends StatelessWidget {
  const _StampPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: AppColors.gold, width: 1.6)),
      ),
      child: const Text(
        'د',
        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }
}
