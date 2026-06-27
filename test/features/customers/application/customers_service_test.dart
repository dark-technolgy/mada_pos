import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/customers/application/customers_service.dart';

void main() {
  const service = CustomersService();

  test('CustomersService loads customers ordered by name', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Zed'));
    await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Alpha'));

    final customers = await service.loadCustomers(database);

    expect(customers.map((customer) => customer.name).toList(), [
      'Alpha',
      'Zed',
    ]);
  });

  test('CustomersService filters by name phone and email', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Alpha Customer',
            phone: const Value('7500000000'),
            email: const Value('alpha@example.com'),
          ),
        );
    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Beta Customer',
            phone: const Value('7700000000'),
            email: const Value('beta@example.com'),
          ),
        );

    final customers = await database.select(database.customers).get();

    expect(
      service
          .filterCustomers(customers: customers, searchQuery: 'alpha')
          .length,
      1,
    );
    expect(
      service
          .filterCustomers(customers: customers, searchQuery: '7700')
          .single
          .id,
      2,
    );
    expect(
      service
          .filterCustomers(customers: customers, searchQuery: 'example.com')
          .length,
      2,
    );
  });

  test('CustomersService deletes customer', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Delete Me',
            balance: const Value(1000),
          ),
        );

    await service.deleteCustomer(database, customerId);

    final customers = await database.select(database.customers).get();
    expect(customers, isEmpty);
  });
}
