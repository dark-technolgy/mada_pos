import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/inventory/application/stock_transfer_service.dart';

void main() {
  const service = StockTransferService();

  test('transfer moves quantity between warehouses', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final user = await db.select(db.users).getSingle();
    final warehouse = await db.select(db.warehouses).getSingle();
    final productId = await db.into(db.products).insert(
          ProductsCompanion.insert(nameAr: 'Transfer Product'),
        );

    await db.into(db.stock).insert(
          StockCompanion.insert(
            productId: productId,
            warehouseId: warehouse.id,
            quantity: const Value(20),
          ),
        );

    final secondWarehouseId = await db.into(db.warehouses).insert(
          WarehousesCompanion.insert(name: 'فرع 2'),
        );

    await service.transfer(
      db,
      user: user,
      productId: productId,
      fromWarehouseId: warehouse.id,
      toWarehouseId: secondWarehouseId,
      quantity: 5,
    );

    final fromStock = await (db.select(db.stock)
          ..where((s) => s.warehouseId.equals(warehouse.id)))
        .getSingle();
    final toStock = await (db.select(db.stock)
          ..where((s) => s.warehouseId.equals(secondWarehouseId)))
        .getSingle();

    expect(fromStock.quantity, 15);
    expect(toStock.quantity, 5);
  });
}
