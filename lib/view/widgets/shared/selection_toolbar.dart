import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Replaces the normal screen header while a multi-select ("تحديد"/"تحديد الكل") session from
/// [EntityAction] is active. [onEdit] is only shown when exactly one item is selected — bulk edit
/// has no defined meaning here.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.selectedCount,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDelete,
    this.onEdit,
    super.key,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Container(
      color: shell.headerBottom,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: onCancel),
          Expanded(
            child: Text(
              l10n.selectedCountLabel(selectedCount),
              style: AppTextStyles.body(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.select_all_rounded, color: Colors.white),
            tooltip: l10n.selectAllAction,
            onPressed: onSelectAll,
          ),
          if (onEdit != null)
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), tooltip: l10n.edit, onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white), tooltip: l10n.delete, onPressed: onDelete),
        ],
      ),
    );
  }
}
