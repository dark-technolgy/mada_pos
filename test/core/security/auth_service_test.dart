import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/security/auth_service.dart';

void main() {
  group('AuthService', () {
    test('hashes passwords with PBKDF2 and verifies them', () {
      final hash = AuthService.hashPassword('Admin123');

      expect(hash.startsWith('pbkdf2_sha256\$'), isTrue);
      expect(AuthService.verifyPassword('Admin123', hash), isTrue);
      expect(AuthService.verifyPassword('Wrong123', hash), isFalse);
      expect(AuthService.needsRehash(hash), isFalse);
    });

    test('accepts legacy SHA-256 hashes and marks them for rehash', () {
      const legacyHash =
          '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';

      expect(AuthService.verifyPassword('admin123', legacyHash), isTrue);
      expect(AuthService.needsRehash(legacyHash), isTrue);
    });
  });
}
