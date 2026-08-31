import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/logic/reports/csv_report_service.dart';
import 'package:dyooni/logic/reports/pdf_report_service.dart';

void main() {
  final service = CsvReportService();

  final clientRow = ReportRow(
    account: Account(id: '1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1)),
    balance: 500,
    transactionCount: 3,
  );
  final supplierRow = ReportRow(
    account: Account(id: '2', name: 'سالم علي', category: AccountCategory.supplier, createdDate: DateTime(2026, 1, 2)),
    balance: -200,
    transactionCount: 1,
  );

  group('build (summary)', () {
    test('output starts with a UTF-8 BOM so Excel renders Arabic correctly', () {
      final bytes = service.build(
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

      expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    });

    test('includes the header row and one row per account with correct direction labels', () {
      final bytes = service.build(
        accountNameHeader: 'Name',
        categoryHeader: 'Category',
        balanceHeader: 'Balance',
        directionHeader: 'Status',
        entriesHeader: 'Entries',
        creditLabel: 'Credit',
        debitLabel: 'Debit',
        clientLabel: 'Client',
        supplierLabel: 'Supplier',
        rows: [clientRow, supplierRow],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');

      expect(lines, hasLength(3));
      expect(lines[0], 'Name,Category,Balance,Status,Entries');
      expect(lines[1], 'أحمد محمد,Client,500.00,Credit,3');
      expect(lines[2], 'سالم علي,Supplier,200.00,Debit,1');
    });

    test('quotes and escapes a field containing a comma', () {
      final rowWithComma = ReportRow(
        account: Account(id: '3', name: 'محمد, أحمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1)),
        balance: 100,
        transactionCount: 1,
      );

      final bytes = service.build(
        accountNameHeader: 'Name',
        categoryHeader: 'Category',
        balanceHeader: 'Balance',
        directionHeader: 'Status',
        entriesHeader: 'Entries',
        creditLabel: 'Credit',
        debitLabel: 'Debit',
        clientLabel: 'Client',
        supplierLabel: 'Supplier',
        rows: [rowWithComma],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      expect(text, contains('"محمد, أحمد"'));
    });

    test('omits any title line when reportTitle is not provided (unchanged default behavior)', () {
      final bytes = service.build(
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

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');
      expect(lines.first, 'Name,Category,Balance,Status,Entries');
    });

    test('writes reportTitle as its own line above the header row when provided', () {
      final bytes = service.build(
        reportTitle: 'إجمالي المبالغ - عام',
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

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');

      expect(lines[0], 'إجمالي المبالغ - عام');
      expect(lines[1], 'Name,Category,Balance,Status,Entries');
      expect(lines, hasLength(3)); // title + header + 1 data row
    });
  });

  group('buildAccountStatement', () {
    final credit = Transaction(
      id: 't1',
      accountId: 'a1',
      amount: 500,
      currency: 'SAR',
      direction: AccountDirection.credit,
      date: DateTime(2026, 1, 1),
      details: 'دفعة أولى',
    );
    final debit = Transaction(
      id: 't2',
      accountId: 'a1',
      amount: 200,
      currency: 'SAR',
      direction: AccountDirection.debit,
      date: DateTime(2026, 1, 5),
      details: 'سحب جزئي',
    );

    test('computes the running balance and a correct totals row', () {
      final bytes = service.buildAccountStatement(
        dateHeader: 'Date',
        detailsHeader: 'Details',
        debitHeader: 'Debit',
        creditHeader: 'Credit',
        balanceHeader: 'Balance',
        totalRowLabel: 'Total',
        attachmentPresentLabel: '(attachment)',
        rows: [
          StatementRow(transaction: credit, runningBalance: 500),
          StatementRow(transaction: debit, runningBalance: 300),
        ],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');

      expect(lines[0], 'Date,Details,Debit,Credit,Balance');
      expect(lines[1], '2026-01-01,دفعة أولى,0,500.00,500.00');
      expect(lines[2], '2026-01-05,سحب جزئي,200.00,0,300.00');
      // totals row: debit total, credit total
      expect(lines[3], ',,200.00,500.00,');
      // final balance row: carries totalRowLabel + the last running balance
      expect(lines[4], ',Total,,,300.00');
    });

    test('appends attachmentPresentLabel to the details column when a transaction has a photo attached', () {
      final withAttachment = Transaction(
        id: 't3',
        accountId: 'a1',
        amount: 150,
        currency: 'SAR',
        direction: AccountDirection.credit,
        date: DateTime(2026, 1, 10),
        details: 'فاتورة',
        attachmentPath: '/tmp/receipt.jpg',
      );

      final bytes = service.buildAccountStatement(
        dateHeader: 'Date',
        detailsHeader: 'Details',
        debitHeader: 'Debit',
        creditHeader: 'Credit',
        balanceHeader: 'Balance',
        totalRowLabel: 'Total',
        attachmentPresentLabel: '(attachment)',
        rows: [StatementRow(transaction: withAttachment, runningBalance: 150)],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');
      expect(lines[1], '2026-01-10,فاتورة (attachment),0,150.00,150.00');
    });

    test('returns just the header row when there are no transactions', () {
      final bytes = service.buildAccountStatement(
        dateHeader: 'Date',
        detailsHeader: 'Details',
        debitHeader: 'Debit',
        creditHeader: 'Credit',
        balanceHeader: 'Balance',
        totalRowLabel: 'Total',
        attachmentPresentLabel: '(attachment)',
        rows: [],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');
      // header + totals row (0,0) + final-balance row (0)
      expect(lines, hasLength(3));
      expect(lines[0], 'Date,Details,Debit,Credit,Balance');
    });

    test('writes reportTitle as its own line above the header row when provided', () {
      final bytes = service.buildAccountStatement(
        reportTitle: 'تقرير كشف الحساب - أحمد محمد',
        dateHeader: 'Date',
        detailsHeader: 'Details',
        debitHeader: 'Debit',
        creditHeader: 'Credit',
        balanceHeader: 'Balance',
        totalRowLabel: 'Total',
        attachmentPresentLabel: '(attachment)',
        rows: [StatementRow(transaction: credit, runningBalance: 500)],
      );

      final text = utf8.decode(bytes.skip(3).toList());
      final lines = text.trim().split('\n');

      expect(lines[0], 'تقرير كشف الحساب - أحمد محمد');
      expect(lines[1], 'Date,Details,Debit,Credit,Balance');
    });
  });
}
