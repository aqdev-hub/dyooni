import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/accounts/account_action_icon_row.dart';
import '../../widgets/accounts/transaction_table.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../transactions/add_transaction_screen.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({required this.account, super.key});
  final Account account;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(accountsProvider.notifier).deleteAccount(account.id);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, l10n.accountDeletedSuccessMessage);
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final transactions = ref.watch(transactionsForAccountProvider(account.id));

    // The header's credit/debit split for THIS account's own bottom bar — not the app-wide
    // totals shown on Home.
    var credit = 0.0;
    var debit = 0.0;
    for (final t in transactions) {
      if (t.direction == AccountDirection.credit) {
        credit += t.amount;
      } else {
        debit += t.amount;
      }
    }

    return Scaffold(
      backgroundColor: shell.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shell.headerTop, shell.headerBottom],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'edit') {
                        AppSnackBar.showError(context, l10n.comingSoonMessage);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref, l10n);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ),
                  IconButton(icon: Image.asset('assets/icons/header_document_reference.png', width: 27, height: 27), onPressed: () => AppSnackBar.showError(context, l10n.comingSoonMessage)),
                  IconButton(icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20), onPressed: () => AppSnackBar.showError(context, l10n.comingSoonMessage)),
                  const Spacer(),
                  Text(account.name, style: AppTextStyles.title(context).copyWith(color: Colors.white), overflow: TextOverflow.ellipsis),
                  IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20), onPressed: () => context.pop()),
                ],
              ),
            ),
            AccountActionIconRow(
              onAddAction: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
              onShare: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
              onMessage: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
              onCurrency: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(l10n.noTransactionsYet, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TransactionTable(transactions: transactions),
                    ),
            ),
            BottomSummaryBar(
              totalCredit: credit,
              totalDebit: debit,
              onAdd: () => showDialog<void>(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => Dialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SizedBox(
                    width: 340,
                    height: 440,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: AddTransactionScreen(accountId: account.id, accountName: account.name),
                    ),
                  ),
                ),
              ),
              addTooltip: l10n.addTransactionTitle,
            ),
          ],
        ),
      ),
    );
  }
}
