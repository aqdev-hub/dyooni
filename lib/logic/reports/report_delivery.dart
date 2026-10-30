import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../data/models/account.dart';
import '../../data/models/personal_data.dart';
import '../../data/models/transaction.dart';
import '../accounts/accounts_provider.dart';
import '../categories/categories_provider.dart';
import '../currencies/currencies_provider.dart';
import '../settings/direction_labels.dart';
import '../settings/general_settings_provider.dart';
import '../settings/personal_data_provider.dart';
import '../transactions/transactions_provider.dart';
import 'report_export_provider.dart';
import 'tabular_report.dart';

const xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// What to do with a finished report: open the print/save dialog, or hand a file to the system
/// share sheet (WhatsApp, e-mail, Drive… are options there).
enum TabularDelivery { printPdf, sharePdf, shareExcel }

/// Collects every text a report needs from the current language and the person's own settings
/// (renamed له/عليه, category and currency names).
ReportLabels buildReportLabels(WidgetRef ref, AppLocalizations l10n) {
  final settings = ref.read(generalSettingsProvider).value;
  return ReportLabels(
    date: l10n.dateLabel,
    details: l10n.detailsLabel,
    account: l10n.accountNameLabel,
    category: l10n.categoryLabel,
    currency: l10n.currencyLabel,
    month: l10n.reportMonthHeader,
    entries: l10n.reportEntriesHeader,
    accountsCount: l10n.reportAccountsCountHeader,
    credit: resolveCreditLabel(l10n, settings),
    debit: resolveDebitLabel(l10n, settings),
    net: l10n.reportNetHeader,
    balance: l10n.reportBalanceHeader,
    openingBalance: l10n.reportOpeningBalance,
    closingBalance: l10n.reportClosingBalance,
    monthTotal: l10n.reportMonthTotal,
    total: l10n.reportGrandTotal,
    categoryNames: {for (final c in ref.read(categoryTypesProvider)) c.id: c.name},
    currencyNames: {for (final c in ref.read(currencyTypesProvider)) c.id: c.name},
  );
}

String _safeFileName(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();

/// Builds the file for [report] and delivers it. Throws on failure; the caller shows the message.
Future<void> deliverTabularReport(
  WidgetRef ref,
  AppLocalizations l10n,
  TabularReport report, {
  required String fileName,
  required TabularDelivery mode,
}) async {
  final name = _safeFileName(fileName);
  if (mode == TabularDelivery.shareExcel) {
    final bytes = ref.read(xlsxReportServiceProvider).buildTabular(report: report);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: xlsxMimeType)]));
    return;
  }
  final personalData = ref.read(personalDataProvider).value ?? PersonalData.dyooniDefault;
  final bytes = await ref.read(pdfReportServiceProvider).buildTabular(
        personalData: personalData,
        appName: l10n.appName,
        report: report,
        signatureLabel: l10n.reportSignatureLabel,
        stampLabel: l10n.reportStampLabel,
      );
  if (mode == TabularDelivery.printPdf) {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '$name.pdf');
  } else {
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }
}

/// "تصدير جميع البيانات": every account and every entry in one Excel file, handed to the share
/// sheet. Returns `false` when there is nothing to export.
Future<bool> exportAllData(WidgetRef ref, AppLocalizations l10n) async {
  final accounts = ref.read(accountsProvider).value ?? const <Account>[];
  final transactions = ref.read(transactionsProvider).value ?? const <Transaction>[];
  if (accounts.isEmpty && transactions.isEmpty) return false;
  final report = ReportBuilders.fullExport(
    title: l10n.exportAllDataFileTitle,
    accountsHeading: l10n.exportAccountsHeading,
    entriesHeading: l10n.exportEntriesHeading,
    accounts: accounts,
    transactions: transactions,
    labels: buildReportLabels(ref, l10n),
    phoneHeader: l10n.phoneLabel,
    createdHeader: l10n.createdDateLabel,
  );
  final now = DateTime.now();
  final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  await deliverTabularReport(ref, l10n, report, fileName: '${l10n.appName} $stamp', mode: TabularDelivery.shareExcel);
  return true;
}
