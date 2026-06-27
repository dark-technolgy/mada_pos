import 'auth_service.dart';

/// PIN storage uses the same PBKDF2 hasher as passwords (short numeric PIN).
class PinAuthService {
  PinAuthService._();

  static String? validatePinFormat(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return 'pin-invalid-format';
    }
    return null;
  }

  static String hashPin(String pin) => AuthService.hashPassword(pin);

  static bool verifyPin(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    return AuthService.verifyPassword(pin, storedHash);
  }
}
