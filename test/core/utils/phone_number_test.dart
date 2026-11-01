import 'package:dyooni/core/utils/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local, trunk-prefixed and international forms all become 967…', () {
    expect(normalizePhoneForMessaging('772906988'), '967772906988');
    expect(normalizePhoneForMessaging('0772 906 988'), '967772906988');
    expect(normalizePhoneForMessaging('+967 772-906-988'), '967772906988');
    expect(normalizePhoneForMessaging('00967772906988'), '967772906988');
    expect(normalizePhoneForMessaging('967772906988'), '967772906988');
  });
  test('Arabic-Indic digits are accepted', () {
    expect(normalizePhoneForMessaging('٧٧٢٩٠٦٩٨٨'), '967772906988');
  });
  test('another country code is kept when the plus sign is typed', () {
    expect(normalizePhoneForMessaging('+966501234567'), '966501234567');
  });
  test('too short or empty is rejected', () {
    expect(normalizePhoneForMessaging(''), isNull);
    expect(normalizePhoneForMessaging('123'), isNull);
  });
}
