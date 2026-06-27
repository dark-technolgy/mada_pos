import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../../core/database/database.dart';
import '../../../core/security/auth_service.dart';
import '../../../core/security/pin_auth_service.dart';

class UserManagementService {
  UserManagementService(this._db);

  final AppDatabase _db;

  Future<List<User>> listUsers() {
    return (_db.select(_db.users)..orderBy([
          (user) => OrderingTerm.asc(user.role),
          (user) => OrderingTerm.asc(user.fullName),
        ]))
        .get();
  }

  Future<User> createUser({
    required String username,
    required String fullName,
    required String role,
    required String password,
  }) async {
    final usernameValidation = AuthService.validateUsername(username);
    if (usernameValidation != null) {
      throw UserManagementException(usernameValidation);
    }

    final passwordValidation = AuthService.validatePassword(password);
    if (passwordValidation != null) {
      throw UserManagementException(passwordValidation);
    }

    final normalizedUsername = username.trim();
    final normalizedFullName = fullName.trim();
    if (normalizedFullName.isEmpty) {
      throw const UserManagementException('Full name is required');
    }

    final existing =
        await (_db.select(_db.users)
              ..where((user) => user.username.equals(normalizedUsername)))
            .getSingleOrNull();
    if (existing != null) {
      throw const UserManagementException('Username already exists');
    }

    final id = await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            username: normalizedUsername,
            passwordHash: AuthService.hashPassword(password),
            fullName: normalizedFullName,
            role: Value(role),
          ),
        );

    return (_db.select(
      _db.users,
    )..where((user) => user.id.equals(id))).getSingle();
  }

  Future<User> updateUser({
    required User user,
    required String fullName,
    required String role,
    required bool isActive,
  }) async {
    final normalizedFullName = fullName.trim();
    if (normalizedFullName.isEmpty) {
      throw const UserManagementException('Full name is required');
    }

    final updatedAt = DateTime.now();
    await (_db.update(
      _db.users,
    )..where((item) => item.id.equals(user.id))).write(
      UsersCompanion(
        fullName: Value(normalizedFullName),
        role: Value(role),
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );

    return user.copyWith(
      fullName: normalizedFullName,
      role: role,
      isActive: isActive,
      updatedAt: updatedAt,
    );
  }

  Future<User> resetPassword({
    required User user,
    required String newPassword,
  }) async {
    final passwordValidation = AuthService.validatePassword(newPassword);
    if (passwordValidation != null) {
      throw UserManagementException(passwordValidation);
    }

    final updatedAt = DateTime.now();
    final passwordHash = AuthService.hashPassword(newPassword);

    await (_db.update(
      _db.users,
    )..where((item) => item.id.equals(user.id))).write(
      UsersCompanion(
        passwordHash: Value(passwordHash),
        updatedAt: Value(updatedAt),
      ),
    );

    return user.copyWith(passwordHash: passwordHash, updatedAt: updatedAt);
  }

  Future<User> setUserPin({required User user, required String pin}) async {
    final formatError = PinAuthService.validatePinFormat(pin);
    if (formatError != null) {
      throw UserManagementException(formatError);
    }
    final hash = PinAuthService.hashPin(pin);
    final updatedAt = DateTime.now();
    await (_db.update(_db.users)..where((item) => item.id.equals(user.id)))
        .write(
      UsersCompanion(
        pin: Value<String?>(hash),
        updatedAt: Value(updatedAt),
      ),
    );
    return user.copyWith(pin: Value(hash), updatedAt: updatedAt);
  }

  Future<User> clearUserPin({required User user}) async {
    final updatedAt = DateTime.now();
    await (_db.update(_db.users)..where((item) => item.id.equals(user.id)))
        .write(
      UsersCompanion(
        pin: const Value<String?>(null),
        updatedAt: Value(updatedAt),
      ),
    );
    return user.copyWith(pin: const Value(null), updatedAt: updatedAt);
  }

  Future<User> setActive({required User user, required bool isActive}) async {
    final updatedAt = DateTime.now();
    await (_db.update(
      _db.users,
    )..where((item) => item.id.equals(user.id))).write(
      UsersCompanion(isActive: Value(isActive), updatedAt: Value(updatedAt)),
    );

    return user.copyWith(isActive: isActive, updatedAt: updatedAt);
  }
}

class UserManagementException implements Exception {
  const UserManagementException(this.message);

  final String message;
}
