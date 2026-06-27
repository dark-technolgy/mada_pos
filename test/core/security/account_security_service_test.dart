import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/security/account_security_service.dart';
import 'package:mada_pos/core/security/auth_service.dart';

void main() {
  group('AccountSecurityService', () {
    late AppDatabase database;
    late AccountSecurityService service;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      service = AccountSecurityService(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('requires default admin password change on fresh database', () async {
      final admin = await (database.select(
        database.users,
      )..where((user) => user.username.equals('admin'))).getSingle();

      expect(await service.shouldRequirePasswordChange(admin), isTrue);
    });

    test('changes password and clears admin forced-change flag', () async {
      final admin = await (database.select(
        database.users,
      )..where((user) => user.username.equals('admin'))).getSingle();

      final updatedUser = await service.changePassword(
        user: admin,
        currentPassword: 'admin123',
        newPassword: 'SecureAdmin123',
      );

      expect(
        AuthService.verifyPassword('SecureAdmin123', updatedUser.passwordHash),
        isTrue,
      );
      expect(await service.shouldRequirePasswordChange(updatedUser), isFalse);
    });

    test(
      'rejects invalid current password for manual password changes',
      () async {
        final admin = await (database.select(
          database.users,
        )..where((user) => user.username.equals('admin'))).getSingle();

        expect(
          () => service.changePassword(
            user: admin,
            currentPassword: 'wrong-password',
            newPassword: 'SecureAdmin123',
          ),
          throwsA(isA<AccountSecurityException>()),
        );
      },
    );
  });
}
