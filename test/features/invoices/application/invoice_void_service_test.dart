import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/invoice_void_service.dart';
import 'package:mada_pos/features/invoices/application/purchase_invoice_service.dart';
import 'package:mada_pos/features/pos/application/pos_sale_service.dart';
import 'package:mada_pos/features/pos/domain/pos_cart_item.dart';
import 'package:mada_pos/features/pos/domain/pos_payment_split.dart';
import 'package:mada_pos/features/pos/domain/pos_pricing.dart';

Future<Product> _insertProductWithStock(AppDatabase db) async {
  final warehouse = await db.select(db.warehouses).getSingle();
  final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          nameAr: 'Test Product',
          sellingPrice: const Value(10),
        ),
      );
  await db.into(db.stock).insert(
        StockCompanion.insert(
          productId: productId,
          warehouseId: warehouse.id,
          quantity: const Value(100),
        ),
      );
  return (db.select(db.products)..where((p) => p.id.equals(productId)))
      .getSingle();
}

void main() {
  const voidService = InvoiceVoidService();
  const purchaseService = PurchaseInvoiceService();

  test('voiding a sale restores stock and marks invoice cancelled', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final user = await db.select(db.users).getSingle();
    final product = await _insertProductWithStock(db);

    final saleService = PosSaleService(db);
    final summary = PosPricing.summarize(
      lines: const [
        PosLinePricing(quantity: 2, unitPrice: 10, discount: 0),
      ],
      invoiceDiscount: 0,
      discountType: 'fixed',
    );

    final sale = await saleService.completeSale(
      user: user,
      cart: [
        PosCartItem(
          product: product,
          quantity: 2,
          baseUnitPrice: product.sellingPrice,
          unitPrice: 10,
          discount: 0,
        ),
      ],
      customer: null,
      summary: summary,
      discountType: 'fixed',
      paymentSplits: const [
        PosPaymentSplit(method: 'cash', amount: 20),
      ],
      currencyCode: 'IQD',
      exchangeRate: 1,
    );

    final stockBeforeVoid = await (db.select(db.stock)
          ..where((s) => s.productId.equals(product.id)))
        .getSingle();

    final invoice = await (db.select(db.invoices)
          ..where((i) => i.id.equals(sale.invoiceId)))
        .getSingle();

    await voidService.voidInvoice(db, invoice: invoice, user: user);

    final updatedInvoice = await (db.select(db.invoices)
          ..where((i) => i.id.equals(sale.invoiceId)))
        .getSingle();
    final stockAfterVoid = await (db.select(db.stock)
          ..where((s) => s.productId.equals(product.id)))
        .getSingle();

    expect(updatedInvoice.status, 'cancelled');
    expect(stockAfterVoid.quantity, stockBeforeVoid.quantity + 2);
  });

  test('cannot void invoice that already has returns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final user = await db.select(db.users).getSingle();
    final product = await _insertProductWithStock(db);
    final warehouse = await db.select(db.warehouses).getSingle();

    final purchase = await purchaseService.recordPurchase(
      db,
      user: user,
      lines: [
        PurchaseInvoiceLine(
          productId: product.id,
          quantity: 1,
          unitCost: 5,
        ),
      ],
      supplierId: null,
      warehouseId: warehouse.id,
      paymentMethod: 'cash',
      currencyCode: 'IQD',
      exchangeRate: 1,
    );

    final invoice = await (db.select(db.invoices)
          ..where((i) => i.id.equals(purchase.invoiceId)))
        .getSingle();

    await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'RET-TEST',
            type: 'purchase_return',
            userId: user.id,
            returnedFromId: Value(purchase.invoiceId),
            subtotal: const Value(5),
            total: const Value(5),
          ),
        );

    expect(
      () => voidService.voidInvoice(db, invoice: invoice, user: user),
      throwsA(isA<InvoiceVoidException>()),
    );
  });
}
