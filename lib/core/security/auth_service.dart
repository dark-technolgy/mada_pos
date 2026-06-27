import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class AuthService {
  AuthService._();

  static const String _pbkdf2Prefix = 'pbkdf2_sha256';
  static const int _defaultIterations = 120000;
  static const int _saltLengthBytes = 16;
  static const int _derivedKeyLengthBytes = 32;

  /// Hash a password using salted PBKDF2-HMAC-SHA256.
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final derivedKey = _deriveKey(password, salt, _defaultIterations);
    return '$_pbkdf2Prefix\$$_defaultIterations\$${base64Encode(salt)}\$${base64Encode(derivedKey)}';
  }

  /// Verify a password against either the current PBKDF2 format or legacy SHA-256.
  static bool verifyPassword(String password, String hash) {
    if (hash.startsWith('$_pbkdf2Prefix\$')) {
      final parts = hash.split('\$');
      if (parts.length != 4) return false;

      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0) return false;

      try {
        final salt = base64Decode(parts[2]);
        final expected = base64Decode(parts[3]);
        final actual = _deriveKey(password, salt, iterations);
        return _constantTimeEquals(actual, expected);
      } catch (_) {
        return false;
      }
    }

    return _constantTimeEquals(
      utf8.encode(_legacySha256(password)),
      utf8.encode(hash),
    );
  }

  /// Rehash legacy hashes and hashes with outdated work factors.
  static bool needsRehash(String hash) {
    if (!hash.startsWith('$_pbkdf2Prefix\$')) {
      return true;
    }

    final parts = hash.split('\$');
    if (parts.length != 4) return true;

    final iterations = int.tryParse(parts[1]);
    return iterations == null || iterations < _defaultIterations;
  }

  static String _legacySha256(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLengthBytes, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _deriveKey(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, _derivedKeyLengthBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;

    var result = 0;
    for (var index = 0; index < left.length; index++) {
      result |= left[index] ^ right[index];
    }

    return result == 0;
  }

  /// Returns a stable error code when invalid, or null when valid.
  static String? validatePassword(String password) {
    if (password.length < 8) return 'password-too-short';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'password-no-upper';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'password-no-lower';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'password-no-digit';
    return null;
  }

  /// Validate username
  static String? validateUsername(String username) {
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }
}
