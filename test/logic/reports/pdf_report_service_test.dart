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
}
