import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/report_options.dart';
import '../shared/app_popup.dart';

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

    return AppPopup(
      title: l10n.reportSortSheetTitle,
      icon: Icons.sort_rounded,
      scrollable: false,
      contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
      child: ListView(
        shrinkWrap: true,
        children: [
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
        ],
      ),
    );
  }
}
