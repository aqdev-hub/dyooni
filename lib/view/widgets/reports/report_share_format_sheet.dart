import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/report_options.dart';

/// Pops with the chosen [ReportShareFormat], or `null` if dismissed without choosing.
class ReportShareFormatSheet extends StatelessWidget {
  const ReportShareFormatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.reportShareFormatTitle,
                textAlign: TextAlign.end,
                style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 17),
              ),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }
}
