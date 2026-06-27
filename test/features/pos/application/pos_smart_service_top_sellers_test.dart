import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/application/pos_smart_service.dart';

void main() {
  late AppDatabase db;
  const service = PosSmartService();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('loadStockTotals sums warehouses per product', () async {
    final whId = await db.into(db.warehouses).insert(
          WarehousesCompanion.insert(name: 'Main'),
        );
    final p1 = await db.into(db.products).insert(
          ProductsCompanion.insert(
            nameAr: 'A',
            purchasePrice: const Value(1),
            sellingPrice: const Value(1),
          ),
        );
    await db.into(db.stock).insert(
          StockCompanion.insert(
            productId: p1,
            warehouseId: whId,
            quantity: const Value(8),
          ),
        );

    final totals = await service.loadStockTotals(db);
    expect(totals[p1], 8);
  });
}
