import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
import '../security/account_security_service.dart';
import '../security/auth_service.dart';
import '../security/permission_service.dart';
import '../services/branch_context_service.dart';
import 'tables/all_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Units,
    Products,
    Customers,
    Suppliers,
    Warehouses,
    Stock,
    StockMovements,
    Currencies,
    Invoices,
    InvoiceItems,
    Payments,
    Debts,
    DebtPayments,
    Expenses,
    CashRegister,
    Settings,
    Backups,
    RolePermissions,
    Branches,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => AppConstants.dbVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedInitialData();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(invoiceItems, invoiceItems.sourceInvoiceItemId);
      }
      if (from < 3) {
        final existing =
            await (select(settings)..where(
                  (item) => item.key.equals(
                    AccountSecurityService.defaultAdminPasswordKey,
                  ),
                ))
                .getSingleOrNull();
        if (existing == null) {
          await into(settings).insert(
            SettingsCompanion.insert(
              key: AccountSecurityService.defaultAdminPasswordKey,
              value: 'true',
            ),
          );
        }
      }
      if (from < 4) {
        await m.createTable(rolePermissions);
        await const PermissionService().seedDefaultsIfEmpty(this);
      }
      if (from < 5) {
        await m.createTable(branches);
        final defaultBranchId = await into(branches).insert(
          BranchesCompanion.insert(
            name: 'الفرع الرئيسي',
            code: const Value('MAIN'),
            isDefault: const Value(true),
          ),
        );
        await m.addColumn(users, users.branchId);
        await m.addColumn(warehouses, warehouses.branchId);
        await m.addColumn(invoices, invoices.branchId);
        await (update(users)..where((u) => u.branchId.isNull())).write(
          UsersCompanion(branchId: Value(defaultBranchId)),
        );
        await (update(warehouses)..where((w) => w.branchId.isNull())).write(
          WarehousesCompanion(branchId: Value(defaultBranchId)),
        );
        final activeBranchSetting = await (select(settings)..where(
              (s) => s.key.equals(BranchContextService.activeBranchKey),
            ))
            .getSingleOrNull();
        if (activeBranchSetting == null) {
          await into(settings).insert(
            SettingsCompanion.insert(
              key: BranchContextService.activeBranchKey,
              value: '$defaultBranchId',
              group: const Value('general'),
            ),
          );
        }
      }
      if (from < 6) {
        await m.addColumn(debts, debts.branchId);
        await m.addColumn(expenses, expenses.branchId);
        final defaultBranch = await (select(branches)
              ..where((b) => b.isDefault.equals(true))
              ..limit(1))
            .getSingleOrNull();
        final fallbackBranch = defaultBranch ??
            await (select(branches)..limit(1)).getSingleOrNull();
        final defaultBranchId = fallbackBranch?.id;
        if (defaultBranchId != null) {
          await (update(expenses)..where((e) => e.branchId.isNull())).write(
            ExpensesCompanion(branchId: Value(defaultBranchId)),
          );
          await (update(debts)..where((d) => d.branchId.isNull())).write(
            DebtsCompanion(branchId: Value(defaultBranchId)),
          );
          await customStatement('''
UPDATE debts
SET branch_id = (
  SELECT branch_id FROM invoices WHERE invoices.id = debts.invoice_id
)
WHERE invoice_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM invoices
    WHERE invoices.id = debts.invoice_id AND invoices.branch_id IS NOT NULL
  );
''');
        }
      }
    },
  );

  /// Seed initial data on first run
  Future<void> _seedInitialData() async {
    // Default admin user (password: admin123)
    await into(users).insert(
      UsersCompanion.insert(
        username: 'admin',
        passwordHash: AuthService.hashPassword('admin123'),
        fullName: 'مدير النظام',
        role: const Value('admin'),
      ),
    );

    // Default currencies
    await into(currencies).insert(
      CurrenciesCompanion.insert(
        code: 'IQD',
        nameAr: 'دينار عراقي',
        nameEn: 'Iraqi Dinar',
        symbol: 'د.ع',
        exchangeRate: const Value(1.0),
        isDefault: const Value(true),
      ),
    );
    await into(currencies).insert(
      CurrenciesCompanion.insert(
        code: 'USD',
        nameAr: 'دولار أمريكي',
        nameEn: 'US Dollar',
        symbol: '\$',
        exchangeRate: const Value(1480.0), // approximate IQD/USD rate
        isDefault: const Value(false),
      ),
    );

    final defaultBranchId = await into(branches).insert(
      BranchesCompanion.insert(
        name: 'الفرع الرئيسي',
        code: const Value('MAIN'),
        isDefault: const Value(true),
      ),
    );

    // Default warehouse
    await into(warehouses).insert(
      WarehousesCompanion.insert(
        name: 'المخزن الرئيسي',
        branchId: Value(defaultBranchId),
        isDefault: const Value(true),
      ),
    );

    // Default units
    final defaultUnits = [
      ['قطعة', 'Piece', 'دانە', 'pc'],
      ['كرتون', 'Box', 'کارتۆن', 'box'],
      ['كيلوغرام', 'Kilogram', 'کیلۆگرام', 'kg'],
      ['غرام', 'Gram', 'گرام', 'g'],
      ['لتر', 'Liter', 'لیتر', 'L'],
      ['متر', 'Meter', 'مەتر', 'm'],
      ['طقم', 'Set', 'تەقم', 'set'],
      ['زوج', 'Pair', 'جووت', 'pair'],
      ['درزن', 'Dozen', 'دەرزن', 'dz'],
    ];
    for (final u in defaultUnits) {
      await into(units).insert(
        UnitsCompanion.insert(
          nameAr: u[0],
          nameEn: Value(u[1]),
          nameKu: Value(u[2]),
          abbreviation: Value(u[3]),
        ),
      );
    }

    // Default settings
    final defaultSettings = {
      'company_name': 'Mada',
      'company_address': 'بغداد، العراق',
      'company_phone': '',
      'company_email': '',
      'company_logo': '',
      'invoice_prefix_sale': 'INV',
      'invoice_prefix_purchase': 'PUR',
      'invoice_prefix_return': 'RET',
      'invoice_prefix_quote': 'QOT',
      'invoice_notes': '',
      'invoice_terms': '',
      'tax_rate': '0',
      'tax_included': 'false',
      'theme_mode': 'dark',
      'language': 'ar',
      'auto_backup': 'true',
      'backup_interval_hours': '24',
      'session_timeout_minutes': '30',
      'security_require_password_change_admin': 'true',
      'printer_type': 'both', // thermal, a4, both
      'thermal_printer_width': '80', // 58 or 80
      BranchContextService.activeBranchKey: '$defaultBranchId',
      'cloud_backup_enabled': 'false',
      'cloud_backup_path': '',
    };
    for (final entry in defaultSettings.entries) {
      await into(settings).insert(
        SettingsCompanion.insert(
          key: entry.key,
          value: entry.value,
          group: Value(_getSettingsGroup(entry.key)),
        ),
      );
    }

    await const PermissionService().seedDefaultsIfEmpty(this);
  }

  String _getSettingsGroup(String key) {
    if (key.startsWith('company_')) return 'company';
    if (key.startsWith('invoice_')) return 'invoice';
    if (key.startsWith('tax_')) return 'tax';
    if (key.startsWith('theme_') || key == 'language') return 'appearance';
    if (key.startsWith('backup_') ||
        key.startsWith('auto_backup') ||
        key.startsWith('cloud_backup')) {
      return 'backup';
    }
    if (key == BranchContextService.activeBranchKey) return 'general';
    if (key.startsWith('session_') || key.startsWith('security_')) {
      return 'security';
    }
    if (key.startsWith('printer_') || key.startsWith('thermal_')) {
      return 'printer';
    }
    return 'general';
  }

  // ─── HELPER QUERIES ───

  /// Get next invoice number for a given type
  Future<String> getNextInvoiceNumber(String type) async {
    final prefix = switch (type) {
      'sale' => 'INV',
      'purchase' => 'PUR',
      'sale_return' || 'purchase_return' => 'RET',
      'quote' => 'QOT',
      _ => 'INV',
    };

    final lastInvoice =
        await (select(invoices)
              ..where((i) => i.type.equals(type))
              ..orderBy([(i) => OrderingTerm.desc(i.id)])
              ..limit(1))
            .getSingleOrNull();

    int nextNum = 1;
    if (lastInvoice != null) {
      final numStr = lastInvoice.invoiceNumber.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (numStr.isNotEmpty) {
        nextNum = int.parse(numStr) + 1;
      }
    }

    return '$prefix-${nextNum.toString().padLeft(6, '0')}';
  }
}

Future<File> resolveAppDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'mada_pos', AppConstants.dbName));

  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }

  return file;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await resolveAppDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
