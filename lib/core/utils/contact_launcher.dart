import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp directly to a chat with [phoneNumber] (digits only, WITH country code, no
/// leading '+') prefilled with [message] — uses the wa.me web link, which works whether or not
/// WhatsApp itself is installed (the OS/browser handles the install-prompt fallback). Throws if
/// nothing on the device can handle the resulting URL; callers are expected to catch this and
/// show their own message — same pattern as [launchPhoneDialer] in phone_launcher.dart, applied
/// here so contact_us_screen.dart's three actions all fail the same honest way.
Future<void> launchWhatsAppChat(String phoneNumber, String message) async {
  final uri = Uri.https('wa.me', '/$phoneNumber', {'text': message});
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) throw StateError('No app available to handle the WhatsApp link');
}

/// Opens the device's default email client with a prefilled recipient/subject/body. Same
/// "throw on failure, let the caller show its own message" contract as [launchWhatsAppChat].
Future<void> launchSupportEmail({
  required String email,
  required String subject,
  required String body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {'subject': subject, 'body': body},
  );
  final launched = await launchUrl(uri);
  if (!launched) throw StateError('No app available to handle mailto: URIs');
}
