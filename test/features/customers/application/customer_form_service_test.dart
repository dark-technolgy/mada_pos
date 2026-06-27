import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/customers/application/customer_form_service.dart';

void main() {
  const service = CustomerFormService();

  test('CustomerFormService creates a new customer', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await service.saveCustomer(
      database,
      payload: const CustomerFormPayload(
        name: 'Alpha Customer',
        phone: '7500000000',
        email: 'alpha@example.com',
        address: 'Erbil',
        notes: 'VIP',
        isActive: true,
      ),
    );

    final customers = await database.select(database.customers).get();
    expect(customers, hasLength(1));
    expect(customers.single.name, 'Alpha Customer');
    expect(customers.single.phone, '7500000000');
    expect(customers.single.email, 'alpha@example.com');
    expect(customers.single.isActive, isTrue);
  });

  test('CustomerFormService loads and updates an existing customer', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Old Name',
            phone: const Value('7700000000'),
            isActive: const Value(true),
          ),
        );

    final loaded = await service.loadCustomer(database, customerId);
    expect(loaded?.name, 'Old Name');

    await service.saveCustomer(
      database,
      customerId: customerId,
      payload: const CustomerFormPayload(
        name: 'New Name',
        phone: '7711111111',
        email: 'new@example.com',
        address: 'Duhok',
        notes: 'Updated',
        isActive: false,
      ),
    );

    final updated = await service.loadCustomer(database, customerId);
    expect(updated?.name, 'New Name');
    expect(updated?.phone, '7711111111');
    expect(updated?.email, 'new@example.com');
    expect(updated?.isActive, isFalse);
  });
}
