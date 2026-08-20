import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/utils/arabic_pdf_text.dart';

void main() {
  test('shapeArabicForPdf never throws and never returns an empty string for non-empty input', () {
    // Smoke test only — asserting the exact reshaped/reversed output would just duplicate the
    // reshaping library's own logic. What matters here is the safety guarantee: this function
    // must never crash report generation, and must never silently drop the text.
    for (final input in ['أحمد محمد', 'سالم', '123', 'Mixed أحمد 123', '']) {
      expect(() => shapeArabicForPdf(input), returnsNormally);
    }
    expect(shapeArabicForPdf('أحمد'), isNotEmpty);
  });
}
