import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_report_service.dart';
import 'xlsx_report_service.dart';

final pdfReportServiceProvider = Provider<PdfReportService>((ref) => PdfReportService());
final xlsxReportServiceProvider = Provider<XlsxReportService>((ref) => XlsxReportService());
