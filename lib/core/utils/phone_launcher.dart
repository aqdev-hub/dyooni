import 'package:url_launcher/url_launcher.dart';

/// Opens the device's phone dialer pre-filled with [phoneNumber] (does NOT place the call
/// automatically — same as tapping a phone number link anywhere else on the device). Throws if
/// no dialer app can handle it; callers are expected to catch this and show their own message
/// (see AccountDetailsScreen's call icon) rather than pre-checking with `canLaunchUrl`, which on
/// iOS would require declaring `tel` under `LSApplicationQueriesSchemes` in Info.plist just for
/// the check itself — launching directly avoids that manifest requirement entirely.
Future<void> launchPhoneDialer(String phoneNumber) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  final launched = await launchUrl(uri);
  if (!launched) throw StateError('No app available to handle tel: URIs');
}
