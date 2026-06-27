import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class StockTransferService {
  const StockTransferService();

  Future<void> transfer(
    AppDatabase db, {
    required User user,
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required double quantity,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw const StockTransferException('invalid-qty');
    }
    if (fromWarehouseId == toWarehouseId) {
      throw const StockTransferException('same-warehouse');
    }

    final now = DateTime.now();

    await db.transaction(() async {
      final fromStock = await (db.select(db.stock)
            ..where((s) => s.productId.equals(productId))
            ..where((s) => s.warehouseId.equals(fromWarehouseId)))
          .getSingleOrNull();

      final available = fromStock?.quantity ?? 0;
      if (available < quantity) {
        throw StockTransferException(
          'insufficient ($available available)',
        );
      }

      await _applyDelta(
        db,
        productId: productId,
        warehouseId: fromWarehouseId,
        delta: -quantity,
        now: now,
      );
      await _applyDelta(
        db,
        productId: productId,
        warehouseId: toWarehouseId,
        delta: quantity,
        now: now,
      );

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              warehouseFromId: Value(fromWarehouseId),
              warehouseToId: Value(toWarehouseId),
              quantity: quantity,
              type: 'transfer',
              referenceType: const Value('transfer'),
              userId: Value(user.id),
              notes: Value(notes),
            ),
          );
    });
  }

  Future<void> _applyDelta(
    AppDatabase db, {
    required int productId,
    required int warehouseId,
    required double delta,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.stock)..where((s) => s.id.equals(existing.id))).write(
        StockCompanion(
          quantity: Value(existing.quantity + delta),
          lastUpdated: Value(now),
        ),
      );
    } else if (delta > 0) {
      await db.into(db.stock).insert(
            StockCompanion.insert(
              productId: productId,
              warehouseId: warehouseId,
              quantity: Value(delta),
              lastUpdated: Value(now),
            ),
          );
    }
  }
}

class StockTransferException implements Exception {
  const StockTransferException(this.message);
  final String message;

  @override
  String toString() => message;
}
