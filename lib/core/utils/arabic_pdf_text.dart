import 'package:arabic_reshaper/arabic_reshaper.dart';

/// The `pdf` package draws each character as a separate glyph — it doesn't join Arabic letters
/// into their correct connected forms, and doesn't reorder right-to-left runs. This function
/// does both, using the community-standard workaround: reshape into presentation forms, then
/// reverse the character order so the (non-shaping) PDF text layout draws them left-to-right in
/// what ends up as the visually-correct right-to-left result.
///
/// Falls back to the original, unshaped text if the reshaping call itself throws — an
/// imperfectly-joined Arabic string in a PDF is a real but minor cosmetic issue; a crash while
/// generating the report is not an acceptable trade for slightly nicer letter joining.
String shapeArabicForPdf(String text) {
  try {
    final reshaped = ArabicReshaper().reshape(text);
    return reshaped.split('').reversed.join();
  } catch (_) {
    return text;
  }
}
