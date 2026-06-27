import '../database/database.dart';

/// Canonical permission keys used across routing and UI.
abstract class AppPermissions {
  static const manageUsers = 'manage_users';
  static const manageSettings = 'manage_settings';
  static const viewReports = 'view_reports';
  static const manageProducts = 'manage_products';
  static const manageInventory = 'manage_inventory';
  static const manageCustomers = 'manage_customers';
  static const manageSuppliers = 'manage_suppliers';
  static const createInvoice = 'create_invoice';
  static const voidInvoice = 'void_invoice';
  static const manageDebts = 'manage_debts';
  static const manageExpenses = 'manage_expenses';
  static const viewProfit = 'view_profit';
  static const manageBackup = 'manage_backup';
  static const cashRegister = 'cash_register';

  static const all = [
    manageUsers,
    manageSettings,
    viewReports,
    manageProducts,
    manageInventory,
    manageCustomers,
    manageSuppliers,
    createInvoice,
    voidInvoice,
    manageDebts,
    manageExpenses,
    viewProfit,
    manageBackup,
    cashRegister,
  ];

  static Map<String, List<String>> get defaultRolePermissions => {
    'admin': List<String>.from(all),
    'manager': [
      viewReports,
      manageProducts,
      manageInventory,
      manageCustomers,
      manageSuppliers,
      createInvoice,
      voidInvoice,
      manageDebts,
      manageExpenses,
      viewProfit,
      cashRegister,
    ],
    'cashier': [
      manageProducts,
      manageInventory,
      manageCustomers,
      createInvoice,
      manageDebts,
      cashRegister,
    ],
    'viewer': [
      viewReports,
    ],
  };
}

class PermissionService {
  const PermissionService();

  Future<Set<String>> permissionsForRole(AppDatabase db, String role) async {
    final rows = await (db.select(db.rolePermissions)
          ..where((row) => row.role.equals(role)))
        .get();
    if (rows.isEmpty) {
      return Set<String>.from(
        AppPermissions.defaultRolePermissions[role] ?? const [],
      );
    }
    return rows.map((row) => row.permission).toSet();
  }

  Future<void> seedDefaultsIfEmpty(AppDatabase db) async {
    final count = await db.select(db.rolePermissions).get();
    if (count.isNotEmpty) return;

    for (final entry in AppPermissions.defaultRolePermissions.entries) {
      for (final permission in entry.value) {
        await db.into(db.rolePermissions).insert(
              RolePermissionsCompanion.insert(
                role: entry.key,
                permission: permission,
              ),
            );
      }
    }
  }

  Future<void> setRolePermissions(
    AppDatabase db, {
    required String role,
    required Set<String> permissions,
  }) async {
    await db.transaction(() async {
      await (db.delete(db.rolePermissions)
            ..where((row) => row.role.equals(role)))
          .go();
      for (final permission in permissions) {
        await db.into(db.rolePermissions).insert(
              RolePermissionsCompanion.insert(
                role: role,
                permission: permission,
              ),
            );
      }
    });
  }
}
