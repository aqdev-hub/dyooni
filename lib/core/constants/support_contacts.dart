/// Support contact details — one place, used by the contact screen and the rating feedback.
///
/// DISCLOSED ASSUMPTION: the number was given without a country code — assumed +967 (Yemen).
/// If that is wrong, only these lines need to change.
abstract class SupportContacts {
  static const phoneLocal = '772906988';
  static const whatsappNumber = '967$phoneLocal'; // wa.me format: country code + number, no '+'
  static const callNumber = '+967$phoneLocal';
  static const email = 'sba849198@gmail.com';
}
