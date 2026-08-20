import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/data/models/account.dart';
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

    final text = utf8.decode(bytes.skip(3).toList()); // strip the BOM before decoding as text
    final lines = text.trim().split('\n');

    expect(lines, hasLength(3)); // header + 2 rows
    expect(lines[0], 'Name,Category,Balance,Status,Entries');
    expect(lines[1], 'أحمد محمد,Client,500.00,Credit,3');
    expect(lines[2], 'سالم علي,Supplier,200.00,Debit,1'); // balance.abs() — negative sign dropped
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

  test('returns just the header row when there are no accounts', () {
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
      rows: [],
    );

    final text = utf8.decode(bytes.skip(3).toList());
    expect(text.trim().split('\n'), hasLength(1));
  });
}
