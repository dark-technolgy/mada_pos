import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';

class UnitFormPayload {
  const UnitFormPayload({
    required this.nameAr,
    this.nameEn,
    this.nameKu,
    this.abbreviation,
    required this.isActive,
  });

  final String nameAr;
  final String? nameEn;
  final String? nameKu;
  final String? abbreviation;
  final bool isActive;
}

class UnitsService {
  const UnitsService();

  Future<List<Unit>> loadUnits(AppDatabase db) {
    return (db.select(db.units)..orderBy([(u) => OrderingTerm.asc(u.nameAr)]))
        .get();
  }

  Future<void> saveUnit(
    AppDatabase db, {
    Unit? unit,
    required UnitFormPayload payload,
  }) async {
    if (unit != null) {
      await (db.update(db.units)..where((u) => u.id.equals(unit.id))).write(
        UnitsCompanion(
          nameAr: Value(payload.nameAr),
          nameEn: Value(payload.nameEn),
          nameKu: Value(payload.nameKu),
          abbreviation: Value(payload.abbreviation),
          isActive: Value(payload.isActive),
        ),
      );
      return;
    }

    await db.into(db.units).insert(
          UnitsCompanion.insert(
            nameAr: payload.nameAr,
            nameEn: Value(payload.nameEn),
            nameKu: Value(payload.nameKu),
            abbreviation: Value(payload.abbreviation),
            isActive: Value(payload.isActive),
          ),
        );
  }

  Future<void> deleteUnit(AppDatabase db, int unitId) async {
    final inUse = await (db.select(db.products)
          ..where((p) => p.unitId.equals(unitId))
          ..limit(1))
        .getSingleOrNull();
    if (inUse != null) {
      throw const UnitsException('in-use');
    }
    await (db.delete(db.units)..where((u) => u.id.equals(unitId))).go();
  }
}

class UnitsException implements Exception {
  const UnitsException(this.code);
  final String code;

  @override
  String toString() => code;
}
