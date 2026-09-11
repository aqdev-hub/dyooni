import 'package:flutter_contacts/flutter_contacts.dart';

/// Opens the device's OWN native contact-picker UI and returns whichever contact the person
/// chose, or `null` if they backed out without choosing anyone or permission was refused.
///
/// `openExternalPick()` is documented as not requiring `READ_CONTACTS` — but on some devices/
/// plugin versions it still needs the permission actually granted to read back the phone/name
/// properties of the picked contact, and skipping the request was reproducing a hard native
/// crash right after tapping a contact (not a catchable Dart exception). Requesting explicitly
/// first, and returning `null` if it's refused, is the safe fix: the picker is only ever opened
/// once permission is actually granted.
Future<Contact?> pickDeviceContact() async {
  final granted = await FlutterContacts.requestPermission(readonly: true);
  if (!granted) return null;
  return FlutterContacts.openExternalPick();
}

/// The contact's first phone number as typed in the device's address book, or `null` if the
/// contact has none. No normalization here — see core/utils/phone_utils.dart for that, applied
/// only where a phone is actually used as a login-lookup key, not when just filling a form field.
String? firstPhoneNumber(Contact contact) => contact.phones.isEmpty ? null : contact.phones.first.number;

/// The contact's full display name, or `null` if it has none at all (rare, but a contact with
/// only a phone number and no name is possible on-device).
String? displayName(Contact contact) => contact.displayName.trim().isEmpty ? null : contact.displayName.trim();
