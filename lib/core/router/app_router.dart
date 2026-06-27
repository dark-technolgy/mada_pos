import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_access.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/license_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/users_management_screen.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/suppliers/presentation/supplier_form_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/invoices/presentation/purchase_invoice_screen.dart';
import '../../features/units/presentation/units_screen.dart';
import '../../features/debts/presentation/debts_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/cash_register/presentation/cash_register_screen.dart';
import '../../features/license/presentation/activation_screen.dart';
import '../../features/setup/presentation/setup_wizard_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);
  ref.watch(sessionManagerProvider);
  final licenseAsync = ref.watch(licenseInfoProvider);
  final bootstrap = ref.watch(appBootstrapProvider);

  return GoRouter(
    initialLocation: user == null ? '/login' : '/dashboard',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoginPage = location == '/login';
      final isActivatePage = location == '/activate';
      final isSetupPage = location == '/setup';

      // Check if setup is needed (only if bootstrap is done)
      if (bootstrap.hasValue) {
        final setupFinished = bootstrap.value?['setup_finished'] == 'true';
        if (!setupFinished && !isSetupPage) {
          return '/setup';
        }
        if (setupFinished && isSetupPage) {
          return '/login';
        }
      }

      final license = licenseAsync.valueOrNull;
      if (license != null && !license.canUseApp && !isActivatePage) {
        return '/activate';
      }
      if (license != null && license.canUseApp && isActivatePage) {
        return user == null ? '/login' : '/dashboard';
      }

      final isLoggedIn = user != null;
      if (!isLoggedIn && !isLoginPage && !isActivatePage && !isSetupPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/dashboard';
      if (isLoggedIn) {
        final session = ref.read(sessionManagerProvider);
        final denied = RouteAccess.deniedRedirect(session, location);
        if (denied != null) return denied;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/activate',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupWizardScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(path: '/pos', builder: (context, state) => const PosScreen()),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/products/add',
            builder: (context, state) => const ProductFormScreen(),
          ),
          GoRoute(
            path: '/products/edit/:id',
            builder: (context, state) => ProductFormScreen(
              productId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/customers/add',
            builder: (context, state) => const CustomerFormScreen(),
          ),
          GoRoute(
            path: '/customers/edit/:id',
            builder: (context, state) => CustomerFormScreen(
              customerId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: '/suppliers/add',
            builder: (context, state) => const SupplierFormScreen(),
          ),
          GoRoute(
            path: '/suppliers/edit/:id',
            builder: (context, state) => SupplierFormScreen(
              supplierId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/invoices/purchase/new',
            builder: (context, state) => const PurchaseInvoiceScreen(),
          ),
          GoRoute(
            path: '/cash-register',
            builder: (context, state) => const CashRegisterScreen(),
          ),
          GoRoute(
            path: '/units',
            builder: (context, state) => const UnitsScreen(),
          ),
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersManagementScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
});
