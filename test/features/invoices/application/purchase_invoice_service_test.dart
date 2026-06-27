import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/purchase_invoice_service.dart';

void main() {
  const service = PurchaseInvoiceService();

  test('PurchaseInvoiceService records purchase and increases stock', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Stocked Product',
            purchasePrice: const Value(5.0),
            sellingPrice: const Value(8.0),
          ),
        );
    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(10),
          ),
        );

    final result = await service.recordPurchase(
      database,
      user: admin,
      lines: [
        PurchaseInvoiceLine(productId: productId, quantity: 3, unitCost: 4),
      ],
      supplierId: null,
      warehouseId: warehouse.id,
      paymentMethod: 'cash',
      currencyCode: 'IQD',
      exchangeRate: 1,
    );

    expect(result.invoiceNumber, startsWith('PUR-'));

    final invoices = await database.select(database.invoices).get();
    final purchase = invoices.firstWhere((i) => i.id == result.invoiceId);
    expect(purchase.type, 'purchase');
    expect(purchase.total, 12);

    final stockRow = await (database.select(database.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    expect(stockRow.quantity, 13);

    final movements = await database.select(database.stockMovements).get();
    expect(movements.where((m) => m.referenceId == result.invoiceId).length, 1);
    expect(
      movements.firstWhere((m) => m.referenceId == result.invoiceId).type,
      'in',
    );
  });
}
