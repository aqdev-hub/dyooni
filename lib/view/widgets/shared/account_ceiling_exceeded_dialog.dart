import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Warns before an entry exceeds an account's configured debit ceiling.
/// Returns true only when the person chooses to raise the ceiling.
Future<bool> showAccountCeilingExceededDialog(
  BuildContext context, {
  required double projectedDebitBalance,
  required double ceiling,
  required String debitLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final shell = dialogContext.shellColors;
      return AlertDialog(
        backgroundColor: shell.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.ceilingExceededTitle,
                style: AppTextStyles.title(dialogContext).copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
        content: Text(
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
