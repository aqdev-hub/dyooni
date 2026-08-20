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
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/reports/pdf_report_service.dart';
import '../../../logic/reports/report_export_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/home/summary_card.dart';
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

  List<ReportRow> _buildRows(List<Account> accounts) {
    return [
      for (final account in accounts)
        ReportRow(
          account: account,
          balance: ref.read(accountBalanceProvider(account.id)),
          transactionCount: ref.read(accountTransactionCountProvider(account.id)),
        ),
    ];
  }

  Future<Uint8List> _generatePdf(AppLocalizations l10n, List<ReportRow> rows, double credit, double debit) {
    return ref.read(pdfReportServiceProvider).build(
          appName: l10n.appName,
          reportTitle: l10n.reportsTitle,
          generatedOnLabel: l10n.reportGeneratedOn,
          generalSummaryLabel: l10n.reportsGeneralSummary,
          totalCreditLabel: l10n.homeTotalCredit,
          totalDebitLabel: l10n.homeTotalDebit,
          netLabel: l10n.homeTotalBalance,
          accountNameHeader: l10n.accountNameLabel,
          balanceHeader: l10n.reportBalanceHeader,
          entriesHeader: l10n.reportEntriesHeader,
          totalCredit: credit,
          totalDebit: debit,
          rows: rows,
        );
  }

  Future<void> _exportPdf(AppLocalizations l10n, List<ReportRow> rows, double credit, double debit) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _generatePdf(l10n, rows, credit, debit);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${l10n.reportsTitle}.pdf');
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareViaWhatsapp(AppLocalizations l10n, List<ReportRow> rows, double credit, double debit) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _generatePdf(l10n, rows, credit, debit);
      // Opens the OS's general share sheet (WhatsApp is one option there if installed) — there is
      // no stable cross-platform API to hand a file directly and exclusively to WhatsApp.
      await Printing.sharePdf(bytes: bytes, filename: '${l10n.reportsTitle}.pdf');
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv(AppLocalizations l10n, List<ReportRow> rows) async {
    setState(() => _isExporting = true);
    try {
      final bytes = ref.read(csvReportServiceProvider).build(
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${l10n.reportsTitle}.csv');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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
    final rows = _buildRows(filtered);

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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () => _exportPdf(l10n, rows, overallSummary.totalCredit, overallSummary.totalDebit),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(l10n.reportsExportPdf),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : () => _exportCsv(l10n, rows),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: Text(l10n.reportsExportExcel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _shareViaWhatsapp(l10n, rows, overallSummary.totalCredit, overallSummary.totalDebit),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(l10n.reportsShareWhatsapp),
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
