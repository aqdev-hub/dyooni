/// Normalizes a phone number into a stable lookup key: keeps digits only, drops spaces, dashes,
/// parentheses, and any leading '+'. This does NOT attempt real international phone parsing
/// (no country-code disambiguation) — it only needs to be byte-for-byte CONSISTENT between the
/// moment a phone is saved at sign-up and the moment the same string is typed again at login,
/// which is the actual requirement here. See signup_screen.dart's TODO about a real country-code
/// picker for the known simplification this inherits.
String normalizePhoneForLookup(String raw) {
  return raw.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Firebase Auth's email/password provider has no native "phone" identifier — the login field
/// accepts either, so callers use this to decide which path an identifier should take.
bool looksLikeEmail(String identifier) => identifier.contains('@');
