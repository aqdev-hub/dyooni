import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/arabic_pdf_text.dart';
import '../../data/models/account.dart';
import '../../data/models/personal_data.dart';
import '../../data/models/transaction.dart';

/// One row of the "إجمالي المبالغ" (summary totals) report — one line per account.
class ReportRow {
  const ReportRow({
    required this.account,
    required this.balance,
    required this.transactionCount,
    this.lastActivityDate,
  });
  final Account account;
  final double balance;
  final int transactionCount;
  final DateTime? lastActivityDate;
}

/// One row of the "تقرير كشف الحساب" (account statement) report — one line per transaction,
/// with the running balance already computed by the caller (see TransactionTable's identical
/// chronological + running-balance logic, which this mirrors on purpose so the PDF/screen never
/// disagree).
class StatementRow {
  const StatementRow({required this.transaction, required this.runningBalance});
  final Transaction transaction;
  final double runningBalance;
}

/// Builds PDF report documents as bytes, ready for `Printing.layoutPdf`/`sharePdf`.
///
/// Uses the low-level `pw.Table`/`pw.TableRow` widgets directly rather than the `fromTextArray`
/// convenience helper — that helper's exact class name has moved between `pdf` package major
/// versions, while the plain `Table`/`TableRow` widgets have been stable for a long time; this
/// avoids one more version-sensitive API (see arabic_pdf_text.dart for the other one).
///
/// KNOWN LIMITATION: [shapeArabicForPdf] reorders whole strings for correct right-to-left
/// display, which only gives correct results for fields that are purely Arabic letters. It is
/// deliberately applied only to Arabic-only fields here — never to amounts, dates, phone numbers,
/// or the English identity block, which must stay in normal left-to-right order.
class PdfReportService {
  Future<(pw.Font, pw.Font)> _loadFonts() async {
    final regularFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    return (pw.Font.ttf(regularFontData), pw.Font.ttf(boldFontData));
  }

