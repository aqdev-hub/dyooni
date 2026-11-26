import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/report_options.dart';
import '../shared/app_popup.dart';

/// Pops with the chosen [ReportShareFormat], or `null` if dismissed without choosing.
class ReportShareFormatSheet extends StatelessWidget {
  const ReportShareFormatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return AppPopup(
      title: l10n.reportShareFormatTitle,
      icon: Icons.ios_share_rounded,
      contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.reportShareFormatExcel,
              textAlign: TextAlign.end,
              style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
            ),
            trailing: Icon(Icons.radio_button_off_rounded, color: shell.textSecondary),
            onTap: () => Navigator.of(context).pop(ReportShareFormat.excel),
          ),
          ListTile(
            title: Text(
              l10n.reportShareFormatPdf,
              textAlign: TextAlign.end,
              style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
            ),
            trailing: Icon(Icons.radio_button_off_rounded, color: shell.textSecondary),
            onTap: () => Navigator.of(context).pop(ReportShareFormat.pdf),
          ),
        ],
      ),
    );
  }
}
