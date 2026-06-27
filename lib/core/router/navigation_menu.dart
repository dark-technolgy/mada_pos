/// Sidebar menu index ↔ route mapping (must match [AppShell] menu order).
class NavigationMenu {
  NavigationMenu._();

  static const int dashboard = 0;
  static const int pos = 1;
  static const int products = 2;
  static const int categories = 3;
  static const int units = 4;
  static const int inventory = 5;
  static const int warehouses = 6;
  static const int customers = 7;
  static const int suppliers = 8;
  static const int invoices = 9;
  static const int quotes = 10;
  static const int cashRegister = 11;
  static const int debts = 12;
  static const int expenses = 13;
  static const int reports = 14;
  static const int users = 15;
  static const int auditLog = 16;
  static const int settings = 17;
  static const int backup = 18;
  static const int about = 19;

  /// Returns menu index for [location], or `-1` when unknown (e.g. form routes).
  static int indexForLocation(String location) {
    if (location.startsWith('/dashboard')) return dashboard;
    if (location.startsWith('/pos')) return pos;
    if (location.startsWith('/products')) return products;
    if (location.startsWith('/categories')) return categories;
    if (location.startsWith('/units')) return units;
    if (location.startsWith('/inventory')) return inventory;
    if (location.startsWith('/warehouses')) return warehouses;
    if (location.startsWith('/customers')) return customers;
    if (location.startsWith('/suppliers')) return suppliers;
    if (location.startsWith('/invoices')) return invoices;
    if (location.startsWith('/quotes')) return quotes;
    if (location.startsWith('/cash-register')) return cashRegister;
    if (location.startsWith('/debts')) return debts;
    if (location.startsWith('/expenses')) return expenses;
    if (location.startsWith('/reports')) return reports;
    if (location.startsWith('/users')) return users;
    if (location.startsWith('/audit-log')) return auditLog;
    if (location.startsWith('/settings')) return settings;
    if (location.startsWith('/backup')) return backup;
    if (location.startsWith('/about')) return about;
    return -1;
  }

  static String routeForIndex(int index) => switch (index) {
    dashboard => '/dashboard',
    pos => '/pos',
    products => '/products',
    categories => '/categories',
    units => '/units',
    inventory => '/inventory',
    warehouses => '/warehouses',
    customers => '/customers',
    suppliers => '/suppliers',
    invoices => '/invoices',
    quotes => '/quotes',
    cashRegister => '/cash-register',
    debts => '/debts',
    expenses => '/expenses',
    reports => '/reports',
    users => '/users',
    auditLog => '/audit-log',
    settings => '/settings',
    backup => '/backup',
    about => '/about',
    _ => '/dashboard',
  };
}
