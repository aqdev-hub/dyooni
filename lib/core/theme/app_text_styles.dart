import 'package:flutter/material.dart';

/// Font pairing: Cairo (Arabic) + Inter (Latin) — similar x-height/weight so mixed-language
/// text (e.g. an Arabic label next to a phone number) doesn't look mismatched mid-sentence.
///
/// Bundled directly from `assets/fonts/` (declared in `pubspec.yaml`) — no runtime network
/// fetch, so the app's own type renders fully offline per requirement 6 ("يعمل بدون إنترنت").
abstract class AppTextStyles {
  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  static TextStyle _base(BuildContext context) =>
      TextStyle(fontFamily: _isArabic(context) ? 'Cairo' : 'Inter');

  static TextStyle headline(BuildContext context) => _base(context).copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle title(BuildContext context) => _base(context).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle body(BuildContext context) => _base(context).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle bodySecondary(BuildContext context) => _base(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle button(BuildContext context) => _base(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );
}
