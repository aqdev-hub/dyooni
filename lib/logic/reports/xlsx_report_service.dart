import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../data/models/account.dart';
import 'pdf_report_service.dart' show ReportRow, StatementRow;

/// Real, styled `.xlsx` output — a colored/centered table with a report title above it. This
/// replaces `csv_report_service.dart` (deleted this batch — see the delivery notes for why),
/// since plain CSV has NO concept of cell color, centering, or a merged title row at all; there
/// was no way to satisfy that request without switching to a real Excel-writing package.
///
/// ONE IMPORTANT CAVEAT, stated plainly per this project's standing practice for
/// unverifiable dependencies (see pubspec.yaml's notes on `arabic_reshaper`/`file_picker` for the
/// same pattern): the `excel` package has no network-reachable pub.dev listing from this sandbox,
/// so its exact currently-resolving API could not be compiled/verified here before delivery.
/// This file is written against the typed `CellValue`/`ExcelColor` API used by the package's 4.x
/// line, including the `Border`/`BorderStyle` cell-border API added this batch — same risk class
/// as the fill/alignment calls already here, just extended a bit further. **Please run
/// `flutter pub get` immediately and tell me right away if it fails to resolve, or if
/// `flutter analyze` reports type errors in this file** — I'll pin a different version or adjust
/// the API calls the moment I know which one actually installed.
///
/// KNOWN SIMPLIFICATION, stated plainly: the worksheet's own column order is left-to-right
/// (Excel's native default) even though the report content is Arabic — a genuine right-to-left
/// SHEET VIEW is a separate, less certain API in this package that I chose not to guess at on
/// top of the base package-version risk above. The Arabic TEXT inside each cell still renders
/// correctly either way; only the visual column order (leftmost = first column here, versus
/// rightmost = first column in the PDF export) differs from the PDF version.
class XlsxReportService {
  static const _titleFill = '#021534'; // brand navy — matches AppColors.backgroundTop
  static const _titleFont = '#CA8906'; // brand gold — matches AppColors.gold
  static const _headerFill = '#021534';
  static const _headerFont = '#FFFFFF';
  static const _creditFill = '#DCEFE0'; // matches AppColors.creditCell
  static const _debitFill = '#F6D9D2'; // matches AppColors.debitCell
  static const _totalsFill = '#C8E6C9'; // matches PdfColors.green100 used in the PDF export
  static const _gridlineColor = '#C7CDD6'; // thin neutral gray, close to PDF's PdfColors.grey300

  /// One shared thin-gray border, reused on every side of every styled cell below — this is what
  /// makes the sheet read as an actual bordered TABLE rather than just colored blocks of text,
  /// which is what was missing before this batch.
  Border get _gridBorder => Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_gridlineColor));

  /// "إجمالي المبالغ" — one row per account, same column order as the old CSV export (name,
  /// category, balance, direction, entry count). Column widths are sized to each column's actual
  /// content (the account name needs the most room; category/direction are short fixed labels)
  /// instead of one flat width for every column.
  Uint8List build({
    required String reportTitle,
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
    final workbook = Excel.createExcel();
    final sheet = workbook['Report'];
    workbook.delete('Sheet1');

    const columnCount = 5;
    _writeTitleRow(sheet, reportTitle, columnCount);
    _writeHeaderRow(sheet, 1, [accountNameHeader, categoryHeader, balanceHeader, directionHeader, entriesHeader]);

    var rowIndex = 2;
    for (final row in rows) {
      final isCredit = row.balance >= 0;
      _writeDataRow(
        sheet,
        rowIndex,
        [
          row.account.name,
          row.account.category.name == 'client' ? clientLabel : supplierLabel,
          row.balance.abs().toStringAsFixed(0),
          isCredit ? creditLabel : debitLabel,
          row.transactionCount.toString(),
        ],
        fillHex: isCredit ? _creditFill : _debitFill,
      );
      rowIndex++;
    }

    _writeColumnWidths(sheet, [28, 14, 16, 14, 12]);
    return _encode(workbook);
  }

  /// "تقرير كشف الحساب" — the full ledger for ONE account: date, details, debit, credit, running
  /// balance, then a totals row and a final-balance row — same column layout and semantics as the
  /// old CSV export. The details column gets the most width since it holds free-text notes.
  Uint8List buildAccountStatement({
    required String reportTitle,
    required String dateHeader,
    required String detailsHeader,
    required String debitHeader,
    required String creditHeader,
    required String balanceHeader,
    required String totalRowLabel,
    required String attachmentPresentLabel,
    required List<StatementRow> rows,
  }) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Statement'];
    workbook.delete('Sheet1');

    const columnCount = 5;
    _writeTitleRow(sheet, reportTitle, columnCount);
    _writeHeaderRow(sheet, 1, [dateHeader, detailsHeader, debitHeader, creditHeader, balanceHeader]);

    var totalCredit = 0.0;
    var totalDebit = 0.0;
    var rowIndex = 2;
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
      _writeDataRow(
        sheet,
        rowIndex,
        [
          date,
          detailsWithAttachment,
          isCredit ? '0' : row.transaction.amount.toStringAsFixed(0),
          isCredit ? row.transaction.amount.toStringAsFixed(0) : '0',
          row.runningBalance.abs().toStringAsFixed(0),
        ],
        fillHex: isCredit ? _creditFill : _debitFill,
      );
      rowIndex++;
    }

    final finalBalance = rows.isEmpty ? 0.0 : rows.last.runningBalance;
    _writeTotalsRow(sheet, rowIndex, ['', '', totalDebit.toStringAsFixed(0), totalCredit.toStringAsFixed(0), '']);
    rowIndex++;
    _writeTotalsRow(sheet, rowIndex, ['', totalRowLabel, '', '', finalBalance.abs().toStringAsFixed(0)]);

    _writeColumnWidths(sheet, [14, 28, 14, 14, 14]);
    return _encode(workbook);
  }

  Uint8List _encode(Excel workbook) {
    final encoded = workbook.encode();
    if (encoded == null) {
      throw StateError('Failed to encode the Excel workbook');
    }
    return Uint8List.fromList(encoded);
  }

  void _writeColumnWidths(Sheet sheet, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  void _writeTitleRow(Sheet sheet, String title, int columnCount) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: columnCount - 1, rowIndex: 0),
    );
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    cell.value = TextCellValue(title);
    cell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(_titleFill),
      fontColorHex: ExcelColor.fromHexString(_titleFont),
      bold: true,
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: _gridBorder,
      bottomBorder: _gridBorder,
      leftBorder: _gridBorder,
      rightBorder: _gridBorder,
    );
    sheet.setRowHeight(0, 26);
  }

  void _writeHeaderRow(Sheet sheet, int rowIndex, List<String> headers) {
    sheet.setRowHeight(rowIndex, 20);
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(_headerFill),
        fontColorHex: ExcelColor.fromHexString(_headerFont),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _gridBorder,
        bottomBorder: _gridBorder,
        leftBorder: _gridBorder,
        rightBorder: _gridBorder,
      );
    }
  }

  void _writeDataRow(Sheet sheet, int rowIndex, List<String> values, {required String fillHex}) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(values[col]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(fillHex),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _gridBorder,
        bottomBorder: _gridBorder,
        leftBorder: _gridBorder,
        rightBorder: _gridBorder,
      );
    }
  }

  void _writeTotalsRow(Sheet sheet, int rowIndex, List<String> values) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(values[col]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(_totalsFill),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _gridBorder,
        bottomBorder: _gridBorder,
        leftBorder: _gridBorder,
        rightBorder: _gridBorder,
      );
    }
  }
}
