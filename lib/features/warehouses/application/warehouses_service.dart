import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';

class WarehouseFormPayload {
  const WarehouseFormPayload({
    required this.name,
    this.location,
    required this.isDefault,
    required this.isActive,
  });

  final String name;
  final String? location;
  final bool isDefault;
  final bool isActive;
}

class WarehousesService {
  const WarehousesService();

  Future<List<Warehouse>> loadWarehouses(AppDatabase db) {
    return (db.select(db.warehouses)
          ..orderBy([
            (w) => OrderingTerm.desc(w.isDefault),
            (w) => OrderingTerm.asc(w.name),
          ]))
        .get();
  }

  Future<void> saveWarehouse(
    AppDatabase db, {
    Warehouse? warehouse,
    required WarehouseFormPayload payload,
  }) async {
    await db.transaction(() async {
      if (payload.isDefault) {
        await (db.update(db.warehouses)
              ..where((w) => w.isDefault.equals(true)))
            .write(const WarehousesCompanion(isDefault: Value(false)));
      }

      if (warehouse != null) {
        await (db.update(db.warehouses)
              ..where((w) => w.id.equals(warehouse.id)))
            .write(
          WarehousesCompanion(
            name: Value(payload.name),
            location: Value(payload.location),
            isDefault: Value(payload.isDefault),
            isActive: Value(payload.isActive),
          ),
        );
        return;
      }

      await db.into(db.warehouses).insert(
            WarehousesCompanion.insert(
              name: payload.name,
              location: Value(payload.location),
              isDefault: Value(payload.isDefault),
              isActive: Value(payload.isActive),
            ),
          );
    });
  }

  Future<void> deleteWarehouse(AppDatabase db, int warehouseId) async {
    final stockCount = await (db.select(db.stock)
          ..where((s) => s.warehouseId.equals(warehouseId)))
        .get();
    if (stockCount.any((s) => s.quantity > 0)) {
      throw const WarehousesException('has-stock');
    }

    final warehouse = await (db.select(db.warehouses)
          ..where((w) => w.id.equals(warehouseId)))
        .getSingle();
    if (warehouse.isDefault) {
      throw const WarehousesException('default-warehouse');
    }

    await (db.delete(db.warehouses)..where((w) => w.id.equals(warehouseId)))
        .go();
  }
}

class WarehousesException implements Exception {
  const WarehousesException(this.code);
  final String code;

  @override
  String toString() => code;
}
