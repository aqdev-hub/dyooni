import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The six actions offered on a long-press, for both an account row (Home) and a transaction row
/// (Account Details) — one shared sheet so the two never visually drift apart.
enum EntityAction { edit, delete, share, transfer, select, selectAll }

/// Shows the long-press action sheet and returns whichever [EntityAction] was tapped, or `null`
/// if the sheet was dismissed without choosing.
Future<EntityAction?> showEntityActionsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final shell = context.shellColors;

  Widget tile(IconData icon, String label, EntityAction action, {Color? color}) => ListTile(
        leading: Icon(icon, color: color ?? shell.accent),
        title: Text(
          label,
          textAlign: TextAlign.end,
          style: AppTextStyles.body(context).copyWith(color: color ?? shell.textPrimary, fontWeight: FontWeight.w600),
        ),
        onTap: () => Navigator.of(context).pop(action),
      );

  return showModalBottomSheet<EntityAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(Icons.edit_outlined, l10n.edit, EntityAction.edit),
            tile(Icons.delete_outline_rounded, l10n.delete, EntityAction.delete, color: AppColors.debit),
            tile(Icons.share_outlined, l10n.shareAction, EntityAction.share),
            tile(Icons.swap_horiz_rounded, l10n.transferAction, EntityAction.transfer),
            tile(Icons.check_circle_outline_rounded, l10n.selectOne, EntityAction.select),
            tile(Icons.select_all_rounded, l10n.selectAllAction, EntityAction.selectAll),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
