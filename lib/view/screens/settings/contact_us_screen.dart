import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/app_snackbar.dart';

/// Contact details are fixed constants (not user-editable data), matching the pattern used
/// throughout the settings screens for anything that isn't stored per-account.
///
/// DISCLOSED ASSUMPTION: the number was given without a country code — assumed +967 (Yemen),
/// matching the project's default currency/locale context. If that's wrong, only these three
/// lines need to change.
const _contactPhoneLocal = '772906988';
const _whatsappNumber = '967$_contactPhoneLocal'; // wa.me format: country code + number, no '+'
const _callNumber = '+967$_contactPhoneLocal';
const _supportEmail = 'sba849198@gmail.com';

/// "تواصل معنا" — reached from the drawer (now a real destination, see app_drawer.dart) and from
/// AboutScreen's own contact button. WhatsApp opens a chat prefilled with a default help-request
/// message (contactUsDefaultMessage); the same message is reused as the email body so the person
/// never has to type a first line themselves on any channel.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context, AppLocalizations l10n) async {
    try {
      await launchWhatsAppChat(_whatsappNumber, l10n.contactUsDefaultMessage);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.contactUsWhatsappFailedMessage);
    }
  }

  Future<void> _call(BuildContext context, AppLocalizations l10n) async {
    try {
      await launchPhoneDialer(_callNumber);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.callFailedMessage);
    }
  }

  Future<void> _sendEmail(BuildContext context, AppLocalizations l10n) async {
    try {
      await launchSupportEmail(
        email: _supportEmail,
        subject: l10n.contactUsEmailSubject,
        body: l10n.contactUsDefaultMessage,
      );
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.contactUsEmailFailedMessage);
    }
  }

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
                      l10n.contactUsScreenTitle,
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
                    const Center(child: AppLogo(size: 88)),
                    const SizedBox(height: 14),
                    Text(
                      l10n.contactUsIntro,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    _TeamCard(
                      roleLabel: l10n.contactUsManagementRole,
                      name: l10n.contactUsManagementName,
                      icon: Icons.engineering_outlined,
                    ),
                    const SizedBox(height: 10),
                    _TeamCard(
                      roleLabel: l10n.contactUsDevelopmentRole,
                      name: l10n.contactUsDevelopmentName,
                      icon: Icons.code_rounded,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.contactUsChooseMethod,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    _ContactActionButton(
                      icon: Icons.chat_bubble_rounded,
                      label: l10n.contactUsWhatsappLabel,
                      background: const Color(0xFF25D366),
                      onTap: () => _openWhatsApp(context, l10n),
                    ),
                    const SizedBox(height: 10),
                    _ContactActionButton(
                      icon: Icons.call_rounded,
                      label: l10n.contactUsCallLabel,
                      background: AppColors.success,
                      onTap: () => _call(context, l10n),
                    ),
                    const SizedBox(height: 10),
                    _ContactActionButton(
                      icon: Icons.mail_outline_rounded,
                      label: l10n.contactUsEmailLabel,
                      background: shell.headerBottom,
                      onTap: () => _sendEmail(context, l10n),
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.roleLabel, required this.name, required this.icon});
  final String roleLabel;
  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: shell.accent.withValues(alpha: 0.14)),
            child: Icon(icon, color: shell.accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(roleLabel, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon),
      label: Text(label, style: AppTextStyles.button(context).copyWith(color: Colors.white)),
    );
  }
}
