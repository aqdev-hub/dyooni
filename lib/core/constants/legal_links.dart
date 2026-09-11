/// Centralizes the public URL(s) for Dyooni's official web pages, hosted via Firebase Hosting
/// (see /public and firebase.json at the repo root). Currently on the project's default Firebase
/// domain since no custom domain is connected yet — update [baseUrl] here, and nowhere else,
/// once a custom domain is attached.
abstract class LegalLinks {
  static const baseUrl = 'https://dyooni-ea39a.web.app';

  /// Sentinel value used in place of a real go_router route inside menu/drawer item lists, to
  /// mark "this item opens an external legal page" — distinct from `null` ("coming soon"
  /// placeholder) and from a real path string ("push this in-app route").
  static const privacyRouteMarker = '#privacy-policy';

  static String privacyPolicy(String languageCode) =>
      languageCode == 'en' ? '$baseUrl/privacy-en.html' : '$baseUrl/privacy.html';
}