  Future<pw.MemoryImage> _loadLogo(PersonalData personalData) async {
    try {
      if (personalData.logoPath != null) {
        return pw.MemoryImage(await File(personalData.logoPath!).readAsBytes());
      }
    } catch (_) {
      // Falls through to the bundled default below — a broken/missing custom logo file must
      // never stop the whole report from generating.
    }
    final data = await rootBundle.load('assets/icons/app_logo.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  /// Preloads each row's transaction attachment (if any) as a [pw.MemoryImage], keyed by
  /// transaction id. Done as a separate async pass BEFORE the (synchronous) table-building code
  /// below, since `pw.Document.addPage`'s `build:` callback itself can't be async. A missing or
  /// unreadable attachment file is skipped — same "never break the whole report over one bad
  /// file" principle as [_loadLogo].
  Future<Map<String, pw.MemoryImage>> _loadAttachments(List<StatementRow> rows) async {
    final images = <String, pw.MemoryImage>{};
    for (final row in rows) {
      final path = row.transaction.attachmentPath;
      if (path == null) continue;
      try {
        final bytes = await File(path).readAsBytes();
        images[row.transaction.id] = pw.MemoryImage(bytes);
      } catch (_) {
        // Attachment file missing/unreadable — the row still renders, just without the thumbnail.
      }
    }
    return images;
  }

  /// The bilingual identity block used at the top of every report: English details on the left,
  /// the app/business logo in the middle, Arabic details on the right — all sourced from
  /// [PersonalData], never hardcoded. [reportTitle] renders underlined below it.
  pw.Widget _buildHeader({
    required PersonalData personalData,
    required pw.MemoryImage logo,
    required String reportTitle,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    pw.Widget contactLine(String value, {required pw.CrossAxisAlignment align}) => pw.Text(
          value,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey700),
        );

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          // The whole document is RTL (see MultiPage below), so a Row's FIRST child renders on
          // the page's RIGHT and its LAST child renders on the LEFT. The Arabic identity block
          // is listed FIRST here so it lands on the right, and the English block is listed LAST
          // so it lands on the left — exactly the "Arabic right / English left" letterhead layout
          // requested. (This was previously backwards: English was first, so RTL ordering put it
          // on the right and Arabic on the left — the opposite of what was intended.)
          children: [
            pw.Expanded(
              child: pw.Column(
                // `.start` under RTL means "right-aligned" — keeps the Arabic text flush to the
                // page's outer right edge, the natural letterhead look for this column's position.
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shapeArabicForPdf(personalData.nameAr), style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text(shapeArabicForPdf(personalData.addressAr), style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey700)),
                  if (personalData.phone.isNotEmpty) contactLine(personalData.phone, align: pw.CrossAxisAlignment.start),
                  contactLine(personalData.email, align: pw.CrossAxisAlignment.start),
                ],
              ),
            ),
            pw.Container(
              width: 60,
              height: 60,
              decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle),
              child: pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.cover)),
            ),
            pw.Expanded(
              child: pw.Column(
                // `.end` under RTL means "left-aligned" — both the correct natural reading
                // alignment for English text AND flush to this column's outer (left) page edge.
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(personalData.nameEn, style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.SizedBox(height: 2),
                  contactLine(personalData.addressEn, align: pw.CrossAxisAlignment.end),
                  if (personalData.phone.isNotEmpty) contactLine(personalData.phone, align: pw.CrossAxisAlignment.end),
                  contactLine(personalData.email, align: pw.CrossAxisAlignment.end),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          shapeArabicForPdf(reportTitle),
          style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.blueGrey800, decoration: pw.TextDecoration.underline),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _footer(pw.Context context, String appName, pw.Font font) {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
          pw.Text(
            shapeArabicForPdf(appName),
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600, decoration: pw.TextDecoration.underline),
          ),
        ],
      ),
    );
  }

  /// "إجمالي المبالغ" — one row per account (name, direction, balance, last activity date), plus
  /// a highlighted totals row, matching the reference report's exact column set.
  Future<Uint8List> buildSummaryTotals({
    required PersonalData personalData,
    required String appName,
    required String reportTitle,
    required String dateHeader,
    required String directionHeader,
    required String balanceHeader,
    required String accountNameHeader,
    required String creditLabel,
    required String debitLabel,
    required String totalRowLabel,
    required List<ReportRow> rows,
  }) async {
    final (regularFont, boldFont) = await _loadFonts();
    final logo = await _loadLogo(personalData);
    final doc = pw.Document();

    var totalCredit = 0.0;
    var totalDebit = 0.0;
    for (final row in rows) {
      if (row.balance >= 0) {
        totalCredit += row.balance;
      } else {
        totalDebit += -row.balance;
      }
    }
    final net = totalCredit - totalDebit;

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        header: (context) => _buildHeader(
          personalData: personalData,
          logo: logo,
          reportTitle: reportTitle,
          regularFont: regularFont,
          boldFont: boldFont,
        ),
        footer: (context) => _footer(context, appName, regularFont),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _headerCell(shapeArabicForPdf(accountNameHeader), boldFont),
                  _headerCell(shapeArabicForPdf(balanceHeader), boldFont),
                  _headerCell(shapeArabicForPdf(directionHeader), boldFont),
                  _headerCell(shapeArabicForPdf(dateHeader), boldFont),
                ],
              ),
              for (final row in rows)
                pw.TableRow(
                  children: [
                    _bodyCell(shapeArabicForPdf(row.account.name), regularFont),
                    _bodyCell(row.balance.abs().toStringAsFixed(0), regularFont),
                    _bodyCell(shapeArabicForPdf(row.balance >= 0 ? creditLabel : debitLabel), regularFont),
                    _bodyCell(_formatDate(row.lastActivityDate), regularFont),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  _headerCellPlain(shapeArabicForPdf(totalRowLabel), boldFont, PdfColors.black),
                  _bodyCellBold(net.abs().toStringAsFixed(0), boldFont),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// "تقرير كشف الحساب" — the full transaction ledger for ONE account: date, details, debit,
  /// credit, running balance — plus a highlighted final-balance row. Rows whose transaction has a
  /// photo attached also show a small thumbnail next to the details text (see [_loadAttachments]).
  Future<Uint8List> buildAccountStatement({
    required PersonalData personalData,
    required String appName,
    required String reportTitle,
    required String dateHeader,
    required String detailsHeader,
    required String debitHeader,
    required String creditHeader,
    required String balanceHeader,
    required String totalRowLabel,
    required List<StatementRow> rows,
  }) async {
    final (regularFont, boldFont) = await _loadFonts();
    final logo = await _loadLogo(personalData);
    final attachmentImages = await _loadAttachments(rows);
    final doc = pw.Document();

    var totalCredit = 0.0;
    var totalDebit = 0.0;
    for (final row in rows) {
      if (row.transaction.direction == AccountDirection.credit) {
        totalCredit += row.transaction.amount;
      } else {
        totalDebit += row.transaction.amount;
      }
    }
    final finalBalance = rows.isEmpty ? 0.0 : rows.last.runningBalance;

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        header: (context) => _buildHeader(
          personalData: personalData,
          logo: logo,
          reportTitle: reportTitle,
          regularFont: regularFont,
          boldFont: boldFont,
        ),
        footer: (context) => _footer(context, appName, regularFont),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _headerCell(shapeArabicForPdf(balanceHeader), boldFont),
                  _headerCell(shapeArabicForPdf(creditHeader), boldFont),
                  _headerCell(shapeArabicForPdf(debitHeader), boldFont),
                  _headerCell(shapeArabicForPdf(detailsHeader), boldFont),
                  _headerCell(shapeArabicForPdf(dateHeader), boldFont),
                ],
              ),
              for (final row in rows)
                pw.TableRow(
                  children: [
                    _bodyCell(row.runningBalance.abs().toStringAsFixed(0), regularFont),
                    _bodyCell(
                      row.transaction.direction == AccountDirection.credit ? row.transaction.amount.toStringAsFixed(0) : '0',
                      regularFont,
                    ),
                    _bodyCell(
                      row.transaction.direction == AccountDirection.debit ? row.transaction.amount.toStringAsFixed(0) : '0',
                      regularFont,
                    ),
                    _detailsCellWithAttachment(
                      shapeArabicForPdf(row.transaction.details ?? '—'),
                      regularFont,
                      attachmentImages[row.transaction.id],
                    ),
                    _bodyCell(_formatDate(row.transaction.date), regularFont),
                  ],
                ),
              pw.TableRow(
                children: [
                  pw.SizedBox(),
                  _bodyCellBold(totalCredit.toStringAsFixed(0), boldFont),
                  _bodyCellBold(totalDebit.toStringAsFixed(0), boldFont),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  _bodyCellBold(finalBalance.abs().toStringAsFixed(0), boldFont),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  _headerCellPlain(shapeArabicForPdf(totalRowLabel), boldFont, PdfColors.black),
                  pw.SizedBox(),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  pw.Widget _headerCell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white)),
      );

  pw.Widget _headerCellPlain(String text, pw.Font font, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, color: color)),
      );

  pw.Widget _bodyCell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
      );

  /// Same as [_bodyCell] but also places a small thumbnail next to the text when [image] is
  /// non-null — this is the only cell that ever carries an attachment thumbnail.
  pw.Widget _detailsCellWithAttachment(String text, pw.Font font, pw.MemoryImage? image) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Flexible(child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
            if (image != null) ...[
              pw.SizedBox(width: 4),
              pw.Container(
                width: 22,
                height: 22,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                child: pw.Image(image, fit: pw.BoxFit.cover),
              ),
            ],
          ],
        ),
      );

  pw.Widget _bodyCellBold(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );
}
