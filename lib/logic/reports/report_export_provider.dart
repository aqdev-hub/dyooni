import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'csv_report_service.dart';
import 'pdf_report_service.dart';

final pdfReportServiceProvider = Provider<PdfReportService>((ref) => PdfReportService());
final csvReportServiceProvider = Provider<CsvReportService>((ref) => CsvReportService());
