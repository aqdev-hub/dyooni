import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../logic/transactions/transactions_provider.dart';

/// Matches the reference row exactly: a gold/navy chevron toggle on the far side, name + balance
/// in the middle, and a document icon with a small gold count badge on the near side. Tapping the
/// chevron expands the row to preview the most recent entry — tapping the row body itself still
/// opens full Account Details, unchanged from before.
class AccountListTile extends ConsumerStatefulWidget {
  const AccountListTile({required this.account, this.onTap, super.key});
  final Account account;
  final VoidCallback? onTap;

  @override
  ConsumerState<AccountListTile> createState() => _AccountListTileState();
}

class _AccountListTileState extends ConsumerState<AccountListTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final account = widget.account;
    final balance = ref.watch(accountBalanceProvider(account.id));
    final direction = ref.watch(accountDirectionProvider(account.id));
    final count = ref.watch(accountTransactionCountProvider(account.id));
    final transactions = ref.watch(transactionsForAccountProvider(account.id));
    final isCredit = direction == AccountDirection.credit;
    final color = isCredit ? AppColors.credit : AppColors.debit;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: shell.border, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Column(
                    children: [
                      Icon(Icons.note_add_rounded, size: 23, color: shell.accent),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: shell.badge, borderRadius: BorderRadius.circular(3)),
                        child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          balance.abs().toStringAsFixed(0),
                          style: AppTextStyles.title(context).copyWith(color: color, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _expanded ? AppColors.chevronExpanded : AppColors.chevronCollapsed),
                      child: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: _expanded ? AppColors.gold : shell.background),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${l10n.detailsLabel}: ${transactions.last.details ?? "—"}',
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
