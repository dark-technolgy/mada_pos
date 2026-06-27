import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/auth/application/user_management_service.dart';
import 'package:mada_pos/features/auth/application/users_management_screen_service.dart';

void main() {
  group('UsersManagementScreenService', () {
    late AppDatabase database;
    late UsersManagementScreenService service;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      service = UsersManagementScreenService(UserManagementService(database));
    });

    tearDown(() async {
      await database.close();
    });

    test('creates and loads users through screen service', () async {
      await service.createUser(
        const UserCreatePayload(
          username: 'cashier9',
          fullName: 'Cashier Nine',
          role: 'cashier',
          password: 'Cashier123',
        ),
      );

      final users = await service.loadUsers();
      expect(users.any((user) => user.username == 'cashier9'), isTrue);
    });

    test('toggles active state for a user', () async {
      final createdUser = await service.createUser(
        const UserCreatePayload(
          username: 'viewer9',
          fullName: 'Viewer Nine',
          role: 'viewer',
          password: 'Viewer123',
        ),
      );

      final updatedUser = await service.toggleActive(createdUser);

      expect(updatedUser.isActive, isFalse);
    });

    test('updates user details through screen service', () async {
      final createdUser = await service.createUser(
        const UserCreatePayload(
          username: 'manager9',
          fullName: 'Manager Nine',
          role: 'manager',
          password: 'Manager123',
        ),
      );

      final updatedUser = await service.updateUser(
        createdUser,
        const UserUpdatePayload(
          fullName: 'Manager Nine Updated',
          role: 'admin',
          isActive: true,
        ),
      );

      expect(updatedUser.fullName, 'Manager Nine Updated');
      expect(updatedUser.role, 'admin');
    });
  });
}
