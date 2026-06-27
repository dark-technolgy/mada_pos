import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../../../core/security/account_security_service.dart';
import '../../../core/security/auth_service.dart';

enum LoginStatus { authenticated, invalidCredentials, passwordChangeRequired }

class LoginResult {
  const LoginResult({required this.status, this.user});

  final LoginStatus status;
  final User? user;
}

class LoginService {
  const LoginService();

  Future<LoginResult> authenticate(
    AppDatabase db, {
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final user =
        await (db.select(db.users)
              ..where((entry) => entry.username.equals(normalizedUsername))
              ..where((entry) => entry.isActive.equals(true)))
            .getSingleOrNull();

    if (user == null ||
        !AuthService.verifyPassword(password, user.passwordHash)) {
      return const LoginResult(status: LoginStatus.invalidCredentials);
    }

    var authenticatedUser = user;
    if (AuthService.needsRehash(user.passwordHash)) {
      final upgradedHash = AuthService.hashPassword(password);
      await (db.update(db.users)..where((entry) => entry.id.equals(user.id)))
          .write(UsersCompanion(passwordHash: Value(upgradedHash)));
      authenticatedUser = user.copyWith(passwordHash: upgradedHash);
    }

    final accountSecurityService = AccountSecurityService(db);
    if (await accountSecurityService.shouldRequirePasswordChange(
      authenticatedUser,
    )) {
      return LoginResult(
        status: LoginStatus.passwordChangeRequired,
        user: authenticatedUser,
      );
    }

    return LoginResult(
      status: LoginStatus.authenticated,
      user: authenticatedUser,
    );
  }

  Future<User> completeMandatoryPasswordChange(
    AppDatabase db, {
    required User user,
    required String newPassword,
  }) {
    final accountSecurityService = AccountSecurityService(db);
    return accountSecurityService.changePassword(
      user: user,
      newPassword: newPassword,
      validateCurrentPassword: false,
    );
  }
}
