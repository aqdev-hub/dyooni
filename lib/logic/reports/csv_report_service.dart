import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/account.dart';
import 'pdf_report_service.dart' show ReportRow, StatementRow;

/// Plain CSV, not a true `.xlsx` binary — deliberate choice, see pubspec.yaml comment on why the
/// `excel` package was avoided. A UTF-8 BOM is prepended because Excel specifically (not Sheets)
/// silently mis-renders Arabic text in a BOM-less UTF-8 CSV as garbled characters — this is a
/// well-known, necessary detail, not an oversight.
///
/// KNOWN, STATED LIMITATION on [reportTitle] below: plain CSV has NO concept of cell background
/// color, centered text, merged cells, or bold styling at all — it is literally just delimited
/// text, and no amount of code here can add those without switching the export to a real `.xlsx`
/// writer package (which this project has deliberately avoided so far — see the same pubspec.yaml
/// comment — because its exact API can't be verified from this offline sandbox). What CAN be done
/// honestly in CSV, and is done here, is putting the title on its own line ABOVE the header row,
/// which is what [reportTitle] adds. If real colored/centered cells are wanted, that requires
/// explicitly opting into the `.xlsx`-package risk as a separate, deliberate change.
class CsvReportService {
  /// "إجمالي المبالغ" export — one row per account. [reportTitle], if given, is written as a
  /// single line above the header row (see the class doc comment for what this can and can't do).
  Uint8List build({
    String? reportTitle,
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
    if (reportTitle != null && reportTitle.trim().isNotEmpty) {
      buffer.writeln(_escapeCsvField(reportTitle));
    }
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

    return _withBom(buffer.toString());
  }

  /// "تقرير كشف الحساب" export — the full ledger for ONE account, matching the reference's
  /// column order exactly: date, details, debit, credit, running balance, then a totals row and
  /// a final-balance row. [reportTitle], if given, is written as a single line above the header
  /// row (see the class doc comment for what this can and can't do).
  ///
  /// [attachmentPresentLabel] is appended to a row's details text whenever that transaction has a
  /// photo attached — plain CSV has no way to embed the image itself (the PDF export does, see
  /// pdf_report_service.dart), so this is the honest text-only equivalent: a visible marker
  /// rather than silently losing the fact that a photo exists once exported to CSV/Excel.
  Uint8List buildAccountStatement({
    String? reportTitle,
    required String dateHeader,
    required String detailsHeader,
    required String debitHeader,
    required String creditHeader,
    required String balanceHeader,
    required String totalRowLabel,
    required String attachmentPresentLabel,
    required List<StatementRow> rows,
  }) {
    final buffer = StringBuffer();
    if (reportTitle != null && reportTitle.trim().isNotEmpty) {
      buffer.writeln(_escapeCsvField(reportTitle));
    }
    buffer.writeln(
      [dateHeader, detailsHeader, debitHeader, creditHeader, balanceHeader].map(_escapeCsvField).join(','),
    );

    var totalCredit = 0.0;
    var totalDebit = 0.0;
    for (final row in rows) {
      final isCredit = row.transaction.direction == AccountDirection.credit;
      if (isCredit) {
        totalCredit += row.transaction.amount;
      } else {
        totalDebit += row.transaction.amount;
      }
      final date =
          '${row.transaction.date.year}-${row.transaction.date.month.toString().padLeft(2, '0')}-${row.transaction.date.day.toString().padLeft(2, '0')}';
      final baseDetails = row.transaction.details ?? '—';
      final detailsWithAttachment =
          row.transaction.attachmentPath != null ? '$baseDetails $attachmentPresentLabel' : baseDetails;
      buffer.writeln(
        [
          date,
          detailsWithAttachment,
          isCredit ? '0' : row.transaction.amount.toStringAsFixed(2),
          isCredit ? row.transaction.amount.toStringAsFixed(2) : '0',
          row.runningBalance.abs().toStringAsFixed(2),
        ].map(_escapeCsvField).join(','),
      );
    }

    final finalBalance = rows.isEmpty ? 0.0 : rows.last.runningBalance;
    buffer.writeln(
      ['', '', totalDebit.toStringAsFixed(2), totalCredit.toStringAsFixed(2), '']
          .map(_escapeCsvField)
          .join(','),
    );
    buffer.writeln(
      ['', totalRowLabel, '', '', finalBalance.abs().toStringAsFixed(2)].map(_escapeCsvField).join(','),
    );

    return _withBom(buffer.toString());
  }

  Uint8List _withBom(String content) {
    const utf8Bom = [0xEF, 0xBB, 0xBF];
    return Uint8List.fromList([...utf8Bom, ...utf8.encode(content)]);
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
