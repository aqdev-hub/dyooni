import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/reports/pdf_report_service.dart';
import '../../../logic/reports/report_export_provider.dart';
import '../../../logic/settings/personal_data_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/home/summary_card.dart';
import '../../widgets/reports/report_options_sheet.dart';
import '../../widgets/shared/app_snackbar.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // Deliberately a LOCAL filter, separate from Home's `selectedCategoryProvider` — switching
  // this filter must never leak back and change what Home shows, and vice versa.
  AccountCategory? _categoryFilter;
  bool _isExporting = false;

  String _categoryLabel(AppLocalizations l10n) => switch (_categoryFilter) {
        null => l10n.homeTabGeneral,
        AccountCategory.client => l10n.homeTabClients,
        AccountCategory.supplier => l10n.homeTabSuppliers,
      };

  List<ReportRow> _buildSummaryRows(List<Account> accounts, DateTimeRange? range, ReportSortOption? sort) {
    final allTx = ref.read(transactionsProvider).value ?? const [];
    final rows = <ReportRow>[];
    for (final account in accounts) {
      var accountTx = allTx.where((t) => t.accountId == account.id).toList();
      if (range != null) {
        accountTx = accountTx.where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end)).toList();
      }
      var balance = 0.0;
      DateTime? lastDate;
      for (final t in accountTx) {
        balance += t.direction == AccountDirection.credit ? t.amount : -t.amount;
        if (lastDate == null || t.date.isAfter(lastDate)) lastDate = t.date;
      }
      rows.add(ReportRow(account: account, balance: balance, transactionCount: accountTx.length, lastActivityDate: lastDate));
    }
    if (sort != null) {
      switch (sort) {
        case ReportSortOption.dateAsc:
          rows.sort((a, b) => (a.lastActivityDate ?? DateTime(1970)).compareTo(b.lastActivityDate ?? DateTime(1970)));
        case ReportSortOption.dateDesc:
          rows.sort((a, b) => (b.lastActivityDate ?? DateTime(1970)).compareTo(a.lastActivityDate ?? DateTime(1970)));
        case ReportSortOption.balanceAsc:
          rows.sort((a, b) => a.balance.compareTo(b.balance));
        case ReportSortOption.balanceDesc:
          rows.sort((a, b) => b.balance.compareTo(a.balance));
        case ReportSortOption.nameAsc:
          rows.sort((a, b) => a.account.name.compareTo(b.account.name));
        case ReportSortOption.nameDesc:
          rows.sort((a, b) => b.account.name.compareTo(a.account.name));
      }
    }
    return rows;
  }

  Future<Uint8List> _generateSummaryPdf(AppLocalizations l10n, List<ReportRow> rows) {
    final personalData = ref.read(personalDataProvider).value ?? PersonalData.dyooniDefault;
    return ref.read(pdfReportServiceProvider).buildSummaryTotals(
          personalData: personalData,
          appName: l10n.appName,
          reportTitle: '${l10n.reportTypeTotalAmounts} - ${_categoryLabel(l10n)}',
          dateHeader: l10n.dateLabel,
          directionHeader: l10n.reportStatusHeader,
          balanceHeader: l10n.reportBalanceHeader,
          accountNameHeader: l10n.accountNameLabel,
          creditLabel: l10n.directionCredit,
          debitLabel: l10n.directionDebit,
          totalRowLabel: l10n.homeTotalBalance,
          rows: rows,
        );
  }

  Uint8List _generateSummaryCsv(AppLocalizations l10n, List<ReportRow> rows) {
    return ref.read(csvReportServiceProvider).build(
          accountNameHeader: l10n.accountNameLabel,
          categoryHeader: l10n.categoryLabel,
          balanceHeader: l10n.reportBalanceHeader,
          directionHeader: l10n.reportStatusHeader,
          entriesHeader: l10n.reportEntriesHeader,
          creditLabel: l10n.directionCredit,
          debitLabel: l10n.directionDebit,
          clientLabel: l10n.categoryClient,
          supplierLabel: l10n.categorySupplier,
          rows: rows,
        );
  }

  List<Account> _filteredAccounts() {
    final accounts = ref.read(accountsProvider).value ?? const [];
    return _categoryFilter == null ? accounts : accounts.where((a) => a.category == _categoryFilter).toList();
  }

  Future<void> _handleGeneratePdf(SummaryReportType type, ReportSortOption? sort, DateTimeRange? range) async {
    final l10n = AppLocalizations.of(context)!;
    if (type != SummaryReportType.totalAmounts) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final rows = _buildSummaryRows(_filteredAccounts(), range, sort);
      final bytes = await _generateSummaryPdf(l10n, rows);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${l10n.reportsTitle}.pdf');
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleGenerateExcel(SummaryReportType type, ReportSortOption? sort, DateTimeRange? range) async {
    final l10n = AppLocalizations.of(context)!;
    if (type != SummaryReportType.totalAmounts) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final rows = _buildSummaryRows(_filteredAccounts(), range, sort);
      final bytes = _generateSummaryCsv(l10n, rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${l10n.reportsTitle}.csv');
      await file.writeAsBytes(bytes);
      // Explicit mimeType — without it, some spreadsheet/office apps' share-receiver dumps the raw
      // text into a single column instead of running their normal CSV-delimiter import.
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleShareViaWhatsapp(
    SummaryReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
    ReportShareFormat format,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (type != SummaryReportType.totalAmounts) {
      AppSnackBar.showError(context, l10n.reportFeatureNotReadyMessage);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final rows = _buildSummaryRows(_filteredAccounts(), range, sort);
      if (format == ReportShareFormat.pdf) {
        final bytes = await _generateSummaryPdf(l10n, rows);
        // Opens the OS's general share sheet (WhatsApp is one option there if installed) — there
        // is no stable cross-platform API to hand a file directly and exclusively to WhatsApp.
        await Printing.sharePdf(bytes: bytes, filename: '${l10n.reportsTitle}.pdf');
      } else {
        final bytes = _generateSummaryCsv(l10n, rows);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${l10n.reportsTitle}.csv');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
      }
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _openReportsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportOptionsSheet<SummaryReportType>(
        initialType: SummaryReportType.totalAmounts,
        options: [
          (SummaryReportType.totalAmounts, l10n.reportTypeTotalAmounts),
          (SummaryReportType.allAmountsDetails, l10n.reportTypeAllAmountsDetails),
          (SummaryReportType.monthlyTotals, l10n.reportTypeMonthlyTotals),
          (SummaryReportType.categoryAndCurrencyTotals, l10n.reportTypeCategoryAndCurrencyTotals),
          (SummaryReportType.monthlyDetailsForCurrentCategory, l10n.reportTypeMonthlyDetailsCurrentCategory),
        ],
        onGeneratePdf: _handleGeneratePdf,
        onGenerateExcel: _handleGenerateExcel,
        onShareViaWhatsapp: _handleShareViaWhatsapp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final overallSummary = ref.watch(overallSummaryProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final filtered = _categoryFilter == null
        ? accounts
        : accounts.where((a) => a.category == _categoryFilter).toList();

    return Scaffold(
      backgroundColor: shell.background,
      appBar: AppBar(
        backgroundColor: shell.headerBottom,
        foregroundColor: Colors.white,
        title: Text(l10n.reportsTitle),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SummaryCard(summary: overallSummary, title: l10n.reportsGeneralSummary),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _openReportsSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: shell.accent,
                    foregroundColor: shell.headerBottom,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.reportsSheetTitle, style: AppTextStyles.button(context).copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 20),
                Text(l10n.reportsAccountsBreakdown, style: AppTextStyles.title(context).copyWith(fontSize: 15, color: shell.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _FilterChip(
                      label: l10n.reportsFilterAll,
                      selected: _categoryFilter == null,
                      onTap: () => setState(() => _categoryFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.homeTabClients,
                      selected: _categoryFilter == AccountCategory.client,
                      onTap: () => setState(() => _categoryFilter = AccountCategory.client),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.homeTabSuppliers,
                      selected: _categoryFilter == AccountCategory.supplier,
                      onTap: () => setState(() => _categoryFilter = AccountCategory.supplier),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(l10n.reportsEmpty, style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary)),
                    ),
                  )
                else
                  for (final account in filtered) _AccountReportRow(account: account),
              ],
            ),
            if (_isExporting)
              Container(
                color: Colors.black.withValues(alpha: 0.15),
                child: Center(child: CircularProgressIndicator(color: shell.accent)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? shell.accent : shell.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? shell.accent : shell.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySecondary(context).copyWith(
            color: selected ? Colors.white : shell.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _AccountReportRow extends ConsumerWidget {
  const _AccountReportRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final balance = ref.watch(accountBalanceProvider(account.id));
    final count = ref.watch(accountTransactionCountProvider(account.id));
    final isCredit = balance >= 0;
    final color = isCredit ? AppColors.credit : AppColors.debit;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: shell.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: AppTextStyles.body(context).copyWith(color: shell.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  l10n.homeTransactionsCount(count),
                  style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            balance.abs().toStringAsFixed(0),
            style: AppTextStyles.body(context).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
