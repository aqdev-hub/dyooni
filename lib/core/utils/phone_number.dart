/// Turns a phone number as people type it ("772 906 988", "0772906988", "+967 772906988",
/// "00967772906988") into the digits-only international form WhatsApp needs ("967772906988").
///
/// ASSUMPTION (the same one the contact screen makes): a number WITHOUT a country code belongs
/// to [defaultCountryCode] (Yemen, 967). A leading "0" is a local trunk prefix and is dropped.
/// Returns `null` when there are fewer than 6 digits — not a usable number.
String? normalizePhoneForMessaging(String raw, {String defaultCountryCode = '967'}) {
  var s = raw.trim();
  // Arabic-Indic digits → ASCII.
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(arabic[i], '$i');
  }
  final hasPlus = s.startsWith('+');
  var digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return null;
  if (hasPlus) return digits;
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.startsWith(defaultCountryCode) && digits.length >= defaultCountryCode.length + 7) return digits;
  return '$defaultCountryCode$digits';
}
