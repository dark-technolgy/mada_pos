import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/application/pos_sale_guard_service.dart';
import 'package:mada_pos/features/pos/domain/pos_cart_item.dart';
import 'package:mada_pos/features/pos/domain/pos_pricing.dart';

Product _product({
  required int id,
  required String name,
  double purchasePrice = 10,
  double sellingPrice = 15,
}) {
  return Product(
    id: id,
    nameAr: name,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    minStockLevel: 0,
    isActive: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  late AppDatabase db;
  const service = PosSaleGuardService(maxTotalDiscountPercent: 50);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('detects selling below purchase price', () async {
    final cart = [
      PosCartItem(
        product: _product(id: 1, name: 'X', purchasePrice: 100, sellingPrice: 5),
        quantity: 1,
        baseUnitPrice: 5,
        unitPrice: 5,
        discount: 0,
      ),
    ];
    const summary = PosPricingSummary(
      grossSubtotal: 5,
      lineDiscountTotal: 0,
      subtotal: 5,
      invoiceDiscountAmount: 0,
      taxableBase: 5,
      taxAmount: 0,
      total: 5,
    );

    final result = await service.evaluate(
      db: db,
      cart: cart,
      summary: summary,
      currencyCode: 'IQD',
      exchangeRate: 1,
    );

    expect(
      result.issues.any((i) => i.kind == PosSaleGuardIssueKind.belowCost),
      isTrue,
    );
  });

  test('detects high total discount percent', () async {
    final cart = [
      PosCartItem(
        product: _product(id: 1, name: 'X'),
        quantity: 1,
        baseUnitPrice: 100,
        unitPrice: 100,
        discount: 60,
      ),
    ];
    const summary = PosPricingSummary(
      grossSubtotal: 100,
      lineDiscountTotal: 60,
      subtotal: 40,
      invoiceDiscountAmount: 0,
      taxableBase: 40,
      taxAmount: 0,
      total: 40,
    );

    final result = await service.evaluate(
      db: db,
      cart: cart,
      summary: summary,
      currencyCode: 'IQD',
      exchangeRate: 1,
    );

    expect(
      result.issues.any((i) => i.kind == PosSaleGuardIssueKind.highDiscount),
      isTrue,
    );
  });
}
