import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/arabic_pdf_text.dart';
import '../../data/models/account.dart';

class ReportRow {
  const ReportRow({required this.account, required this.balance, required this.transactionCount});
  final Account account;
  final double balance;
  final int transactionCount;
}

/// Builds the PDF report document as bytes, ready for `Printing.layoutPdf`/`sharePdf`.
///
/// Uses the low-level `pw.Table`/`pw.TableRow` widgets directly rather than the `fromTextArray`
/// convenience helper — that helper's exact class name has moved between `pdf` package major
/// versions, while the plain `Table`/`TableRow` widgets have been stable for a long time; this
/// avoids one more version-sensitive API in a batch that already has one (see arabic_pdf_text.dart).
///
/// KNOWN LIMITATION: [shapeArabicForPdf] reorders whole strings for correct right-to-left
/// display, which only gives correct results for fields that are purely Arabic letters. It is
/// deliberately applied only to the account-name column here — never to amounts or dates, which
/// must stay in normal left-to-right digit order. An account name that mixes Arabic and digits
/// (e.g. "فرع 2") would still shape imperfectly; a full bidi implementation is out of scope for
/// this batch.
class PdfReportService {
  Future<Uint8List> build({
    required String appName,
    required String reportTitle,
    required String generatedOnLabel,
    required String generalSummaryLabel,
    required String totalCreditLabel,
    required String totalDebitLabel,
    required String netLabel,
    required String accountNameHeader,
    required String balanceHeader,
    required String entriesHeader,
    required double totalCredit,
    required double totalDebit,
    required List<ReportRow> rows,
  }) async {
    final regularFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(shapeArabicForPdf(appName), style: pw.TextStyle(font: boldFont, fontSize: 20)),
            pw.Text(shapeArabicForPdf(reportTitle), style: pw.TextStyle(font: regularFont, fontSize: 14)),
            pw.Text(
              '$generatedOnLabel $dateStr',
              style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.Text(shapeArabicForPdf(generalSummaryLabel), style: pw.TextStyle(font: boldFont, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryCell(shapeArabicForPdf(totalCreditLabel), totalCredit.toStringAsFixed(0), PdfColors.green700, regularFont),
              _summaryCell(shapeArabicForPdf(totalDebitLabel), totalDebit.toStringAsFixed(0), PdfColors.red700, regularFont),
              _summaryCell(shapeArabicForPdf(netLabel), (totalCredit - totalDebit).toStringAsFixed(0), PdfColors.blueGrey800, regularFont),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _headerCell(shapeArabicForPdf(entriesHeader), boldFont),
                  _headerCell(shapeArabicForPdf(balanceHeader), boldFont),
                  _headerCell(shapeArabicForPdf(accountNameHeader), boldFont),
                ],
              ),
              for (final row in rows)
                pw.TableRow(
                  children: [
                    _bodyCell(row.transactionCount.toString(), regularFont),
                    _bodyCell(row.balance.abs().toStringAsFixed(0), regularFont),
                    _bodyCell(shapeArabicForPdf(row.account.name), regularFont),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _summaryCell(String label, String value, PdfColor color, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 16, color: color)),
      ],
    );
  }

  pw.Widget _headerCell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
      );

  pw.Widget _bodyCell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
      );
}
