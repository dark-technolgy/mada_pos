import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/inventory/application/inventory_service.dart';

void main() {
  const service = InventoryService();

  test('InventoryService aggregates stock and derives statuses', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final lowProductId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Low Product',
            minStockLevel: const Value(5),
            sellingPrice: const Value(10),
          ),
        );
    final outProductId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Out Product',
            minStockLevel: const Value(2),
            sellingPrice: const Value(10),
          ),
        );
    final okProductId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Ok Product',
            barcode: const Value('OK-123'),
            minStockLevel: const Value(1),
            sellingPrice: const Value(10),
          ),
        );

    await database
        .into(database.stock)
        .insert(
          StockCompanion.insert(
            productId: lowProductId,
            warehouseId: 1,
            quantity: const Value(3),
          ),
        );
    await database
        .into(database.stock)
        .insert(
          StockCompanion.insert(
            productId: okProductId,
            warehouseId: 1,
            quantity: const Value(7),
          ),
        );

    final result = await service.loadStock(database);

    expect(result.items, hasLength(3));
    expect(result.lowCount, 1);
    expect(result.outCount, 1);
    expect(
      result.items.firstWhere((item) => item.product.id == lowProductId).status,
      'low',
    );
    expect(
      result.items.firstWhere((item) => item.product.id == outProductId).status,
      'out',
    );
    expect(
      result.items.firstWhere((item) => item.product.id == okProductId).status,
      'ok',
    );

    final lowItem =
        result.items.firstWhere((item) => item.product.id == lowProductId);
    expect(lowItem.suggestedReorderQty, 7);
    expect(
      result.items.firstWhere((item) => item.product.id == outProductId)
          .suggestedReorderQty,
      4,
    );
    expect(
      result.items.firstWhere((item) => item.product.id == okProductId)
          .suggestedReorderQty,
      isNull,
    );
  });

  test('InventoryService filters by status and search', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final phoneId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'هاتف',
            barcode: const Value('ABC123'),
            minStockLevel: const Value(5),
            sellingPrice: const Value(10),
          ),
        );
    final keyboardId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'لوحة مفاتيح',
            barcode: const Value('XYZ999'),
            minStockLevel: const Value(1),
            sellingPrice: const Value(10),
          ),
        );

    await database
        .into(database.stock)
        .insert(
          StockCompanion.insert(
            productId: phoneId,
            warehouseId: 1,
            quantity: const Value(0),
          ),
        );
    await database
        .into(database.stock)
        .insert(
          StockCompanion.insert(
            productId: keyboardId,
            warehouseId: 1,
            quantity: const Value(8),
          ),
        );

    final loaded = await service.loadStock(database);

    final outItems = service.filterItems(
      items: loaded.items,
      query: '',
      filter: 'out',
    );
    final searchItems = service.filterItems(
      items: loaded.items,
      query: 'xyz',
      filter: 'all',
    );

    expect(outItems.map((item) => item.product.id), [phoneId]);
    expect(searchItems.map((item) => item.product.id), [keyboardId]);
  });
}
