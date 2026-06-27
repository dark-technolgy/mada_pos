import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';

class WarehouseStockRow {
  const WarehouseStockRow({
    required this.warehouse,
    required this.quantity,
  });

  final Warehouse warehouse;
  final double quantity;
}

class InventoryAdjustmentService {
  const InventoryAdjustmentService();

  /// Warehouses with stock for [productId], plus any active warehouse with zero (for inbound).
  Future<List<WarehouseStockRow>> loadWarehouseOptions(
    AppDatabase db, {
    required int productId,
  }) async {
    final warehouses =
        await (db.select(db.warehouses)
              ..where((w) => w.isActive.equals(true))
              ..orderBy([
                (w) => OrderingTerm.desc(w.isDefault),
                (w) => OrderingTerm.asc(w.name),
              ]))
            .get();
    final stocks = await (db.select(db.stock)
          ..where((s) => s.productId.equals(productId)))
        .get();

    final qtyByWarehouse = {for (final s in stocks) s.warehouseId: s.quantity};

    return [
      for (final w in warehouses)
        WarehouseStockRow(
          warehouse: w,
          quantity: qtyByWarehouse[w.id] ?? 0,
        ),
    ];
  }

  Future<void> applyDelta(
    AppDatabase db, {
    required User user,
    required int productId,
    required int warehouseId,
    required double delta,
    String? notes,
  }) async {
    if (delta == 0) {
      throw const InventoryAdjustmentException('Delta cannot be zero');
    }

    final now = DateTime.now();
    final existing = await (db.select(db.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    final previous = existing?.quantity ?? 0;
    final next = previous + delta;
    if (next < 0) {
      throw InventoryAdjustmentException(
        'Insufficient stock (current ${previous.toStringAsFixed(0)}).',
      );
    }

    if (existing != null) {
      await (db.update(db.stock)..where((s) => s.id.equals(existing.id))).write(
        StockCompanion(
          quantity: Value(next),
          lastUpdated: Value(now),
        ),
      );
    } else {
      await db
          .into(db.stock)
          .insert(
            StockCompanion.insert(
              productId: productId,
              warehouseId: warehouseId,
              quantity: Value(next),
              lastUpdated: Value(now),
            ),
          );
    }

    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            productId: productId,
            warehouseToId: delta > 0 ? Value(warehouseId) : const Value.absent(),
            warehouseFromId:
                delta < 0 ? Value(warehouseId) : const Value.absent(),
            quantity: delta.abs(),
            type: 'adjustment',
            referenceType: const Value('adjustment'),
            userId: Value(user.id),
            notes: Value(
              notes ??
                  (delta > 0
                      ? 'adjustment +${delta.toStringAsFixed(2)}'
                      : 'adjustment -${delta.abs().toStringAsFixed(2)}'),
            ),
          ),
        );
  }
}

class InventoryAdjustmentException implements Exception {
  const InventoryAdjustmentException(this.message);
  final String message;

  @override
  String toString() => message;
}
