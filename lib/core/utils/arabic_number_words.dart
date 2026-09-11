/// Converts a non-negative integer amount to Arabic words, matching the reference's helper text
/// under the amount field (e.g. 39000 -> "تسعة وثلاثون ألفًا"). Covers the range that a debt
/// amount realistically falls in (0 to low millions) using standard Arabic numeral-word rules.
///
/// KNOWN LIMITATION: full Arabic numeral grammar has gender agreement (مذكر/مؤنث) that depends on
/// the noun being counted (e.g. "ريال" is masculine, "ليرة" is feminine) — this implementation
/// uses the masculine forms throughout, correct for currencies like "ريال" and "دولار" which this
/// app already uses, but not universally correct for every possible feminine currency noun.
String arabicNumberToWords(num amount) {
  final whole = amount.truncate();
  if (whole == 0) return 'صفر';
  if (whole < 0) return 'سالب ${arabicNumberToWords(-whole)}';
  return _convert(whole).trim();
}

const _ones = [
  '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
  'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
  'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];

const _tens = [
  '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون',
];

const _hundreds = [
  '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة',
];

String _convert(int n) {
  if (n < 20) return _ones[n];
  if (n < 100) {
    final tens = _tens[n ~/ 10];
    final ones = n % 10;
    return ones == 0 ? tens : '${_ones[ones]} و$tens';
  }
  if (n < 1000) {
    final hundreds = _hundreds[n ~/ 100];
    final rest = n % 100;
    return rest == 0 ? hundreds : '$hundreds و${_convert(rest)}';
  }
  if (n < 1000000) {
    final thousands = n ~/ 1000;
    final rest = n % 1000;
    final thousandsWord = switch (thousands) {
      1 => 'ألف',
      2 => 'ألفان',
      >= 3 && <= 10 => '${_convert(thousands)} آلاف',
      _ => '${_convert(thousands)} ألفًا',
    };
    return rest == 0 ? thousandsWord : '$thousandsWord و${_convert(rest)}';
  }
  final millions = n ~/ 1000000;
  final rest = n % 1000000;
  final millionsWord = switch (millions) {
    1 => 'مليون',
    2 => 'مليونان',
    >= 3 && <= 10 => '${_convert(millions)} ملايين',
    _ => '${_convert(millions)} مليونًا',
  };
  return rest == 0 ? millionsWord : '$millionsWord و${_convert(rest)}';
}
