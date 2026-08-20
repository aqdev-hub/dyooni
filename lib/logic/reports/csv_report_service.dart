import 'dart:convert';
import 'dart:typed_data';

import 'pdf_report_service.dart' show ReportRow;

/// Plain CSV, not a true `.xlsx` binary — deliberate choice, see pubspec.yaml comment on why the
/// `excel` package was avoided this batch. A UTF-8 BOM is prepended because Excel specifically
/// (not Sheets) silently mis-renders Arabic text in a BOM-less UTF-8 CSV as garbled characters —
/// this is a well-known, necessary detail, not an oversight.
class CsvReportService {
  Uint8List build({
    required String accountNameHeader,
    required String categoryHeader,
    required String balanceHeader,
    required String directionHeader,
    required String entriesHeader,
    required String creditLabel,
    required String debitLabel,
    required String clientLabel,
    required String supplierLabel,
    required List<ReportRow> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      [accountNameHeader, categoryHeader, balanceHeader, directionHeader, entriesHeader]
          .map(_escapeCsvField)
          .join(','),
    );

    for (final row in rows) {
      final isCredit = row.balance >= 0;
      buffer.writeln(
        [
          row.account.name,
          row.account.category.name == 'client' ? clientLabel : supplierLabel,
          row.balance.abs().toStringAsFixed(2),
          isCredit ? creditLabel : debitLabel,
          row.transactionCount.toString(),
        ].map(_escapeCsvField).join(','),
      );
    }

    const utf8Bom = [0xEF, 0xBB, 0xBF];
    return Uint8List.fromList([...utf8Bom, ...utf8.encode(buffer.toString())]);
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
