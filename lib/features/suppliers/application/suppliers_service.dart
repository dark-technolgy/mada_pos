import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/database/database.dart';

class SuppliersService {
  const SuppliersService();

  Future<List<Supplier>> loadSuppliers(AppDatabase db) {
    return (db.select(
      db.suppliers,
    )..orderBy([(supplier) => OrderingTerm.asc(supplier.name)])).get();
  }

  List<Supplier> filterSuppliers(List<Supplier> suppliers, String searchQuery) {
    final normalizedQuery = searchQuery.trim();
    if (normalizedQuery.isEmpty) {
      return List<Supplier>.from(suppliers);
    }

    return suppliers.where((supplier) {
      return supplier.name.contains(normalizedQuery) ||
          (supplier.phone?.contains(normalizedQuery) ?? false) ||
          (supplier.companyName?.contains(normalizedQuery) ?? false);
    }).toList();
  }

  Future<void> deleteSupplier(AppDatabase db, int supplierId) {
    return (db.delete(
      db.suppliers,
    )..where((supplier) => supplier.id.equals(supplierId))).go();
  }
}
