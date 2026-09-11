import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted, iterated HMAC-SHA256 stretching for staff passwords/PINs. Not
/// bcrypt/argon2/PBKDF2 — the `crypto` package doesn't provide those, and
/// pulling in a native plugin just for this would add a Windows build
/// dependency. 100k rounds of chained HMAC-SHA256 is a reasonable cost for a
/// till app authenticating against a local database (not an
/// internet-facing login endpoint), and is far stronger than a bare hash.
class PasswordHasher {
  const PasswordHasher._();

  static const int _iterations = 100000;
  static const int _saltBytes = 16;

  /// Returns `salt:hash`, both hex-encoded, ready to store in one column.
  static String hash(String plainText) {
    final salt = _randomBytes(_saltBytes);
    final digest = _stretch(plainText, salt);
    return '${hex.encode(salt)}:${hex.encode(digest)}';
  }

  static bool verify(String plainText, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final salt = hex.decode(parts[0]);
    final expected = hex.decode(parts[1]);
    final actual = _stretch(plainText, salt);
    return _constantTimeEquals(actual, expected);
  }

  static List<int> _stretch(String plainText, List<int> salt) {
    final keyBytes = utf8.encode(plainText);
    var block = Hmac(sha256, keyBytes).convert(salt).bytes;
    for (var i = 1; i < _iterations; i++) {
      block = Hmac(sha256, keyBytes).convert(block).bytes;
    }
    return block;
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Minimal hex codec so we don't pull in an extra dependency for it.
class _HexCodec {
  const _HexCodec();

  String encode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> decode(String input) {
    final result = <int>[];
    for (var i = 0; i < input.length; i += 2) {
      result.add(int.parse(input.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

const hex = _HexCodec();
