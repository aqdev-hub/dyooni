import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/utils/phone_utils.dart';

void main() {
  group('normalizePhoneForLookup', () {
    test('strips spaces, dashes, and parentheses', () {
      expect(normalizePhoneForLookup('050 123 4567'), '0501234567');
      expect(normalizePhoneForLookup('(050) 123-4567'), '0501234567');
    });

    test('strips a leading plus sign along with any other non-digits', () {
      expect(normalizePhoneForLookup('+966501234567'), '966501234567');
    });

    test('is idempotent for an already-normalized number', () {
      expect(normalizePhoneForLookup('0501234567'), '0501234567');
    });

    test('signup and login typing the same visible number always normalize identically', () {
      const typedAtSignup = '+966 50 123 4567';
      const typedAtLogin = '+966-50-123-4567';
      expect(normalizePhoneForLookup(typedAtSignup), normalizePhoneForLookup(typedAtLogin));
    });
  });

  group('looksLikeEmail', () {
    test('true for a string containing @', () {
      expect(looksLikeEmail('user@example.com'), isTrue);
    });

    test('false for a plain phone number', () {
      expect(looksLikeEmail('0501234567'), isFalse);
      expect(looksLikeEmail('+966501234567'), isFalse);
    });
  });
}
