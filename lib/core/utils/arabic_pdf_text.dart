import 'package:arabic_reshaper/arabic_reshaper.dart';

/// The `pdf` package draws each character as a separate glyph — it doesn't join Arabic letters
/// into their correct connected forms. The report document itself uses RTL layout, so reversing
/// the reshaped result here would reverse it a second time and produces the broken words seen in
/// exported reports. Only reshape; the PDF layout engine retains the RTL run order.
///
/// Falls back to the original, unshaped text if the reshaping call itself throws — an
/// imperfectly-joined Arabic string in a PDF is a real but minor cosmetic issue; a crash while
/// generating the report is not an acceptable trade for slightly nicer letter joining.
String shapeArabicForPdf(String text) {
  try {
    final reshaped = ArabicReshaper().reshape(text);
    return reshaped;
  } catch (_) {
    return text;
  }
}
