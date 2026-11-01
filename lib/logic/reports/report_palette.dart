import 'package:pdf/pdf.dart';

/// The colours of the PDF reports — the app's navy and gold, with enough contrast to print
/// well. (The Excel writer repeats the same hex values; keep the two in step.)
class ReportPalette {
  const ReportPalette._();

  static const navy = PdfColor.fromInt(0xFF0B2A6B); // table header row / titles
  static const headingFill = PdfColor.fromInt(0xFFF0C24B); // gold band above each table
  static const totalFill = PdfColor.fromInt(0xFFFFE08A); // total rows
  static const subtleFill = PdfColor.fromInt(0xFFD5DDF2); // carry-over lines
  static const zebraFill = PdfColor.fromInt(0xFFEAF0FF); // every second line
  static const border = PdfColor.fromInt(0xFF8FA3D1);
}
