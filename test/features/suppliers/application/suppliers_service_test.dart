import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/suppliers/application/suppliers_service.dart';

void main() {
  const service = SuppliersService();

  test('SuppliersService loads suppliers sorted by name', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Zeta Supplies'));
    await database
        .into(database.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Alpha Trade'));

    final suppliers = await service.loadSuppliers(database);

    expect(suppliers.map((supplier) => supplier.name).toList(), [
      'Alpha Trade',
      'Zeta Supplies',
    ]);
  });

  test('SuppliersService filters by name phone and company', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: 'Baran',
            phone: const Value('7501'),
            companyName: const Value('North Co'),
          ),
        );
    await database
        .into(database.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: 'Haval',
            phone: const Value('7702'),
            companyName: const Value('South Co'),
          ),
        );

    final suppliers = await service.loadSuppliers(database);

    expect(service.filterSuppliers(suppliers, 'Baran'), hasLength(1));
    expect(service.filterSuppliers(suppliers, '7501'), hasLength(1));
    expect(service.filterSuppliers(suppliers, 'South'), hasLength(1));
  });

  test('SuppliersService deletes supplier by id', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final supplierId = await database
        .into(database.suppliers)
        .insert(SuppliersCompanion.insert(name: 'Delete Me'));

    await service.deleteSupplier(database, supplierId);

    final suppliers = await service.loadSuppliers(database);
    expect(suppliers, isEmpty);
  });
}
