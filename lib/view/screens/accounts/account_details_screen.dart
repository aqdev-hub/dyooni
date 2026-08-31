import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/account.dart';
import '../../../data/models/personal_data.dart';
import '../../../data/models/report_options.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/reports/pdf_report_service.dart';
import '../../../logic/reports/report_export_provider.dart';
import '../../../logic/settings/personal_data_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/accounts/account_action_icon_row.dart';
import '../../widgets/accounts/account_phone_row.dart';
import '../../widgets/accounts/transaction_table.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/reports/report_options_sheet.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/selection_toolbar.dart';
import '../accounts/add_account_screen.dart';
import '../transactions/add_transaction_screen.dart';

/// Real .xlsx MIME type — same reasoning as the earlier CSV export's explicit mimeType: without
/// it, some spreadsheet/office apps' share-receiver mishandles the file on receipt.
const _xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({required this.account, super.key});
  final Account account;

  @override
  ConsumerState<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String _searchQuery = '';

  Account get account => widget.account;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() => setState(() {
        _searchOpen = false;
        _searchQuery = '';
        _searchController.clear();
      });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.deleteAccountConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.deleteAccountConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
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

  Future<void> _confirmDeleteTransaction(BuildContext context, WidgetRef ref, AppLocalizations l10n, Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.deleteTransactionConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.deleteTransactionConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, l10n.transactionDeletedSuccessMessage);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  Future<void> _confirmDeleteSelectedTransactions(BuildContext context, WidgetRef ref, AppLocalizations l10n, Set<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dShell = dialogContext.shellColors;
        return AlertDialog(
          backgroundColor: dShell.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(l10n.deleteTransactionConfirmTitle, style: AppTextStyles.title(dialogContext).copyWith(color: dShell.textPrimary)),
          content: Text(l10n.deleteSelectedTransactionsConfirmBody, style: AppTextStyles.body(dialogContext).copyWith(color: dShell.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel, style: TextStyle(color: dShell.textSecondary))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    try {
      for (final id in ids) {
        await ref.read(transactionsProvider.notifier).deleteTransaction(id);
      }
      ref.read(transactionSelectionModeProvider.notifier).state = false;
      ref.read(selectedTransactionIdsProvider.notifier).state = {};
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, l10n.transactionDeletedSuccessMessage);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, l10n.unexpectedError);
    }
  }

  /// Opens the ACCOUNT edit screen (name/date/details/phone/category) — reached from the 3-dot
  /// menu's "تعديل" on this screen's own header. Deliberately separate from
  /// [_openEditTransaction] below: this is the account itself, not one of its transactions.
  void _openEditAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 340,
          height: 540,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: AddAccountScreen(existingAccount: account),
          ),
        ),
      ),
    );
  }

  void _openEditTransaction(BuildContext context, Transaction transaction) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 340,
          height: 540,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: AddTransactionScreen(
              accountId: account.id,
              accountName: account.name,
              existingTransaction: transaction,
            ),
          ),
        ),
      ),
    );
  }

  /// Chronological ledger with running balance — same logic as TransactionTable's, on purpose,
  /// so the PDF/Excel export and the on-screen table never disagree. Optionally filtered by
  /// [range] and re-ordered by [sort] before returning.
  List<StatementRow> _buildStatementRows(List<Transaction> transactions, DateTimeRange? range, ReportSortOption? sort) {
    var filtered = transactions;
    if (range != null) {
      filtered = filtered.where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end)).toList();
    }
    final chronological = [...filtered]..sort((a, b) => a.date.compareTo(b.date));
    var runningBalance = 0.0;
    final rows = <StatementRow>[];
    for (final t in chronological) {
      runningBalance += t.direction == AccountDirection.credit ? t.amount : -t.amount;
      rows.add(StatementRow(transaction: t, runningBalance: runningBalance));
    }
    return switch (sort) {
      ReportSortOption.dateDesc => rows.reversed.toList(),
      ReportSortOption.balanceAsc => [...rows]..sort((a, b) => a.runningBalance.compareTo(b.runningBalance)),
      ReportSortOption.balanceDesc => [...rows]..sort((a, b) => b.runningBalance.compareTo(a.runningBalance)),
      // dateAsc is already the default order; name sort is a no-op for a single account.
      _ => rows,
    };
  }

  Future<Uint8List> _generateStatementPdf(WidgetRef ref, AppLocalizations l10n, List<StatementRow> rows) {
    final personalData = ref.read(personalDataProvider).value ?? PersonalData.dyooniDefault;
    return ref.read(pdfReportServiceProvider).buildAccountStatement(
          personalData: personalData,
          appName: l10n.appName,
          reportTitle: '${l10n.reportTypeStatement} - ${account.name}',
          dateHeader: l10n.dateLabel,
          detailsHeader: l10n.detailsLabel,
          debitHeader: l10n.directionDebit,
          creditHeader: l10n.directionCredit,
          balanceHeader: l10n.reportBalanceHeader,
          totalRowLabel: l10n.homeTotalBalance,
          rows: rows,
        );
  }

  Uint8List _generateStatementXlsx(WidgetRef ref, AppLocalizations l10n, List<StatementRow> rows) {
    return ref.read(xlsxReportServiceProvider).buildAccountStatement(
          reportTitle: '${l10n.reportTypeStatement} - ${account.name}',
          dateHeader: l10n.dateLabel,
          detailsHeader: l10n.detailsLabel,
          debitHeader: l10n.directionDebit,
          creditHeader: l10n.directionCredit,
          balanceHeader: l10n.reportBalanceHeader,
          totalRowLabel: l10n.homeTotalBalance,
          attachmentPresentLabel: l10n.attachmentPresentLabel,
          rows: rows,
        );
  }

  Future<void> _handleGeneratePdf(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Transaction> transactions,
    AccountReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
  ) async {
    if (type != AccountReportType.statement) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    try {
      final rows = _buildStatementRows(transactions, range, sort);
      final bytes = await _generateStatementPdf(ref, l10n, rows);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${account.name}.pdf');
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    }
  }

  Future<void> _handleGenerateExcel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Transaction> transactions,
    AccountReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
  ) async {
    if (type != AccountReportType.statement) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    try {
      final rows = _buildStatementRows(transactions, range, sort);
      final bytes = _generateStatementXlsx(ref, l10n, rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${account.name}.xlsx');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: _xlsxMimeType)]));
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    }
  }

  Future<void> _handleShareViaWhatsapp(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Transaction> transactions,
    AccountReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
    ReportShareFormat format,
  ) async {
    if (type != AccountReportType.statement) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    try {
      final rows = _buildStatementRows(transactions, range, sort);
      if (format == ReportShareFormat.pdf) {
        final bytes = await _generateStatementPdf(ref, l10n, rows);
        await Printing.sharePdf(bytes: bytes, filename: '${account.name}.pdf');
      } else {
        final bytes = _generateStatementXlsx(ref, l10n, rows);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${account.name}.xlsx');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: _xlsxMimeType)]));
      }
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    }
  }

  Future<void> _openReportsSheet(BuildContext context, WidgetRef ref, AppLocalizations l10n, List<Transaction> transactions) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportOptionsSheet<AccountReportType>(
        initialType: AccountReportType.statement,
        options: [
          (AccountReportType.statement, l10n.reportTypeStatement),
          (AccountReportType.monthlyStatement, l10n.reportTypeMonthlyStatement),
        ],
        onGeneratePdf: (type, sort, range) => _handleGeneratePdf(context, ref, l10n, transactions, type, sort, range),
        onGenerateExcel: (type, sort, range) => _handleGenerateExcel(context, ref, l10n, transactions, type, sort, range),
        onShareViaWhatsapp: (type, sort, range, format) =>
            _handleShareViaWhatsapp(context, ref, l10n, transactions, type, sort, range, format),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final transactions = ref.watch(transactionsForAccountProvider(account.id));
    final selectionMode = ref.watch(transactionSelectionModeProvider);
    final selectedIds = ref.watch(selectedTransactionIdsProvider);
    final hasPhone = account.phone != null && account.phone!.trim().isNotEmpty;

    // The header's credit/debit split for THIS account's own bottom bar — always the REAL,
    // unfiltered totals, regardless of whatever the search box above is currently narrowing the
    // list down to (a search is a view filter, not a different account).
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
            if (selectionMode)
              SelectionToolbar(
                selectedCount: selectedIds.length,
                onCancel: () {
                  ref.read(transactionSelectionModeProvider.notifier).state = false;
                  ref.read(selectedTransactionIdsProvider.notifier).state = {};
                },
                onSelectAll: () => ref.read(selectedTransactionIdsProvider.notifier).state = transactions.map((t) => t.id).toSet(),
                onEdit: selectedIds.length == 1
                    ? () {
                        final match = transactions.where((t) => t.id == selectedIds.first);
                        if (match.isEmpty) return;
                        _openEditTransaction(context, match.first);
                      }
                    : null,
                onDelete: () => _confirmDeleteSelectedTransactions(context, ref, l10n, selectedIds),
              )
            else if (_searchOpen)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [shell.headerTop, shell.headerBottom],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: _closeSearch),
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(19)),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: shell.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (v) => setState(() => _searchQuery = v),
                                textAlignVertical: TextAlignVertical.center,
                                style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textPrimary),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: l10n.transactionSearchHint,
                                  hintStyle: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [shell.headerTop, shell.headerBottom],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                // Matches home_screen.dart's `_Header` rhythm exactly: leading nav icon (there:
                // hamburger menu / here: back arrow) → title (there: "عام" / here: account name)
                // → expanded filler → trailing icon group (search, reports, 3-dot menu) — all
                // read right-to-left in RTL, same as Home.
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20), onPressed: () => context.pop()),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        account.name,
                        style: AppTextStyles.title(context).copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20), onPressed: _openSearch),
                    IconButton(
                      icon: Image.asset('assets/icons/header_document_reference.png', width: 27, height: 27),
                      tooltip: l10n.reportsSheetTitle,
                      onPressed: () => _openReportsSheet(context, ref, l10n, transactions),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      color: shell.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: shell.border)),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditAccount(context);
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref, l10n);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Text(l10n.edit, style: TextStyle(color: shell.textPrimary))),
                        PopupMenuItem(value: 'delete', child: Text(l10n.delete, style: const TextStyle(color: AppColors.debit))),
                      ],
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: AccountActionIconRow(
                    onAddAction: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                    onShare: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                    onMessage: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                    onCurrency: () => AppSnackBar.showError(context, l10n.comingSoonMessage),
                  ),
                ),
                // Only rendered when the account actually has a phone number — sits on the
                // OPPOSITE side of the row from the 4 action icons above.
                if (hasPhone) AccountPhoneRow(phone: account.phone!),
              ],
            ),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(l10n.noTransactionsYet, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TransactionTable(
                        transactions: transactions,
                        searchQuery: _searchQuery,
                        onEditTransaction: (t) => _openEditTransaction(context, t),
                        onDeleteTransaction: (t) => _confirmDeleteTransaction(context, ref, l10n, t),
                      ),
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
