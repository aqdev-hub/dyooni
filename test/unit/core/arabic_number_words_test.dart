import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/utils/arabic_number_words.dart';

void main() {
  test('zero', () {
    expect(arabicNumberToWords(0), 'صفر');
  });

  test('single digits and teens', () {
    expect(arabicNumberToWords(5), 'خمسة');
    expect(arabicNumberToWords(15), 'خمسة عشر');
  });

  test('tens with a remainder', () {
    expect(arabicNumberToWords(39), 'تسعة وثلاثون');
  });

  test('hundreds', () {
    expect(arabicNumberToWords(300), 'ثلاثمائة');
    expect(arabicNumberToWords(450), 'أربعمائة وخمسون');
  });

  test('thousands, matching the reference example (39000)', () {
    expect(arabicNumberToWords(39000), 'تسعة وثلاثون ألفًا');
  });

  test('thousands with a remainder, matching the reference example (3200)', () {
    expect(arabicNumberToWords(3200), 'ثلاثة آلاف ومائتان');
  });

  test('never throws and never returns empty for any non-negative input', () {
    for (final n in [0, 1, 19, 99, 999, 1000, 999999, 1000000, 2500000]) {
      expect(() => arabicNumberToWords(n), returnsNormally);
      expect(arabicNumberToWords(n), isNotEmpty);
    }
  });
}
