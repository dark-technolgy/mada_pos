import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/inventory/application/inventory_adjustment_service.dart';

void main() {
  const service = InventoryAdjustmentService();

  test('InventoryAdjustmentService applies positive and negative delta', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Adj Product',
            sellingPrice: const Value(1.0),
          ),
        );
    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(20),
          ),
        );

    await service.applyDelta(
      database,
      user: admin,
      productId: productId,
      warehouseId: warehouse.id,
      delta: 5,
    );

    var row = await (database.select(database.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    expect(row.quantity, 25);

    await service.applyDelta(
      database,
      user: admin,
      productId: productId,
      warehouseId: warehouse.id,
      delta: -7,
    );

    row = await (database.select(database.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    expect(row.quantity, 18);

    final movements = await database.select(database.stockMovements).get();
    expect(movements.length, 2);
    expect(movements.every((m) => m.type == 'adjustment'), isTrue);
  });

  test('InventoryAdjustmentService rejects negative below zero', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();
    final warehouse =
        await (database.select(database.warehouses)..limit(1)).getSingle();
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            nameAr: 'Low Product',
            sellingPrice: const Value(1.0),
          ),
        );
    await database.into(database.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(2),
          ),
        );

    expect(
      () => service.applyDelta(
        database,
        user: admin,
        productId: productId,
        warehouseId: warehouse.id,
        delta: -5,
      ),
      throwsA(isA<InventoryAdjustmentException>()),
    );
  });
}
