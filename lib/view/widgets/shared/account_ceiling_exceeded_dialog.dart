import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'app_popup.dart';

/// Warns before an entry exceeds an account's configured debit ceiling.
/// Returns true only when the person chooses to raise the ceiling.
Future<bool> showAccountCeilingExceededDialog(
  BuildContext context, {
  required double projectedDebitBalance,
  required double ceiling,
  required String debitLabel,
}) async {
  final result = await showAppPopup<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final shell = dialogContext.shellColors;
      return AppPopup(
        title: l10n.ceilingExceededTitle,
        icon: Icons.error_outline_rounded,
        child: Text(
          l10n.ceilingExceededBody(
            ceiling.toStringAsFixed(0),
            debitLabel,
            projectedDebitBalance.toStringAsFixed(0),
          ),
          style: AppTextStyles.body(dialogContext).copyWith(color: shell.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ceilingExceededRaiseButton),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
