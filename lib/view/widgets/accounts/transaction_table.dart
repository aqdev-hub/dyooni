import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../shared/app_snackbar.dart';
import '../shared/entity_actions_sheet.dart';
import '../voice/voice_recording_player.dart';

/// - Tapping a row (outside selection mode) opens it for editing via [onEditTransaction].
/// - Long-pressing a row opens the shared action sheet (edit/delete/share/transfer/select/select
///   all — see EntityAction). "Select"/"Select all" turn on the shared selection providers, which
///   AccountDetailsScreen also watches to swap its header for the "N selected" toolbar.
/// - While selection mode is active, each row shows a leading checkbox and taps toggle selection
///   instead of opening the editor.
class TransactionTable extends ConsumerWidget {
  const TransactionTable({
    required this.transactions,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
    super.key,
  });

  final List<Transaction> transactions;
  final ValueChanged<Transaction> onEditTransaction;
  final ValueChanged<Transaction> onDeleteTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final selectionMode = ref.watch(transactionSelectionModeProvider);
    final selectedIds = ref.watch(selectedTransactionIdsProvider);
    final chronological = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    var runningBalance = 0.0;
    final rows = <(Transaction, double)>[];
    for (final transaction in chronological) {
      runningBalance += transaction.direction == AccountDirection.credit ? transaction.amount : -transaction.amount;
      rows.add((transaction, runningBalance));
    }

    Future<void> handleLongPress(Transaction transaction) async {
      final action = await showEntityActionsSheet(context);
      if (!context.mounted || action == null) return;
      switch (action) {
        case EntityAction.edit:
          onEditTransaction(transaction);
        case EntityAction.delete:
          onDeleteTransaction(transaction);
        case EntityAction.share:
        case EntityAction.transfer:
          AppSnackBar.showError(context, l10n.comingSoonMessage);
        case EntityAction.select:
          ref.read(transactionSelectionModeProvider.notifier).state = true;
          ref.read(selectedTransactionIdsProvider.notifier).state = {transaction.id};
        case EntityAction.selectAll:
          ref.read(transactionSelectionModeProvider.notifier).state = true;
          ref.read(selectedTransactionIdsProvider.notifier).state = transactions.map((t) => t.id).toSet();
      }
    }

    void handleTap(Transaction transaction) {
      if (selectionMode) {
        final next = {...selectedIds};
        if (!next.remove(transaction.id)) next.add(transaction.id);
        ref.read(selectedTransactionIdsProvider.notifier).state = next;
        return;
      }
      onEditTransaction(transaction);
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
                  if (selectionMode) const SizedBox(width: 28),
                  _HeaderCell(l10n.dateLabel),
                  _HeaderCell(l10n.amountLabel),
                  _HeaderCell(l10n.detailsLabel),
                  _HeaderCell(l10n.reportBalanceHeader),
                ],
              ),
            ),
            for (final row in rows.reversed)
              _DataRow(
                transaction: row.$1,
                runningBalance: row.$2,
                selectionMode: selectionMode,
                selected: selectedIds.contains(row.$1.id),
                onTap: () => handleTap(row.$1),
                onLongPress: () => handleLongPress(row.$1),
              ),
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
  const _DataRow({
    required this.transaction,
    required this.runningBalance,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final Transaction transaction;
  final double runningBalance;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final isCredit = transaction.direction == AccountDirection.credit;
    final amountColor = isCredit ? AppColors.credit : AppColors.debit;
    final amountCell = isCredit ? AppColors.creditCell : AppColors.debitCell;
    final balanceColor = runningBalance >= 0 ? AppColors.credit : AppColors.debit;
    final balanceCell = runningBalance >= 0 ? AppColors.creditCell : AppColors.debitCell;
    final date = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? shell.accent.withValues(alpha: 0.14) : null,
          border: Border(top: BorderSide(color: shell.border)),
        ),
        child: Row(
          children: [
            if (selectionMode)
              SizedBox(
                width: 28,
                child: Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: selected ? shell.accent : shell.textSecondary,
                ),
              ),
            _TextCell(date, color: shell.textSecondary, fontSize: 10),
            _TintedCell(transaction.amount.toStringAsFixed(0), background: amountCell, foreground: amountColor),
            _DetailsCell(transaction: transaction, color: shell.textPrimary),
            _TintedCell(runningBalance.abs().toStringAsFixed(0), background: balanceCell, foreground: balanceColor),
          ],
        ),
      ),
    );
  }
}

class _DetailsCell extends StatelessWidget {
  const _DetailsCell({required this.transaction, required this.color});
  final Transaction transaction;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Flexible(child: Text(transaction.details ?? '—', textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySecondary(context).copyWith(color: color))),
            if (transaction.voiceRecording != null) VoiceRecordingPlayer(recording: transaction.voiceRecording!),
            ],
          ),
        ),
      );
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
