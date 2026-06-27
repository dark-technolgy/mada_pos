import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/security/auth_service.dart';
import 'package:mada_pos/features/auth/application/login_service.dart';

void main() {
  const service = LoginService();

  test('LoginService rejects invalid credentials', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await service.authenticate(
      database,
      username: 'admin',
      password: 'wrong-password',
    );

    expect(result.status, LoginStatus.invalidCredentials);
    expect(result.user, isNull);
  });

  test(
    'LoginService upgrades legacy password hashes on successful login',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final userId = await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              username: 'legacy',
              passwordHash:
                  '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
              fullName: 'Legacy User',
              role: const Value('cashier'),
            ),
          );

      final result = await service.authenticate(
        database,
        username: 'legacy',
        password: 'admin123',
      );

      expect(result.status, LoginStatus.authenticated);
      expect(result.user, isNotNull);
      expect(result.user!.passwordHash.startsWith('pbkdf2_sha256\$'), isTrue);

      final storedUser = await (database.select(
        database.users,
      )..where((entry) => entry.id.equals(userId))).getSingle();
      expect(AuthService.needsRehash(storedUser.passwordHash), isFalse);
    },
  );

  test(
    'LoginService requires password change for fresh default admin',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final result = await service.authenticate(
        database,
        username: 'admin',
        password: 'admin123',
      );

      expect(result.status, LoginStatus.passwordChangeRequired);
      expect(result.user?.username, 'admin');
    },
  );

  test('LoginService completes mandatory password change', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin = await (database.select(
      database.users,
    )..where((entry) => entry.username.equals('admin'))).getSingle();

    final updatedUser = await service.completeMandatoryPasswordChange(
      database,
      user: admin,
      newPassword: 'SecureAdmin123',
    );

    expect(
      AuthService.verifyPassword('SecureAdmin123', updatedUser.passwordHash),
      isTrue,
    );
  });
}
