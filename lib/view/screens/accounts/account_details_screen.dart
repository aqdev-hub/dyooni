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
import '../../widgets/accounts/transaction_table.dart';
import '../../widgets/home/bottom_summary_bar.dart';
import '../../widgets/reports/report_options_sheet.dart';
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

  Uint8List _generateStatementCsv(WidgetRef ref, AppLocalizations l10n, List<StatementRow> rows) {
    return ref.read(csvReportServiceProvider).buildAccountStatement(
          dateHeader: l10n.dateLabel,
          detailsHeader: l10n.detailsLabel,
          debitHeader: l10n.directionDebit,
          creditHeader: l10n.directionCredit,
          balanceHeader: l10n.reportBalanceHeader,
          totalRowLabel: l10n.homeTotalBalance,
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
      final bytes = _generateStatementCsv(ref, l10n, rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${account.name}.csv');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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
        final bytes = _generateStatementCsv(ref, l10n, rows);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${account.name}.csv');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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
                  IconButton(
                    icon: Image.asset('assets/icons/header_document_reference.png', width: 27, height: 27),
                    tooltip: l10n.reportsSheetTitle,
                    onPressed: () => _openReportsSheet(context, ref, l10n, transactions),
                  ),
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
