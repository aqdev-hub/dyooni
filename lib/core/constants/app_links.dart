import 'legal_links.dart';

/// Where the app can be downloaded, for "مشاركة التطبيق" and "قيّم التطبيق".
///
/// The app is not on Google Play yet, so people are sent to the official site. The day it is
/// published, set [playStoreUrl] below (and nowhere else): sharing then points to the store and
/// the rating sheet gains a "rate on the store" button.
abstract class AppLinks {
  /// `null` until the app is published on Google Play.
  static const String? playStoreUrl = null;

  /// The store address this app WILL have (from its application id) — copy it into
  /// [playStoreUrl] when the listing is live.
  static const futurePlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.aqdev.dyooni.dyooni';

  static String website(String languageCode) =>
      languageCode == 'en' ? '${LegalLinks.baseUrl}/index-en.html' : '${LegalLinks.baseUrl}/';

  /// The link a person receives when the app is shared.
  static String shareUrl(String languageCode) => playStoreUrl ?? website(languageCode);
}
