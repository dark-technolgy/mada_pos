import 'dart:async';
import 'package:drift/drift.dart';
import '../database/database.dart';

/// Manages user sessions with auto-logout functionality
class SessionManager {
  SessionManager(this._db);

  final AppDatabase _db;
  User? _currentUser;
  Timer? _sessionTimer;
  int _timeoutMinutes = 30;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isManager => _currentUser?.role == 'manager' || isAdmin;

  /// Check if the current user has a specific permission
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    final role = _currentUser!.role;

    return switch (permission) {
      'manage_users' => role == 'admin',
      'manage_settings' => role == 'admin',
      'view_reports' => role != 'viewer',
      'manage_products' => role != 'viewer',
      'manage_inventory' => role != 'viewer',
      'manage_customers' => role != 'viewer',
      'manage_suppliers' => role == 'admin' || role == 'manager',
      'create_invoice' => role != 'viewer',
      'void_invoice' => role == 'admin' || role == 'manager',
      'manage_debts' => role != 'viewer',
      'manage_expenses' => role == 'admin' || role == 'manager',
      'view_profit' => role == 'admin' || role == 'manager',
      'manage_backup' => role == 'admin',
      'cash_register' => role != 'viewer',
      _ => role == 'admin',
    };
  }

  /// Start a session for a user
  Future<void> startSession(User user, {int? timeoutMinutes}) async {
    _currentUser = user;
    if (timeoutMinutes != null) _timeoutMinutes = timeoutMinutes;
    _resetTimer();

    // Update last login
    await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(lastLogin: Value(DateTime.now())),
    );

    // Audit log
    await _db
        .into(_db.auditLog)
        .insert(
          AuditLogCompanion.insert(
            userId: Value(user.id),
            action: 'login',
            targetTable: 'users',
            recordId: Value(user.id),
          ),
        );
  }

  /// End the current session
  Future<void> endSession() async {
    if (_currentUser != null) {
      await _db
          .into(_db.auditLog)
          .insert(
            AuditLogCompanion.insert(
              userId: Value(_currentUser!.id),
              action: 'logout',
              targetTable: 'users',
              recordId: Value(_currentUser!.id),
            ),
          );
    }
    _currentUser = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Reset the session timer (called on user activity)
  void resetTimer() => _resetTimer();

  void _resetTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      endSession();
    });
  }

  /// Record an audit action
  Future<void> logAction({
    required String action,
    required String targetTable,
    int? recordId,
    String? oldValues,
    String? newValues,
    String? details,
  }) async {
    if (_currentUser == null) return;
    await _db
        .into(_db.auditLog)
        .insert(
          AuditLogCompanion.insert(
            userId: Value(_currentUser!.id),
            action: action,
            targetTable: targetTable,
            recordId: Value.absentIfNull(recordId),
            oldValues: Value.absentIfNull(oldValues),
            newValues: Value.absentIfNull(newValues),
            details: Value.absentIfNull(details),
          ),
        );
  }

  void dispose() {
    _sessionTimer?.cancel();
  }
}
