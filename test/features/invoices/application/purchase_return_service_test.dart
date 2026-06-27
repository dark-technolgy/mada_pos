import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/purchase_return_service.dart';

void main() {
  const service = PurchaseReturnService();

  test('PurchaseReturnService records return and reduces stock', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Purchase return product',
            sellingPrice: const Value(10.0),
          ),
        );

    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(50),
          ),
        );

    final purchaseId = await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'PUR-RET-TEST-1',
            type: 'purchase',
            userId: admin.id,
            warehouseId: Value(warehouse.id),
            subtotal: const Value(100.0),
            total: const Value(100.0),
            paidAmount: const Value(100.0),
            remaining: const Value(0.0),
            currencyCode: const Value('IQD'),
            exchangeRate: const Value(1.0),
            paymentMethod: const Value('cash'),
            status: const Value('paid'),
          ),
        );

    final itemId = await database.into(database.invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            invoiceId: purchaseId,
            productId: productId,
            quantity: 10,
            unitPrice: 10,
            discount: const Value(0),
            total: 100,
            warehouseId: Value(warehouse.id),
          ),
        );

    final result = await service.recordPurchaseReturn(
      database,
      user: admin,
      original: (await (database.select(database.invoices)
                ..where((i) => i.id.equals(purchaseId)))
              .getSingle()),
      lines: [
        PurchaseReturnLine(invoiceItemId: itemId, quantity: 4),
      ],
    );

    expect(result.total, 40.0);

    final returns = await (database.select(database.invoices)
          ..where((i) => i.type.equals('purchase_return')))
        .get();
    expect(returns.length, 1);
    expect(returns.first.returnedFromId, purchaseId);

    final stockRow = await (database.select(database.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    expect(stockRow.quantity, 46);
  });
}
