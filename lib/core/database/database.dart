import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
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
    AuditLog,
    Backups,
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
      // Future migrations here
    },
  );

  /// Seed initial data on first run
  Future<void> _seedInitialData() async {
    // Default admin user (password: admin123)
    await into(users).insert(
      UsersCompanion.insert(
        username: 'admin',
        passwordHash:
            '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', // sha256 of 'admin123'
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

    // Default warehouse
    await into(warehouses).insert(
      WarehousesCompanion.insert(
        name: 'المخزن الرئيسي',
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
      'company_name': 'KeenX',
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
      'printer_type': 'both', // thermal, a4, both
      'thermal_printer_width': '80', // 58 or 80
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
  }

  String _getSettingsGroup(String key) {
    if (key.startsWith('company_')) return 'company';
    if (key.startsWith('invoice_')) return 'invoice';
    if (key.startsWith('tax_')) return 'tax';
    if (key.startsWith('theme_') || key == 'language') return 'appearance';
    if (key.startsWith('backup_') || key.startsWith('auto_backup')) {
      return 'backup';
    }
    if (key.startsWith('session_')) return 'security';
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
  final file = File(p.join(dbFolder.path, 'keenx_pos', AppConstants.dbName));

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
