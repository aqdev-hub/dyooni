import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reused by Home (accounts totals, with the "add" button) and Account Details (one account's
/// totals, with its own "add transaction" button) — same visual contract, different numbers and
/// optional add-action feeding it.
///
/// The debit/credit pair inside the accent box is wrapped in `Expanded` — it used to be a plain
/// `Row` with `spaceBetween` and no `Expanded`/`Flexible` anywhere, which is exactly what
/// overflowed in English ("Credit"/"Debit" plus their numbers run wider than the Arabic
/// equivalents on some screens, with nothing flexible to shrink). Wrapping each stat in
/// `Expanded` fixes that without changing anything else about the layout or its public API.
class BottomSummaryBar extends StatelessWidget {
  const BottomSummaryBar({
    required this.totalCredit,
    required this.totalDebit,
    this.onAdd,
    this.addTooltip,
    super.key,
  });

  final double totalCredit;
  final double totalDebit;
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final net = totalCredit - totalDebit;
    final netIsDebit = net < 0;
    final netLabel = netIsDebit ? l10n.directionDebit : l10n.directionCredit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: shell.surface,
        border: Border(top: BorderSide(color: shell.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: shell.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: l10n.directionDebit,
                          valueText: totalDebit.toStringAsFixed(0),
                          color: AppColors.debit,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: l10n.directionCredit,
                          valueText: totalCredit.toStringAsFixed(0),
                          color: AppColors.credit,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l10n.homeTotalBalance} $netLabel: ${net.abs().toStringAsFixed(0)} ${l10n.currencyLocal}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: addTooltip ?? '',
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: shell.headerBottom, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.note_add_rounded, color: shell.accent, size: 29),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `alignEnd` lets the credit stat sit at the trailing edge of its half (matching the original
/// `spaceBetween` look) while the debit stat sits at the leading edge — both fields are actually
/// used by at least one call site, so this can't trip the `unused_element_parameter` check that
/// caught the previous `suffix` parameter.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.valueText,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String valueText;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          valueText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(context).copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
