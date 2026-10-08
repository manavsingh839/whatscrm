import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;

class CryptoUtils {
  /// Generate a random 64-character hex key (32 bytes)
  static String generateKeyHex() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Encrypt string using AES-256-GCM matching Node.js `<iv-hex>:<ciphertext-hex>:<authTag-hex>`
  static String encrypt(String plainText, String keyHex) {
    if (keyHex.length != 64) {
      throw ArgumentError('Encryption key must be 64 hex characters (32 bytes)');
    }
    final keyBytes = enc.Key.fromBase16(keyHex);
    final ivBytes = enc.IV.fromSecureRandom(12); // 12 bytes IV for GCM

    final encrypter = enc.Encrypter(
      enc.AES(keyBytes, mode: enc.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plainText, iv: ivBytes);

    // encrypted.bytes contains ciphertext + 16-byte auth tag
    final allBytes = encrypted.bytes;
    if (allBytes.length < 16) {
      throw StateError('Ciphertext too short for GCM tag');
    }
    final ctBytes = allBytes.sublist(0, allBytes.length - 16);
    final tagBytes = allBytes.sublist(allBytes.length - 16);

    final ivHex = ivBytes.base16;
    final ctHex = ctBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final tagHex = tagBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '$ivHex:$ctHex:$tagHex';
  }

  /// Decrypt `<iv-hex>:<ciphertext-hex>:<authTag-hex>` or legacy `<iv-hex>:<ciphertext-hex>`
  static String decrypt(String encryptedText, String keyHex) {
    if (keyHex.length != 64) {
      throw ArgumentError('Encryption key must be 64 hex characters (32 bytes)');
    }
    final parts = encryptedText.split(':');
    final keyBytes = enc.Key.fromBase16(keyHex);

    if (parts.length == 3) {
      // GCM format: iv : ciphertext : authTag
      final iv = enc.IV.fromBase16(parts[0]);
      final ctBytes = _hexToBytes(parts[1]);
      final tagBytes = _hexToBytes(parts[2]);

      final combined = Uint8List(ctBytes.length + tagBytes.length);
      combined.setAll(0, ctBytes);
      combined.setAll(ctBytes.length, tagBytes);

      final encrypter = enc.Encrypter(
        enc.AES(keyBytes, mode: enc.AESMode.gcm),
      );

      return encrypter.decrypt(enc.Encrypted(combined), iv: iv);
    } else if (parts.length == 2) {
      // CBC legacy format: iv : ciphertext
      final iv = enc.IV.fromBase16(parts[0]);
      final encrypter = enc.Encrypter(
        enc.AES(keyBytes, mode: enc.AESMode.cbc),
      );
      return encrypter.decrypt(enc.Encrypted.fromBase16(parts[1]), iv: iv);
    } else {
      throw FormatException('Invalid encrypted token format');
    }
  }

  /// Compute HMAC-SHA256 signature for Meta Webhooks verification
  static String computeHmacSha256(String data, String secret) {
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Verify Meta Webhook signature `sha256=<hash>`
  static bool verifyMetaSignature({
    required String rawBody,
    required String secret,
    required String signatureHeader,
  }) {
    if (!signatureHeader.startsWith('sha256=')) return false;
    final expectedSignature = signatureHeader.substring('sha256='.length);
    final computed = computeHmacSha256(rawBody, secret);
    return computed == expectedSignature;
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
