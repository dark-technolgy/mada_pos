import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/sale_return_service.dart';

void main() {
  const service = SaleReturnService();

  test('SaleReturnService records return and restores stock', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Return Product',
            sellingPrice: const Value(10.0),
          ),
        );

    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(100),
          ),
        );

    final saleId = await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-RET-TEST-1',
            type: 'sale',
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
            invoiceId: saleId,
            productId: productId,
            quantity: 10,
            unitPrice: 10,
            discount: const Value(0),
            total: 100,
            warehouseId: Value(warehouse.id),
          ),
        );

    await (database.update(database.stock)
          ..where((s) => s.productId.equals(productId)))
        .write(
          StockCompanion(
            quantity: const Value(90),
            lastUpdated: Value(DateTime.now()),
          ),
        );

    final result = await service.recordSaleReturn(
      database,
      user: admin,
      original: (await (database.select(database.invoices)
                ..where((i) => i.id.equals(saleId)))
              .getSingle()),
      lines: [
        SaleReturnLine(invoiceItemId: itemId, quantity: 3),
      ],
    );

    expect(result.total, 30.0);

    final returns = await (database.select(database.invoices)
          ..where((i) => i.type.equals('sale_return')))
        .get();
    expect(returns.length, 1);
    expect(returns.first.returnedFromId, saleId);

    final stockRow = await (database.select(database.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    expect(stockRow.quantity, 93);
  });

  test('SaleReturnService reduces customer balance when customer is set',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();

    final customerId = await database.into(database.customers).insert(
          CustomersCompanion.insert(
            name: 'Balance Customer',
            balance: const Value(100.0),
          ),
        );

    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Bal Product',
            sellingPrice: const Value(5.0),
          ),
        );

    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(20),
          ),
        );

    final saleId = await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-BAL-1',
            type: 'sale',
            customerId: Value(customerId),
            userId: admin.id,
            warehouseId: Value(warehouse.id),
            subtotal: const Value(50.0),
            total: const Value(50.0),
            paidAmount: const Value(50.0),
            remaining: const Value(0.0),
            currencyCode: const Value('IQD'),
            exchangeRate: const Value(1.0),
            paymentMethod: const Value('cash'),
            status: const Value('paid'),
          ),
        );

    final itemId = await database.into(database.invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            invoiceId: saleId,
            productId: productId,
            quantity: 10,
            unitPrice: 5,
            discount: const Value(0),
            total: 50,
            warehouseId: Value(warehouse.id),
          ),
        );

    await (database.update(database.stock)
          ..where((s) => s.productId.equals(productId)))
        .write(
          StockCompanion(
            quantity: const Value(10),
            lastUpdated: Value(DateTime.now()),
          ),
        );

    await service.recordSaleReturn(
      database,
      user: admin,
      original: (await (database.select(database.invoices)
                ..where((i) => i.id.equals(saleId)))
              .getSingle()),
      lines: [
        SaleReturnLine(invoiceItemId: itemId, quantity: 2),
      ],
    );

    final customer = await (database.select(database.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingle();
    expect(customer.balance, 90.0);
  });
}
