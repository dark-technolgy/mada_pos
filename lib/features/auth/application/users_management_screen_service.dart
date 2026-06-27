import '../../../core/database/database.dart';
import 'user_management_service.dart';

class UserCreatePayload {
  const UserCreatePayload({
    required this.username,
    required this.fullName,
    required this.role,
    required this.password,
  });

  final String username;
  final String fullName;
  final String role;
  final String password;
}

class UserUpdatePayload {
  const UserUpdatePayload({
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String fullName;
  final String role;
  final bool isActive;
}

class UsersManagementScreenService {
  const UsersManagementScreenService(this._userManagementService);

  final UserManagementService _userManagementService;

  Future<List<User>> loadUsers() {
    return _userManagementService.listUsers();
  }

  Future<User> createUser(UserCreatePayload payload) {
    return _userManagementService.createUser(
      username: payload.username,
      fullName: payload.fullName,
      role: payload.role,
      password: payload.password,
    );
  }

  Future<User> updateUser(User user, UserUpdatePayload payload) {
    return _userManagementService.updateUser(
      user: user,
      fullName: payload.fullName,
      role: payload.role,
      isActive: payload.isActive,
    );
  }

  Future<User> resetPassword(User user, String newPassword) {
    return _userManagementService.resetPassword(
      user: user,
      newPassword: newPassword,
    );
  }

  Future<User> toggleActive(User user) {
    return _userManagementService.setActive(
      user: user,
      isActive: !user.isActive,
    );
  }
}
