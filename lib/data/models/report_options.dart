/// The five summary-report variants offered on the "التقارير" sheet reached from the Reports
/// screen (all accounts). Only [totalAmounts] is fully implemented this batch — the other four
/// are real, selectable options in the UI (matching the reference exactly) but generating one of
/// them currently shows an honest "still under development" message instead of silently
/// producing wrong output. See ReportsScreen's doc comment for the full disclosure.
enum SummaryReportType {
  totalAmounts,
  allAmountsDetails,
  monthlyTotals,
  categoryAndCurrencyTotals,
  monthlyDetailsForCurrentCategory,
}

/// The two account-statement variants offered on the "التقارير" sheet reached from Account
/// Details (one account). Only [statement] is fully implemented this batch — see the doc comment
/// on [SummaryReportType] for why [monthlyStatement] is UI-complete but generation-pending.
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

/// The two exportable file formats, used by the WhatsApp-share format-choice sheet.
enum ReportShareFormat { excel, pdf }
