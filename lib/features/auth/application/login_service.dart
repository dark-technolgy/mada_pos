import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/database/database.dart';
import '../../../core/security/account_security_service.dart';
import '../../../core/security/auth_service.dart';
import '../../../core/security/supabase_auth_service.dart';

enum LoginStatus {
  authenticated,
  invalidCredentials,
  passwordChangeRequired,
  notApproved,
  error
}

class LoginResult {
  const LoginResult({required this.status, this.user, this.message});

  final LoginStatus status;
  final User? user;
  final String? message;
}

class LoginService {
  const LoginService();

  Future<LoginResult> authenticate(
    AppDatabase db, {
    required String username, // This will be treated as email for Supabase
    required String password,
  }) async {
    final sbAuth = SupabaseAuthService();
    
    try {
      // 1. Try Supabase Auth
      final response = await sbAuth.signIn(email: username.trim(), password: password);
      final sbUser = response.user;

      if (sbUser == null) {
        return const LoginResult(status: LoginStatus.invalidCredentials);
      }

      // 2. Check if approved
      final isApproved = await sbAuth.isUserApproved(sbUser.id);
      if (!isApproved) {
        return const LoginResult(status: LoginStatus.notApproved);
      }

      // 3. Sync with local DB
      var localUser = await (db.select(db.users)..where((u) => u.supabaseId.equals(sbUser.id))).getSingleOrNull();

      if (localUser == null) {
        // Create local user from Supabase data
        final fullName = sbUser.userMetadata?['full_name'] ?? 'User';
        final id = await db.into(db.users).insert(
          UsersCompanion.insert(
            supabaseId: Value(sbUser.id),
            username: username.trim(),
            email: Value(sbUser.email),
            passwordHash: '', // Cloud users don't need local hash check
            fullName: fullName,
            role: const Value('cashier'), // Default role
          )
        );
        localUser = await (db.select(db.users)..where((u) => u.id.equals(id))).getSingle();
      }

      return LoginResult(status: LoginStatus.authenticated, user: localUser);

    } on sb.AuthException catch (e) {
      // 4. Fallback to local login for offline capability (Admin only or existing users)
      return _authenticateLocal(db, username, password);
    } catch (e) {
      return const LoginResult(status: LoginStatus.error);
    }
  }

  Future<LoginResult> _authenticateLocal(AppDatabase db, String username, String password) async {
    final normalizedUsername = username.trim();
    final user =
        await (db.select(db.users)
              ..where((entry) => entry.username.equals(normalizedUsername))
              ..where((entry) => entry.isActive.equals(true)))
            .getSingleOrNull();

    if (user == null || user.passwordHash.isEmpty ||
        !AuthService.verifyPassword(password, user.passwordHash)) {
      return const LoginResult(status: LoginStatus.invalidCredentials);
    }

    return LoginResult(
      status: LoginStatus.authenticated,
      user: user,
    );
  }

  Future<void> register(AppDatabase db, {
    required String email,
    required String password,
    required String fullName,
  }) async {
    final sbAuth = SupabaseAuthService();
    await sbAuth.signUp(email: email, password: password, fullName: fullName);
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
