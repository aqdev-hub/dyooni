import 'package:flutter_contacts/flutter_contacts.dart';

/// Thrown by [pickDeviceContact] when the device's contact-read permission was denied — kept
/// deliberately distinct from a plain `null` return (which means the person opened the picker
/// and backed out without choosing anyone).
///
/// FIX for the reported bug where the phone/person contact-pick icons appeared to "stop working
/// entirely — nothing happens when tapped": before this split, a denied permission and a
/// cancelled picker looked IDENTICAL to the person — both silently did nothing at all. That made
/// a genuinely revoked/denied permission indistinguishable from ordinary user cancellation, so
/// there was never any feedback telling the person why nothing opened. Callers now catch this
/// exception specifically and show `contactPermissionDeniedMessage` — a real, actionable message
/// — only for this case.
class ContactPermissionDeniedException implements Exception {
  const ContactPermissionDeniedException();
}

/// Opens the device's OWN native contact-picker UI and returns whichever contact the person
/// chose, or `null` if they backed out without choosing anyone. Throws
/// [ContactPermissionDeniedException] if permission itself was refused — see that class's doc
/// comment for why this is a separate case from `null`.
///
/// `openExternalPick()` is documented as not requiring `READ_CONTACTS` — but on some devices/
/// plugin versions it still needs the permission actually granted to read back the phone/name
/// properties of the picked contact, and skipping the request was reproducing a hard native
/// crash right after tapping a contact. Requesting explicitly first, and throwing (rather than
/// quietly returning `null`) if it's refused, is the safe fix: the picker only ever opens once
/// permission is actually granted, and a refusal is never silently swallowed into looking like
/// the icon simply does nothing.
///
/// NOTE if this exception keeps firing after the fix ships: a runtime permission REQUEST can
/// never override a permission the person has already permanently denied on-device ("رفض ولا
/// تسأل مرة أخرى" / "Deny & don't ask again") — in that case `requestPermission()` will keep
/// returning `false` no matter how many times it's called, and the person must re-enable the
/// Contacts permission for the app from the device's own system Settings first.
Future<Contact?> pickDeviceContact() async {
  final granted = await FlutterContacts.requestPermission(readonly: true);
  if (!granted) throw const ContactPermissionDeniedException();
  return FlutterContacts.openExternalPick();
}

/// The contact's first phone number as typed in the device's address book, or `null` if the
/// contact has none. No normalization here — see core/utils/phone_utils.dart for that, applied
/// only where a phone is actually used as a login-lookup key, not when just filling a form field.
String? firstPhoneNumber(Contact contact) => contact.phones.isEmpty ? null : contact.phones.first.number;

/// The contact's full display name, or `null` if it has none at all (rare, but a contact with
/// only a phone number and no name is possible on-device).
String? displayName(Contact contact) => contact.displayName.trim().isEmpty ? null : contact.displayName.trim();
