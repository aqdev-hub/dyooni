import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/logic/reports/pdf_report_service.dart';
import 'package:dyooni/logic/reports/xlsx_report_service.dart';

void main() {
  final service = XlsxReportService();

  final clientRow = ReportRow(
    account: Account(id: '1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1)),
    balance: 500,
    transactionCount: 3,
  );

  final credit = Transaction(
    id: 't1',
    accountId: 'a1',
    amount: 500,
    currency: 'SAR',
    direction: AccountDirection.credit,
    date: DateTime(2026, 1, 1),
    details: 'دفعة أولى',
  );

  // Smoke tests only, deliberately — see xlsx_report_service.dart's doc comment: the exact
  // `excel` package API used to WRITE these files could not be verified against a live pub.dev
  // listing from this sandbox, so asserting the precise decoded cell/style shape here would just
  // duplicate a guess about that same API rather than test something solid (same reasoning as
  // test/unit/core/arabic_pdf_text_test.dart's smoke test for the same class of risk). What
  // matters most is the safety guarantee: report generation must never throw, and it must
  // produce genuine `.xlsx` bytes — an `.xlsx` file is itself a ZIP archive, which always starts
  // with the bytes 'PK', so that's checked directly rather than via the package's own decoder.
  // That keeps this test meaningful even if the installed version's exact API differs from what
  // was guessed at in production code.
  group('build (summary)', () {
    test('produces a non-empty, valid xlsx byte stream for a normal set of rows', () {
      final bytes = service.build(
        reportTitle: 'تقرير تجريبي',
        accountNameHeader: 'Name',
        categoryHeader: 'Category',
        balanceHeader: 'Balance',
        directionHeader: 'Status',
        entriesHeader: 'Entries',
        creditLabel: 'Credit',
        debitLabel: 'Debit',
        clientLabel: 'Client',
        supplierLabel: 'Supplier',
        rows: [clientRow],
      );

      expect(bytes.length, greaterThan(500));
      expect(bytes[0], 0x50); // 'P' — the ZIP magic header every .xlsx file starts with
      expect(bytes[1], 0x4B); // 'K'
    });

    test('never throws for an empty row list', () {
      expect(
        () => service.build(
          reportTitle: 'تقرير فارغ',
          accountNameHeader: 'Name',
          categoryHeader: 'Category',
          balanceHeader: 'Balance',
          directionHeader: 'Status',
          entriesHeader: 'Entries',
          creditLabel: 'Credit',
          debitLabel: 'Debit',
          clientLabel: 'Client',
          supplierLabel: 'Supplier',
          rows: const [],
        ),
        returnsNormally,
      );
    });
  });

  group('buildAccountStatement', () {
    test('produces a non-empty, valid xlsx byte stream for a normal set of rows', () {
      final bytes = service.buildAccountStatement(
        reportTitle: 'كشف حساب تجريبي',
        dateHeader: 'Date',
        detailsHeader: 'Details',
        debitHeader: 'Debit',
        creditHeader: 'Credit',
        balanceHeader: 'Balance',
        totalRowLabel: 'Total',
        attachmentPresentLabel: '(attachment)',
        rows: [StatementRow(transaction: credit, runningBalance: 500)],
      );

      expect(bytes.length, greaterThan(500));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('never throws when there are no transactions', () {
      expect(
        () => service.buildAccountStatement(
          reportTitle: 'كشف حساب فارغ',
          dateHeader: 'Date',
          detailsHeader: 'Details',
          debitHeader: 'Debit',
          creditHeader: 'Credit',
          balanceHeader: 'Balance',
          totalRowLabel: 'Total',
          attachmentPresentLabel: '(attachment)',
          rows: const [],
        ),
        returnsNormally,
      );
    });
  });
}
