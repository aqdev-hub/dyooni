import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';

class TransactionTable extends StatelessWidget {
  const TransactionTable({required this.transactions, super.key});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final chronological = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    var runningBalance = 0.0;
    final rows = <(Transaction, double)>[];
    for (final transaction in chronological) {
      runningBalance += transaction.direction == AccountDirection.credit ? transaction.amount : -transaction.amount;
      rows.add((transaction, runningBalance));
    }

    return Container(
      decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: shell.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
          children: [
            Container(
              color: shell.headerBottom,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              child: Row(
                children: [
                  _HeaderCell(l10n.dateLabel),
                  _HeaderCell(l10n.amountLabel),
                  _HeaderCell(l10n.detailsLabel),
                  _HeaderCell(l10n.reportBalanceHeader),
                ],
              ),
            ),
            for (final row in rows.reversed) _DataRow(transaction: row.$1, runningBalance: row.$2),
          ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.transaction, required this.runningBalance});
  final Transaction transaction;
  final double runningBalance;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final isCredit = transaction.direction == AccountDirection.credit;
    final amountColor = isCredit ? AppColors.credit : AppColors.debit;
    final amountCell = isCredit ? AppColors.creditCell : AppColors.debitCell;
    final balanceColor = runningBalance >= 0 ? AppColors.credit : AppColors.debit;
    final balanceCell = runningBalance >= 0 ? AppColors.creditCell : AppColors.debitCell;
    final date = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: shell.border))),
      child: Row(
        children: [
          _TextCell(date, color: shell.textSecondary, fontSize: 10),
          _TintedCell(transaction.amount.toStringAsFixed(0), background: amountCell, foreground: amountColor),
          _TextCell(transaction.details ?? '—', color: shell.textPrimary),
          _TintedCell(runningBalance.abs().toStringAsFixed(0), background: balanceCell, foreground: balanceColor),
        ],
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(this.value, {required this.color, this.fontSize});
  final String value;
  final Color color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(value, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySecondary(context).copyWith(color: color, fontSize: fontSize)),
        ),
      );
}

class _TintedCell extends StatelessWidget {
  const _TintedCell(this.value, {required this.background, required this.foreground});
  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(5)),
          child: Text(value, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary(context).copyWith(color: foreground, fontWeight: FontWeight.w700)),
        ),
      );
}
