/// The five summary-report variants offered on the "التقارير" sheet reached from the Reports
/// screen (all accounts). All five are built by ReportBuilders
/// (logic/reports/tabular_report.dart), which groups every amount per currency — one table each.
enum SummaryReportType {
  totalAmounts,
  allAmountsDetails,
  monthlyTotals,
  categoryAndCurrencyTotals,
  monthlyDetailsForCurrentCategory,
}

/// The two account-statement variants offered on the "التقارير" sheet reached from Account
/// Details (one account): the full [statement] and the [monthlyStatement] (per-month opening and
/// closing balance, built by ReportBuilders.accountMonthlyStatement).
enum AccountReportType {
  statement,
  monthlyStatement,
}

/// Six sort orders, matching the reference's "طريقة ترتيب التقرير" sheet exactly. Applied to
/// whichever list is being reported on (accounts for summary reports, transactions for account
/// statements) before the file is generated.
enum ReportSortOption {
  dateAsc,
  dateDesc,
  balanceAsc,
  balanceDesc,
  nameAsc,
  nameDesc,
}

/// "تصفية حسب الحالة" in the report options: keep only the accounts whose balance, in the
/// reported period, is له / عليه / settled — judged per currency (see
/// ReportBuilders.filterByBalanceState). Not choosing it means everything is reported.
enum ReportStatusFilter { credit, debit, settled }

/// The two exportable file formats, used by the WhatsApp-share format-choice sheet.
enum ReportShareFormat { excel, pdf }
