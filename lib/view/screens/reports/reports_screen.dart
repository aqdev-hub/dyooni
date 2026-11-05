
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';
import '../../../data/models/account.dart';
import '../../../data/models/report_options.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/accounts/accounts_provider.dart';
import '../../../logic/categories/categories_provider.dart';
import '../../../data/models/category_type.dart';
import '../../../logic/reports/report_delivery.dart';
import '../../../logic/reports/tabular_report.dart';
import '../../../logic/settings/direction_labels.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../../logic/transactions/transactions_provider.dart';
import '../../widgets/home/summary_card.dart';
import '../../widgets/shared/app_screen_chrome.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/reports/report_options_sheet.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/main_bottom_nav.dart';

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

  /// Written by the report-options sheet ("تصفية حسب الحالة"), read when a report is generated.
  final ValueNotifier<ReportStatusFilter?> _statusFilter = ValueNotifier(null);

  @override
  void dispose() {
    _statusFilter.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l10n) =>
      categoryNameOf(ref.read(categoryTypesProvider), _categoryFilter?.id ?? generalCategoryId);

  List<Account> _filteredAccounts() {
    final accounts = ref.read(accountsProvider).value ?? const [];
    return _categoryFilter == null ? accounts : accounts.where((a) => a.category == _categoryFilter).toList();
  }

  Future<void> _handleGeneratePdf(SummaryReportType type, ReportSortOption? sort, DateTimeRange? range) =>
      _handleTabular(type, sort, range, TabularDelivery.printPdf);

  Future<void> _handleGenerateExcel(SummaryReportType type, ReportSortOption? sort, DateTimeRange? range) =>
      _handleTabular(type, sort, range, TabularDelivery.shareExcel);

  Future<void> _handleShareViaWhatsapp(
    SummaryReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
    ReportShareFormat format,
  ) =>
      _handleTabular(type, sort, range, format == ReportShareFormat.pdf ? TabularDelivery.sharePdf : TabularDelivery.shareExcel);

  String _typeTitle(AppLocalizations l10n, SummaryReportType type) => switch (type) {
        SummaryReportType.totalAmounts => l10n.reportTypeTotalAmounts,
        SummaryReportType.allAmountsDetails => l10n.reportTypeAllAmountsDetails,
        SummaryReportType.monthlyTotals => l10n.reportTypeMonthlyTotals,
        SummaryReportType.categoryAndCurrencyTotals => l10n.reportTypeCategoryAndCurrencyTotals,
        SummaryReportType.monthlyDetailsForCurrentCategory => l10n.reportTypeMonthlyDetailsCurrentCategory,
      };

  /// All the summary reports. They are built as plain tables ([TabularReport]) so PDF,
  /// Excel and sharing all come from the same data. Amounts are always grouped per currency.
  Future<void> _handleTabular(
    SummaryReportType type,
    ReportSortOption? sort,
    DateTimeRange? range,
    TabularDelivery mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    try {
      final labels = buildReportLabels(ref, l10n);
      final accounts = _filteredAccounts();
      final from = range?.start;
      final to = range?.end;
      final transactions = ReportBuilders.filterByBalanceState(
        ref.read(transactionsProvider).value ?? const <Transaction>[],
        _statusFilter.value,
        from: from,
        to: to,
      );
      final title = '${_typeTitle(l10n, type)} - ${_categoryLabel(l10n)}';
      final report = switch (type) {
        SummaryReportType.allAmountsDetails => ReportBuilders.allAmountsDetails(
            title: title, accounts: accounts, transactions: transactions, labels: labels, from: from, to: to, sort: sort),
        SummaryReportType.monthlyTotals => ReportBuilders.monthlyTotals(
            title: title, accounts: accounts, transactions: transactions, labels: labels, from: from, to: to, sort: sort),
        SummaryReportType.categoryAndCurrencyTotals => ReportBuilders.categoryAndCurrencyTotals(
            title: title, accounts: accounts, transactions: transactions, labels: labels, from: from, to: to, sort: sort),
        SummaryReportType.monthlyDetailsForCurrentCategory => ReportBuilders.monthlyDetails(
            title: title, accounts: accounts, transactions: transactions, labels: labels, from: from, to: to, sort: sort),
        SummaryReportType.totalAmounts => ReportBuilders.accountTotals(
            title: title, accounts: accounts, transactions: transactions, labels: labels, from: from, to: to, sort: sort),
      };
      if (report.isEmpty) {
        if (mounted) AppSnackBar.showError(context, l10n.reportNoDataMessage);
        return;
      }
      await deliverTabularReport(ref, l10n, report, fileName: title, mode: mode);
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, l10n.exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _openReportsSheet() async {
    final l10n = AppLocalizations.of(context)!;
    _statusFilter.value = null; // every time the sheet opens, start without a status filter
    final settings = ref.read(generalSettingsProvider).value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportOptionsSheet<SummaryReportType>(
        initialType: SummaryReportType.totalAmounts,
        statusFilter: _statusFilter,
        creditLabel: resolveCreditLabel(l10n, settings),
        debitLabel: resolveDebitLabel(l10n, settings),
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

    return AppScaffold(
      drawer: const AppDrawer(),
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: context.voicePalette.headerGold, size: 30),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.reportsTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline(context).copyWith(color: context.voicePalette.headerGold, fontSize: 21, height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
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
                // "الكل" + one chip per category from إدارة التصنيفات (hidden-from-Home ones included).
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: l10n.reportsFilterAll,
                      selected: _categoryFilter == null,
                      onTap: () => setState(() => _categoryFilter = null),
                    ),
                    for (final c in ref.watch(assignableCategoriesProvider))
                      _FilterChip(
                        label: c.name,
                        selected: _categoryFilter?.id == c.id,
                        onTap: () => setState(() => _categoryFilter = AccountCategory(c.id)),
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
            MainBottomNav(
              activeTab: MainNavTab.reports,
              onHome: () => context.go('/home'),
              // Tab-like: replace this screen (back from voice then returns to Home, not Reports).
              onVoice: () => context.pushReplacement('/voice'),
              onVoiceLongPress: () => context.pushReplacement('/voice', extra: true),
              onReports: () {},
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
