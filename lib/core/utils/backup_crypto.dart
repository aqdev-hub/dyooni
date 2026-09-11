import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show compute;

/// Encrypts/decrypts backup files with a person-chosen password — AES-256-CBC with a random
/// salt+IV per backup, and the key derived from the password via a hand-written
/// PBKDF2-HMAC-SHA256 (built only on the `crypto` package's Hmac/sha256 — no extra crypto
/// dependency beyond the one AES package itself). This is what makes an exported
/// `.dyoonibackup` file unreadable to anyone who opens it without the password: the envelope
/// itself is JSON (`salt`/`iv`/`cipherText`, all base64) so it can still be parsed, but every
/// account/transaction/personal-data field inside `cipherText` is fully opaque cipher bytes —
/// never plaintext on disk.
///
/// KNOWN, STATED LIMITATION: this is confidentiality-only (CBC, unauthenticated) — there is no
/// separate integrity/authentication tag. A wrong password (or a corrupted file) is detected
/// indirectly: AES-CBC decryption with the wrong key almost always either throws a padding error
/// or produces bytes that fail UTF-8/JSON decoding, and that failure is what LocalBackupController
/// surfaces as "wrong password" to the person. This is a deliberate, disclosed trade-off — a
/// second MAC primitive was judged unnecessary for a backup file that never leaves the person's
/// own device/control, not a claim of authenticated encryption.
///
/// Iteration count is 20,000 (not the more common 100,000+) — a deliberate performance trade-off
/// for pure-Dart PBKDF2 running on a phone CPU; still runs off the UI isolate via [compute] either
/// way, so the exact count only affects how long backup/restore takes, never UI responsiveness.
abstract class BackupCrypto {
  static const _iterations = 20000;
  static const _keyLengthBytes = 32; // AES-256
  static const _digestSizeBytes = 32; // SHA-256
  static final _random = Random.secure();

  static Uint8List _randomBytes(int length) => Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  /// Standard PBKDF2-HMAC-SHA256 (RFC 8018), written by hand so this needs no extra package
  /// beyond `crypto` (already a stable, low-risk dependency) for key derivation.
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final blockCount = (_keyLengthBytes / _digestSizeBytes).ceil();
    final derived = <int>[];
    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final indexBytes = Uint8List(4)..buffer.asByteData().setUint32(0, blockIndex, Endian.big);
      var u = hmac.convert([...salt, ...indexBytes]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < _iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var b = 0; b < t.length; b++) {
          t[b] ^= u[b];
        }
      }
      derived.addAll(t);
    }
    return Uint8List.fromList(derived.sublist(0, _keyLengthBytes));
  }

  /// Returns the full JSON envelope string, ready to be written to a `.dyoonibackup` file.
  static String encrypt(String plainText, String password) {
    final salt = _randomBytes(16);
    final ivBytes = _randomBytes(16);
    final key = enc.Key(_deriveKey(password, salt));
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final cipherText = encrypter.encrypt(plainText, iv: iv);
    return jsonEncode({
      'envelopeVersion': 1,
      'salt': base64Encode(salt),
      'iv': base64Encode(ivBytes),
      'cipherText': cipherText.base64,
    });
  }

  /// Throws `FormatException('envelope')` if [envelopeJson] isn't a structurally valid backup
  /// envelope at all (wrong file picked entirely), or `FormatException('password')` if the
  /// envelope is valid but decryption failed — almost always a wrong password. Callers use the
  /// exception's `message` to tell the two cases apart (see LocalBackupController.restoreFromFile).
  static String decrypt(String envelopeJson, String password) {
    late Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('envelope');
    }
    final saltB64 = envelope['salt'];
    final ivB64 = envelope['iv'];
    final cipherB64 = envelope['cipherText'];
    if (saltB64 is! String || ivB64 is! String || cipherB64 is! String) {
      throw const FormatException('envelope');
    }
    try {
      final key = enc.Key(_deriveKey(password, base64Decode(saltB64)));
      final iv = enc.IV(base64Decode(ivB64));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherB64, iv: iv);
    } catch (_) {
      throw const FormatException('password');
    }
  }

  /// [encrypt]/[decrypt] run PBKDF2 (20,000 HMAC rounds) plus AES — genuinely slow enough on a
  /// phone CPU to visibly freeze a frame if run on the UI isolate, so both async wrappers hand
  /// the work to [compute] instead. `compute` requires a top-level or static function reference
  /// (not a closure), which is exactly why these take a positional `List<String>` instead of
  /// named parameters.
  static Future<String> encryptAsync(String plainText, String password) => compute(_encryptIsolate, [plainText, password]);

  static Future<String> decryptAsync(String envelopeJson, String password) => compute(_decryptIsolate, [envelopeJson, password]);

  static String _encryptIsolate(List<String> args) => encrypt(args[0], args[1]);

  static String _decryptIsolate(List<String> args) => decrypt(args[0], args[1]);
}
