import 'package:drift/drift.dart' show Value;
import '../database/database.dart';
import 'auth_service.dart';

class AccountSecurityService {
  AccountSecurityService(this._db);

  static const String defaultAdminPasswordKey =
      'security_require_password_change_admin';

  final AppDatabase _db;

  Future<bool> shouldRequirePasswordChange(User user) async {
    if (user.username != 'admin') return false;

    final setting =
        await (_db.select(_db.settings)
              ..where((item) => item.key.equals(defaultAdminPasswordKey)))
            .getSingleOrNull();

    return setting?.value == 'true';
  }

  Future<User> changePassword({
    required User user,
    required String newPassword,
    String? currentPassword,
    bool validateCurrentPassword = true,
  }) async {
    if (validateCurrentPassword) {
      if (currentPassword == null ||
          !AuthService.verifyPassword(currentPassword, user.passwordHash)) {
        throw const AccountSecurityException('current-password-invalid');
      }
    }

    final validationMessage = AuthService.validatePassword(newPassword);
    if (validationMessage != null) {
      throw AccountSecurityException(validationMessage);
    }

    final hashedPassword = AuthService.hashPassword(newPassword);
    final updatedAt = DateTime.now();

    await (_db.update(
      _db.users,
    )..where((item) => item.id.equals(user.id))).write(
      UsersCompanion(
        passwordHash: Value(hashedPassword),
        updatedAt: Value(updatedAt),
      ),
    );

    if (user.username == 'admin') {
      await (_db.update(_db.settings)
            ..where((item) => item.key.equals(defaultAdminPasswordKey)))
          .write(const SettingsCompanion(value: Value('false')));
    }

    return user.copyWith(passwordHash: hashedPassword, updatedAt: updatedAt);
  }
}

class AccountSecurityException implements Exception {
  const AccountSecurityException(this.message);

  final String message;
}
