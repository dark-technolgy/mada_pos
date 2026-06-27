import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class SupplierFormPayload {
  const SupplierFormPayload({
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.isActive,
  });

  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
}

class SupplierFormService {
  const SupplierFormService();

  Future<Supplier?> loadSupplier(AppDatabase db, int supplierId) {
    return (db.select(
      db.suppliers,
    )..where((supplier) => supplier.id.equals(supplierId))).getSingleOrNull();
  }

  Future<void> saveSupplier(
    AppDatabase db, {
    required SupplierFormPayload payload,
    int? supplierId,
  }) async {
    if (supplierId != null) {
      await (db.update(
        db.suppliers,
      )..where((supplier) => supplier.id.equals(supplierId))).write(
        SuppliersCompanion(
          name: Value(payload.name),
          companyName: Value(payload.companyName),
          phone: Value(payload.phone),
          email: Value(payload.email),
          address: Value(payload.address),
          notes: Value(payload.notes),
          isActive: Value(payload.isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: payload.name,
            companyName: Value(payload.companyName),
            phone: Value(payload.phone),
            email: Value(payload.email),
            address: Value(payload.address),
            notes: Value(payload.notes),
            isActive: Value(payload.isActive),
          ),
        );
  }
}
