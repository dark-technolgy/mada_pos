import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/security/auth_service.dart';
import 'package:mada_pos/features/auth/application/user_management_service.dart';

void main() {
  group('UserManagementService', () {
    late AppDatabase database;
    late UserManagementService service;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      service = UserManagementService(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('creates user with hashed password', () async {
      final user = await service.createUser(
        username: 'cashier1',
        fullName: 'Cashier One',
        role: 'cashier',
        password: 'Cashier123',
      );

      expect(user.username, 'cashier1');
      expect(user.fullName, 'Cashier One');
      expect(
        AuthService.verifyPassword('Cashier123', user.passwordHash),
        isTrue,
      );
    });

    test('updates role and active state', () async {
      final user = await service.createUser(
        username: 'viewer1',
        fullName: 'Viewer One',
        role: 'viewer',
        password: 'Viewer123',
      );

      final updated = await service.updateUser(
        user: user,
        fullName: 'Manager One',
        role: 'manager',
        isActive: false,
      );

      expect(updated.fullName, 'Manager One');
      expect(updated.role, 'manager');
      expect(updated.isActive, isFalse);
    });

    test('resets password with validation', () async {
      final user = await service.createUser(
        username: 'cashier2',
        fullName: 'Cashier Two',
        role: 'cashier',
        password: 'Cashier123',
      );

      final updated = await service.resetPassword(
        user: user,
        newPassword: 'Reset123A',
      );

      expect(
        AuthService.verifyPassword('Reset123A', updated.passwordHash),
        isTrue,
      );
    });

    test('lists seeded admin and created users', () async {
      await service.createUser(
        username: 'cashier3',
        fullName: 'Cashier Three',
        role: 'cashier',
        password: 'Cashier123',
      );

      final users = await service.listUsers();
      expect(users.any((user) => user.username == 'admin'), isTrue);
      expect(users.any((user) => user.username == 'cashier3'), isTrue);
    });
  });
}
