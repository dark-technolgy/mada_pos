import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/tax_settings.dart';

class PurchaseInvoiceLine {
  const PurchaseInvoiceLine({
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });

  final int productId;
  final double quantity;
  final double unitCost;
}

class PurchaseFormLoadResult {
  const PurchaseFormLoadResult({
    required this.suppliers,
    required this.products,
    required this.warehouses,
    required this.currencies,
    required this.defaultCurrencyCode,
    required this.defaultExchangeRate,
    required this.defaultWarehouseId,
  });

  final List<Supplier> suppliers;
  final List<Product> products;
  final List<Warehouse> warehouses;
  final List<Currency> currencies;
  final String defaultCurrencyCode;
  final double defaultExchangeRate;
  final int? defaultWarehouseId;
}

class RecordPurchaseResult {
  const RecordPurchaseResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.total,
  });

  final int invoiceId;
  final String invoiceNumber;
  final DateTime createdAt;
  final double total;
}

class PurchaseInvoiceService {
  const PurchaseInvoiceService();

  Future<PurchaseFormLoadResult> loadFormData(AppDatabase db) async {
    final suppliers =
        await (db.select(db.suppliers)
              ..where((s) => s.isActive.equals(true))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
    final products =
        await (db.select(db.products)
              ..where((p) => p.isActive.equals(true))
              ..orderBy([(p) => OrderingTerm.asc(p.nameAr)]))
            .get();
    final warehouses =
        await (db.select(db.warehouses)
              ..where((w) => w.isActive.equals(true))
              ..orderBy([
                (w) => OrderingTerm.desc(w.isDefault),
                (w) => OrderingTerm.asc(w.name),
              ]))
            .get();
    final currencies =
        await (db.select(db.currencies)..orderBy([
              (c) => OrderingTerm.desc(c.isDefault),
              (c) => OrderingTerm.asc(c.code),
            ]))
            .get();

    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);
    final defaultWarehouse =
        warehouses.where((w) => w.isDefault).firstOrNull ?? warehouses.firstOrNull;

    return PurchaseFormLoadResult(
      suppliers: suppliers,
      products: products,
      warehouses: warehouses,
      currencies: currencies,
      defaultCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      defaultExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
      defaultWarehouseId: defaultWarehouse?.id,
    );
  }

  Future<RecordPurchaseResult> recordPurchase(
    AppDatabase db, {
    required User user,
    required List<PurchaseInvoiceLine> lines,
    int? supplierId,
    int? branchId,
    required int warehouseId,
    required String paymentMethod,
    required String currencyCode,
    required double exchangeRate,
    double invoiceDiscount = 0,
    String discountType = 'fixed',
  }) async {
    if (lines.isEmpty) {
      throw const PurchaseInvoiceException('No line items');
    }

    final subtotal = lines.fold<double>(
      0,
      (sum, line) => sum + (line.quantity * line.unitCost),
    );

    final double discountAmount = discountType == 'percentage'
        ? subtotal * (invoiceDiscount.clamp(0, 100) / 100)
        : invoiceDiscount.clamp(0, subtotal).toDouble();

    final taxSettings = await TaxSettingsLoader.load(db);
    final taxBreakdown = TaxCalculator.compute(
      taxableBase: (subtotal - discountAmount).clamp(0.0, double.infinity),
      settings: taxSettings,
    );
    final total = taxBreakdown.total;
    final taxAmount = taxBreakdown.taxAmount;

    final invoiceNumber = await db.getNextInvoiceNumber('purchase');
    final createdAt = DateTime.now();

    final invoiceId = await db
        .into(db.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: invoiceNumber,
            type: 'purchase',
            supplierId: Value(supplierId),
            branchId: Value(branchId),
            userId: user.id,
            warehouseId: Value(warehouseId),
            subtotal: Value(subtotal),
            discountAmount: Value(discountAmount),
            discountType: Value(discountType),
            taxAmount: Value(taxAmount),
            total: Value(total),
            paidAmount: Value(total),
            remaining: const Value(0),
            currencyCode: Value(currencyCode),
            exchangeRate: Value(exchangeRate),
            paymentMethod: Value(paymentMethod),
            status: const Value('paid'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );

    for (final line in lines) {
      final lineTotal = line.quantity * line.unitCost;
      await db
          .into(db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: invoiceId,
              productId: line.productId,
              quantity: line.quantity,
              unitPrice: line.unitCost,
              discount: const Value(0),
              total: lineTotal,
              warehouseId: Value(warehouseId),
            ),
          );

      final existingStock = await (db.select(db.stock)
            ..where((s) => s.productId.equals(line.productId))
            ..where((s) => s.warehouseId.equals(warehouseId)))
          .getSingleOrNull();

      if (existingStock != null) {
        await (db.update(db.stock)..where((s) => s.id.equals(existingStock.id)))
            .write(
              StockCompanion(
                quantity: Value(existingStock.quantity + line.quantity),
                lastUpdated: Value(createdAt),
              ),
            );
      } else {
        await db
            .into(db.stock)
            .insert(
              StockCompanion.insert(
                productId: line.productId,
                warehouseId: warehouseId,
                quantity: Value(line.quantity),
                lastUpdated: Value(createdAt),
              ),
            );
      }

      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: line.productId,
              warehouseToId: Value(warehouseId),
              quantity: line.quantity,
              type: 'in',
              referenceType: const Value('invoice'),
              referenceId: Value(invoiceId),
              userId: Value(user.id),
            ),
          );
    }

    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            invoiceId: Value(invoiceId),
            supplierId: Value(supplierId),
            amount: total,
            currencyCode: Value(currencyCode),
            paymentMethod: Value(paymentMethod),
            userId: Value(user.id),
          ),
        );

    return RecordPurchaseResult(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      createdAt: createdAt,
      total: total,
    );
  }
}

class PurchaseInvoiceException implements Exception {
  const PurchaseInvoiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
