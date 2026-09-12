import 'dart:io';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/logic/reports/pdf_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a non-empty Arabic summary PDF', () async {
    final bytes = await PdfReportService().buildSummaryTotals(
      personalData: PersonalData.dyooniDefault,
      appName: 'ديوني',
      reportTitle: 'تقرير كشف الحساب',
      dateHeader: 'التاريخ',
      directionHeader: 'النوع',
      balanceHeader: 'الرصيد',
      accountNameHeader: 'اسم الحساب',
      creditLabel: 'له',
      debitLabel: 'عليه',
      totalRowLabel: 'الرصيد الإجمالي',
      signatureLabel: 'التوقيع',
      stampLabel: 'الختم',
      rows: [
        ReportRow(
          account: Account(id: 'account-1', name: 'عبدالقدوس', category: AccountCategory.client, createdDate: DateTime(2026, 8, 23)),
          balance: 4900,
          transactionCount: 4,
          lastActivityDate: DateTime(2026, 8, 23),
        ),
      ],
    );

    final output = File('tmp/pdf_review/arabic_report_fixed.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(1000));
  });

  test('generating with signature/stamp enabled but no custom or bundled image never throws', () async {
    // PersonalData.dyooniDefault has signatureEnabled/stampEnabled true with no custom paths —
    // this exercises the fallback-to-bundled-default path (see
    // PdfReportService._loadCustomOrDefaultImage). Even if the default asset files haven't been
    // added to this test environment yet, generation must still succeed (the section is simply
    // omitted rather than crashing) — same "never break the whole report" guarantee as every
    // other optional image in this service.
    final bytes = await PdfReportService().buildSummaryTotals(
      personalData: PersonalData.dyooniDefault,
      appName: 'ديوني',
      reportTitle: 'تقرير تجريبي',
      dateHeader: 'التاريخ',
      directionHeader: 'النوع',
      balanceHeader: 'الرصيد',
      accountNameHeader: 'اسم الحساب',
      creditLabel: 'له',
      debitLabel: 'عليه',
      totalRowLabel: 'الرصيد الإجمالي',
      signatureLabel: 'التوقيع',
      stampLabel: 'الختم',
      rows: const [],
    );

    expect(bytes.length, greaterThan(500));
  });
}
