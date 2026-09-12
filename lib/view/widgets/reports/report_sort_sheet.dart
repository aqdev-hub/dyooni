import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/report_options.dart';

/// Pops with the chosen [ReportSortOption], or `null` if dismissed without choosing.
class ReportSortSheet extends StatelessWidget {
  const ReportSortSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final options = <(ReportSortOption, String)>[
      (ReportSortOption.dateAsc, l10n.reportSortDateAsc),
      (ReportSortOption.dateDesc, l10n.reportSortDateDesc),
      (ReportSortOption.balanceAsc, l10n.reportSortBalanceAsc),
      (ReportSortOption.balanceDesc, l10n.reportSortBalanceDesc),
      (ReportSortOption.nameAsc, l10n.reportSortNameAsc),
      (ReportSortOption.nameDesc, l10n.reportSortNameDesc),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: shell.accent,
              child: Text(
                l10n.reportSortSheetTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.button(context).copyWith(color: shell.headerBottom, fontWeight: FontWeight.w800),
              ),
            ),
            for (final (value, label) in options)
              ListTile(
                title: Text(
                  label,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                ),
                trailing: Icon(Icons.radio_button_off_rounded, color: shell.textSecondary),
                onTap: () => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
