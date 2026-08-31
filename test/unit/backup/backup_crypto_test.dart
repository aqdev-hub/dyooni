import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/utils/backup_crypto.dart';

void main() {
  const plainText = '{"accounts":[{"id":"a1","name":"أحمد محمد"}]}';
  const password = 'Secret123';

  test('encrypt then decrypt with the SAME password returns the original plain text', () {
    final envelope = BackupCrypto.encrypt(plainText, password);
    final decrypted = BackupCrypto.decrypt(envelope, password);

    expect(decrypted, plainText);
  });

  test('the envelope never contains the original plain text anywhere in it', () {
    final envelope = BackupCrypto.encrypt(plainText, password);

    expect(envelope.contains('أحمد محمد'), isFalse);
    expect(envelope.contains('a1'), isFalse);
  });

  test('decrypting with the WRONG password throws FormatException("password")', () {
    final envelope = BackupCrypto.encrypt(plainText, password);

    expect(
      () => BackupCrypto.decrypt(envelope, 'wrongpass'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'password')),
    );
  });

  test('decrypting a completely invalid envelope throws FormatException("envelope")', () {
    expect(
      () => BackupCrypto.decrypt('not a real envelope at all', password),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'envelope')),
    );
  });

  test('two encryptions of the same text use different salt/iv (never identical ciphertext)', () {
    final first = BackupCrypto.encrypt(plainText, password);
    final second = BackupCrypto.encrypt(plainText, password);

    expect(first, isNot(equals(second)));
  });
}
