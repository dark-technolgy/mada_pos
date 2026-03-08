import 'package:drift/drift.dart';

/// Users table - المستخدمين
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 3, max: 50).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();
  TextColumn get role => text().withDefault(
    const Constant('cashier'),
  )(); // admin, manager, cashier, viewer
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get pin => text().nullable()();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Categories table - الأصناف
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameAr => text().withLength(min: 1, max: 100)();
  TextColumn get nameEn => text().withLength(min: 1, max: 100).nullable()();
  TextColumn get nameKu => text().withLength(min: 1, max: 100).nullable()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Units table - الوحدات
class Units extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameAr => text().withLength(min: 1, max: 50)();
  TextColumn get nameEn => text().withLength(min: 1, max: 50).nullable()();
  TextColumn get nameKu => text().withLength(min: 1, max: 50).nullable()();
  TextColumn get abbreviation =>
      text().withLength(min: 1, max: 10).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Products table - المنتجات
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameAr => text().withLength(min: 1, max: 200)();
  TextColumn get nameEn => text().withLength(min: 1, max: 200).nullable()();
  TextColumn get nameKu => text().withLength(min: 1, max: 200).nullable()();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get sku => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get unitId => integer().nullable().references(Units, #id)();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get minStockLevel => real().withDefault(const Constant(0.0))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Customers table - العملاء
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Suppliers table - الموردين
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get companyName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Warehouses table - المخازن
class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get location => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stock table - المخزون
class Stock extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, warehouseId},
  ];
}

/// Stock Movements table - حركات المخزون
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  @ReferenceName('stockMovementsFrom')
  IntColumn get warehouseFromId =>
      integer().nullable().references(Warehouses, #id)();
  @ReferenceName('stockMovementsTo')
  IntColumn get warehouseToId =>
      integer().nullable().references(Warehouses, #id)();
  RealColumn get quantity => real()();
  TextColumn get type => text()(); // in, out, transfer, adjustment
  IntColumn get referenceId => integer().nullable()();
  TextColumn get referenceType =>
      text().nullable()(); // invoice, adjustment, transfer
  IntColumn get userId => integer().nullable().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Currencies table - العملات
class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 3, max: 3).unique()();
  TextColumn get nameAr => text()();
  TextColumn get nameEn => text()();
  TextColumn get symbol => text()();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Invoices table - الفواتير
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get type =>
      text()(); // sale, purchase, sale_return, purchase_return, quote
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  TextColumn get discountType =>
      text().withDefault(const Constant('fixed'))(); // fixed, percentage
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get remaining => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  TextColumn get paymentMethod => text().withDefault(
    const Constant('cash'),
  )(); // cash, card, transfer, split
  TextColumn get status => text().withDefault(
    const Constant('paid'),
  )(); // paid, partial, unpaid, draft, cancelled
  TextColumn get notes => text().nullable()();
  BoolColumn get isHeld => boolean().withDefault(const Constant(false))();
  IntColumn get returnedFromId =>
      integer().nullable().references(Invoices, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Invoice Items table - عناصر الفاتورة
class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  IntColumn get warehouseId =>
      integer().nullable().references(Warehouses, #id)();
}

/// Payments table - المدفوعات
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  RealColumn get amount => real()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Debts table - الديون
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  TextColumn get type => text()(); // receivable (مدين), payable (دائن)
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  RealColumn get originalAmount => real()();
  RealColumn get remainingAmount => real()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // active, partial, settled, written_off
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Debt Payments table - دفعات الديون
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Expenses table - المصروفات
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get description => text().nullable()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cash Register table - الصندوق
class CashRegister extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  RealColumn get openingAmount => real().withDefault(const Constant(0.0))();
  RealColumn get closingAmount => real().nullable()();
  RealColumn get actualAmount => real().nullable()();
  RealColumn get difference => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

/// Settings table - الإعدادات
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get group => text().withDefault(const Constant('general'))();
}

/// Audit Log table - سجل المراجعة
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  TextColumn get action => text()(); // create, update, delete, login, logout
  TextColumn get targetTable => text()();
  IntColumn get recordId => integer().nullable()();
  TextColumn get oldValues => text().nullable()();
  TextColumn get newValues => text().nullable()();
  TextColumn get details => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Backups table - النسخ الاحتياطية
class Backups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get type => text()(); // local, cloud
  TextColumn get status => text()(); // success, failed
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
