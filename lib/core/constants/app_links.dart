/// Where the app can be downloaded, for "مشاركة التطبيق" and "قيّم التطبيق".
///
/// The app is not on Google Play yet, so people are sent to its page on the developer's site,
/// where it can be downloaded and rated. The day it is published, set [playStoreUrl] below (and
/// nowhere else): sharing and rating then point to the store.
abstract class AppLinks {
  /// `null` until the app is published on Google Play.
  static const String? playStoreUrl = null;

  /// The store address this app WILL have (from its application id) — copy it into
  /// [playStoreUrl] when the listing is live.
  static const futurePlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.aqdev.dyooni.dyooni';

  /// The app's page on the developer's site (download + rating), same for every language.
  static const appPageUrl = 'https://abdulquddus-dev.github.io/?project=dyooni';

  /// A small JSON file describing the newest release (see version.json in the project root).
  /// The app reads it to tell people an update exists. `null` turns the check off.
  static const String? updateInfoUrl = 'https://raw.githubusercontent.com/aqdev-hub/dyooni/main/version.json';

  /// The link a person receives when the app is shared.
  static String shareUrl(String languageCode) => playStoreUrl ?? appPageUrl;

  /// Where a person goes to rate the app.
  static String get ratingUrl => playStoreUrl ?? appPageUrl;
}
