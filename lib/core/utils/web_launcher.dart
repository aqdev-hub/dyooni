import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the device's browser. Throws when nothing can open it, so callers show their
/// own message (same contract as phone_launcher.dart).
Future<void> launchWebPage(Uri url) async {
  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!launched) throw StateError('No app available to open $url');
}
