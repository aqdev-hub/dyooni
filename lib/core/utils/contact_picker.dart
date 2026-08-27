import 'package:flutter_contacts/flutter_contacts.dart';

/// Opens the device's OWN native contact-picker UI and returns whichever contact the person
/// chose, or `null` if they backed out without choosing anyone.
///
/// Deliberately `openExternalPick()`, not an in-app list built on `FlutterContacts.getContacts()`
/// — the external picker hands back exactly the one contact the person picked via the OS's own
/// one-time grant for that contact, so this never needs the app to hold the broad `READ_CONTACTS`
/// runtime permission, and needs no manifest/Info.plist entry at all.
Future<Contact?> pickDeviceContact() => FlutterContacts.openExternalPick();

/// The contact's first phone number as typed in the device's address book, or `null` if the
/// contact has none. No normalization here — see core/utils/phone_utils.dart for that, applied
/// only where a phone is actually used as a login-lookup key, not when just filling a form field.
String? firstPhoneNumber(Contact contact) => contact.phones.isEmpty ? null : contact.phones.first.number;

/// The contact's full display name, or `null` if it has none at all (rare, but a contact with
/// only a phone number and no name is possible on-device).
String? displayName(Contact contact) => contact.displayName.trim().isEmpty ? null : contact.displayName.trim();
