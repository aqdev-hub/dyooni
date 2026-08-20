import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/accounts/accounts_provider.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({required this.summary, required this.title, super.key});
  final AccountsSummary summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
              const Spacer(),
              Icon(Icons.people_outline, size: 16, color: shell.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${l10n.homeAccountsCount}: ${summary.count}',
                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: shell.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatColumn(
                label: l10n.homeTotalBalance,
                value: summary.net,
                color: shell.textPrimary,
              ),
              _StatColumn(
                label: l10n.homeTotalCredit,
                value: summary.totalCredit,
                color: AppColors.credit,
                icon: Icons.arrow_upward_rounded,
              ),
              _StatColumn(
                label: l10n.homeTotalDebit,
                value: summary.totalDebit,
                color: AppColors.debit,
                icon: Icons.arrow_downward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, required this.color, this.icon});
  final String label;
  final double value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toStringAsFixed(0),
                style: AppTextStyles.title(context).copyWith(color: color, fontSize: 16),
              ),
              if (icon != null) ...[
                const SizedBox(width: 2),
                Icon(icon, size: 14, color: color),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
