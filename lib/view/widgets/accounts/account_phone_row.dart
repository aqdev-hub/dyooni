import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/phone_launcher.dart';
import '../shared/app_snackbar.dart';

/// Only rendered when the account actually has a phone number (see AccountDetailsScreen) — sits
/// on the opposite side of the row from AccountActionIconRow, showing the number itself plus a
/// call icon that opens the device's dialer pre-filled with it.
class AccountPhoneRow extends StatelessWidget {
  const AccountPhoneRow({required this.phone, super.key});
  final String phone;

  Future<void> _call(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await launchPhoneDialer(phone);
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.callFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () => _call(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  phone,
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                child: const Icon(Icons.call_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
