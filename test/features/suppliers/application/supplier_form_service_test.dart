import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/suppliers/application/supplier_form_service.dart';

void main() {
  const service = SupplierFormService();

  test('SupplierFormService creates a new supplier', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await service.saveSupplier(
      database,
      payload: const SupplierFormPayload(
        name: 'Aso',
        companyName: 'Aso Co',
        phone: '7500000000',
        email: 'aso@example.com',
        address: 'Erbil',
        notes: 'Preferred',
        isActive: true,
      ),
    );

    final suppliers = await database.select(database.suppliers).get();
    expect(suppliers, hasLength(1));
    expect(suppliers.single.name, 'Aso');
    expect(suppliers.single.companyName, 'Aso Co');
    expect(suppliers.single.isActive, isTrue);
  });

  test('SupplierFormService loads and updates an existing supplier', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final supplierId = await database
        .into(database.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: 'Old Supplier',
            companyName: const Value('Old Co'),
            phone: const Value('7700000000'),
            isActive: const Value(true),
          ),
        );

    final loaded = await service.loadSupplier(database, supplierId);
    expect(loaded?.name, 'Old Supplier');

    await service.saveSupplier(
      database,
      supplierId: supplierId,
      payload: const SupplierFormPayload(
        name: 'New Supplier',
        companyName: 'New Co',
        phone: '7711111111',
        email: 'new@example.com',
        address: 'Duhok',
        notes: 'Updated',
        isActive: false,
      ),
    );

    final updated = await service.loadSupplier(database, supplierId);
    expect(updated?.name, 'New Supplier');
    expect(updated?.companyName, 'New Co');
    expect(updated?.phone, '7711111111');
    expect(updated?.isActive, isFalse);
  });
}
