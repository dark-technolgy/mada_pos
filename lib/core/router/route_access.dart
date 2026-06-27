import '../security/session_manager.dart';

/// Maps [GoRouter] locations to [SessionManager.hasPermission] keys.
class RouteAccess {
  RouteAccess._();

  /// When non-null, navigation to [location] should redirect to this path.
  static String? deniedRedirect(SessionManager session, String location) {
    if (location.startsWith('/login')) return null;
    bool ok(String permission) => session.hasPermission(permission);

    if (location.startsWith('/pos')) {
      return ok('create_invoice') ? null : '/dashboard';
    }
    if (location.startsWith('/products')) {
      return ok('manage_products') ? null : '/dashboard';
    }
    if (location.startsWith('/categories')) {
      return ok('manage_products') ? null : '/dashboard';
    }
    if (location.startsWith('/inventory')) {
      return ok('manage_inventory') ? null : '/dashboard';
    }
    if (location.startsWith('/warehouses')) {
      return ok('manage_inventory') ? null : '/dashboard';
    }
    if (location.startsWith('/audit-log')) {
      return ok('manage_users') ? null : '/dashboard';
    }
    if (location.startsWith('/customers')) {
      return ok('manage_customers') ? null : '/dashboard';
    }
    if (location.startsWith('/suppliers')) {
      return ok('manage_suppliers') ? null : '/dashboard';
    }
    if (location.startsWith('/invoices')) {
      return ok('create_invoice') ? null : '/dashboard';
    }
    if (location.startsWith('/quotes')) {
      return ok('create_invoice') ? null : '/dashboard';
    }
    if (location.startsWith('/units')) {
      return ok('manage_products') ? null : '/dashboard';
    }
    if (location.startsWith('/cash-register')) {
      return ok('cash_register') ? null : '/dashboard';
    }
    if (location.startsWith('/debts')) {
      return ok('manage_debts') ? null : '/dashboard';
    }
    if (location.startsWith('/expenses')) {
      return ok('manage_expenses') ? null : '/dashboard';
    }
    if (location.startsWith('/reports')) {
      return ok('view_reports') ? null : '/dashboard';
    }
    if (location.startsWith('/users')) {
      return ok('manage_users') ? null : '/dashboard';
    }
    if (location.startsWith('/settings')) {
      return ok('manage_settings') ? null : '/dashboard';
    }
    if (location.startsWith('/backup')) {
      return ok('manage_backup') ? null : '/dashboard';
    }

    return null;
  }
}
