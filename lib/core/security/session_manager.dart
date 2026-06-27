import 'dart:async';
import 'package:drift/drift.dart';
import '../constants/app_constants.dart';
import '../database/database.dart';
import 'permission_service.dart';
import 'pin_auth_service.dart';

/// Manages user sessions with auto-logout and PIN lock.
class SessionManager {
  SessionManager(this._db, {this.onUserChanged, this.onLockChanged});

  final AppDatabase _db;
  final void Function(User?)? onUserChanged;
  final void Function(bool locked)? onLockChanged;
  User? _currentUser;
  Set<String> _permissions = {};
  Timer? _sessionTimer;
  Timer? _pinLockTimer;
  int _timeoutMinutes = 30;
  bool _isLocked = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLocked => _isLocked;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isManager => _currentUser?.role == 'manager' || isAdmin;

  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    if (_currentUser!.role == 'admin') return true;
    return _permissions.contains(permission);
  }

  Future<void> startSession(User user, {int? timeoutMinutes}) async {
    _timeoutMinutes = timeoutMinutes ?? await _resolveTimeoutMinutes();
    _currentUser = user;
    _permissions = await const PermissionService().permissionsForRole(
      _db,
      user.role,
    );
    _isLocked = false;
    _resetTimer();
    _resetPinLockTimer();

    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(lastLogin: Value(DateTime.now())),
    );

    onUserChanged?.call(user);
    onLockChanged?.call(false);
  }

  Future<void> endSession() async {
    _currentUser = null;
    _permissions = {};
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _pinLockTimer?.cancel();
    _pinLockTimer = null;
    _isLocked = false;
    onUserChanged?.call(null);
    onLockChanged?.call(false);
  }

  void recordActivity() {
    resetTimer();
    if (_isLocked) return;
    _resetPinLockTimer();
  }

  void resetTimer() => _resetTimer();

  void lockScreen() {
    if (_currentUser == null || _isLocked) return;
    _isLocked = true;
    onLockChanged?.call(true);
  }

  Future<bool> unlockWithPin(String pin) async {
    final user = _currentUser;
    if (user == null || user.pin == null) return false;
    if (!PinAuthService.verifyPin(pin, user.pin)) return false;
    _isLocked = false;
    _resetPinLockTimer();
    onLockChanged?.call(false);
    return true;
  }

  bool get canUsePinLock => _currentUser?.pin != null;

  void _resetTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      unawaited(endSession());
    });
  }

  void _resetPinLockTimer() {
    _pinLockTimer?.cancel();
    if (_currentUser?.pin == null) return;
    _pinLockTimer = Timer(
      Duration(minutes: AppConstants.pinLockTimeoutMinutes),
      lockScreen,
    );
  }

  Future<int> _resolveTimeoutMinutes() async {
    final timeoutSetting = await (_db.select(_db.settings)
          ..where((setting) => setting.key.equals('session_timeout_minutes')))
        .getSingleOrNull();

    final configured = int.tryParse(timeoutSetting?.value ?? '');
    if (configured == null || configured <= 0) {
      return AppConstants.sessionTimeoutMinutes;
    }

    return configured;
  }

  Future<void> logAction({
    required String action,
    required String targetTable,
    int? recordId,
    String? oldValues,
    String? newValues,
    String? details,
  }) async {
    // Audit log removed to simplify system.
  }

  void dispose() {
    _sessionTimer?.cancel();
    _pinLockTimer?.cancel();
  }
}
