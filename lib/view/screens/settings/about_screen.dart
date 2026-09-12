import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_version.dart';
import '../../widgets/shared/app_logo.dart';

/// "حول التطبيق" — a static feature/credits page reached from the drawer. Feature copy here is
/// kept in sync with what is ACTUALLY implemented (see دليل_المشروع_الشامل.md's feature list) —
/// no aspirational/roadmap items are listed as if they were shipped.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    final features = <(IconData, String, String)>[
      (Icons.people_alt_outlined, l10n.aboutFeatureAccountsTitle, l10n.aboutFeatureAccountsDesc),
      (Icons.receipt_long_outlined, l10n.aboutFeatureTransactionsTitle, l10n.aboutFeatureTransactionsDesc),
      (Icons.mic_none_rounded, l10n.aboutFeatureVoiceTitle, l10n.aboutFeatureVoiceDesc),
      (Icons.picture_as_pdf_outlined, l10n.aboutFeatureReportsTitle, l10n.aboutFeatureReportsDesc),
      (Icons.lock_outline_rounded, l10n.aboutFeatureLocalBackupTitle, l10n.aboutFeatureLocalBackupDesc),
      (Icons.cloud_outlined, l10n.aboutFeatureDriveBackupTitle, l10n.aboutFeatureDriveBackupDesc),
      (Icons.verified_user_outlined, l10n.aboutFeatureAuthTitle, l10n.aboutFeatureAuthDesc),
      (Icons.language_rounded, l10n.aboutFeatureBilingualTitle, l10n.aboutFeatureBilingualDesc),
    ];

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
                      l10n.aboutScreenTitle,
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
                    const Center(child: AppLogo(size: 96)),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline(context).copyWith(color: shell.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.aboutTagline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.accent, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.aboutDescription,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(context).copyWith(color: shell.textSecondary, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.aboutFeaturesTitle,
                      style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    for (final (icon, title, desc) in features) ...[
                      _FeatureRow(icon: icon, title: title, description: desc),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: shell.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: shell.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.aboutTeamTitle,
                            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          _CreditLine(role: l10n.contactUsManagementRole, name: l10n.contactUsManagementName),
                          const SizedBox(height: 4),
                          _CreditLine(role: l10n.contactUsDevelopmentRole, name: l10n.contactUsDevelopmentName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        l10n.aboutVersionLabel(kAppVersion),
                        style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/contact-us'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: shell.accent,
                        side: BorderSide(color: shell.accent),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(l10n.drawerContactUs, style: AppTextStyles.button(context).copyWith(color: shell.accent)),
                    ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: shell.accent.withValues(alpha: 0.14)),
            child: Icon(icon, color: shell.accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditLine extends StatelessWidget {
  const _CreditLine({required this.role, required this.name});
  final String role;
  final String name;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            role,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(name, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
