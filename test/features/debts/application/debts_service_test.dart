import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/debts/application/debts_service.dart';

void main() {
  const service = DebtsService();

  test(
    'DebtsService loads filters and totals debts across currencies',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final customerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Alpha Customer'));
      final supplierId = await database
          .into(database.suppliers)
          .insert(SuppliersCompanion.insert(name: 'Beta Supplier'));

      await database
          .into(database.debts)
          .insert(
            DebtsCompanion.insert(
              customerId: Value(customerId),
              type: 'receivable',
              originalAmount: 10,
              remainingAmount: 10,
              currencyCode: const Value('USD'),
              status: const Value('active'),
              createdAt: Value(DateTime(2026, 3, 9, 9)),
              updatedAt: Value(DateTime(2026, 3, 9, 9)),
            ),
          );
      await database
          .into(database.debts)
          .insert(
            DebtsCompanion.insert(
              supplierId: Value(supplierId),
              type: 'payable',
              originalAmount: 5000,
              remainingAmount: 5000,
              currencyCode: const Value('IQD'),
              status: const Value('partial'),
              createdAt: Value(DateTime(2026, 3, 8, 9)),
              updatedAt: Value(DateTime(2026, 3, 8, 9)),
            ),
          );

      final loaded = await service.loadScreenData(database);

      expect(loaded.debts, hasLength(2));
      expect(loaded.customers, hasLength(1));
      expect(loaded.suppliers, hasLength(1));
      expect(loaded.displayCurrencyCode, 'IQD');

      final receivables = service.filterDebts(
        debts: loaded.debts,
        tabIndex: 0,
        searchQuery: 'Alpha',
        personNameResolver: (debt) {
          if (debt.customerId == customerId) return 'Alpha Customer';
          if (debt.supplierId == supplierId) return 'Beta Supplier';
          return 'Unknown';
        },
      );
      final payables = service.filterDebts(
        debts: loaded.debts,
        tabIndex: 1,
        searchQuery: '',
        personNameResolver: (debt) {
          if (debt.customerId == customerId) return 'Alpha Customer';
          if (debt.supplierId == supplierId) return 'Beta Supplier';
          return 'Unknown';
        },
      );

      expect(receivables, hasLength(1));
      expect(payables, hasLength(1));
      expect(service.totalReceivable(loaded.debts, loaded.currencyMap), 14800);
      expect(service.totalPayable(loaded.debts, loaded.currencyMap), 5000);
    },
  );

  test('DebtsService filters debts by branch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final branchA = await database.into(database.branches).insert(
          BranchesCompanion.insert(name: 'A', code: const Value('A')),
        );
    final branchB = await database.into(database.branches).insert(
          BranchesCompanion.insert(name: 'B', code: const Value('B')),
        );

    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            type: 'receivable',
            originalAmount: 100,
            remainingAmount: 100,
            branchId: Value(branchA),
          ),
        );
    await database.into(database.debts).insert(
          DebtsCompanion.insert(
            type: 'payable',
            originalAmount: 200,
            remainingAmount: 200,
            branchId: Value(branchB),
          ),
        );

    final branchAOnly = await service.loadScreenData(
      database,
      branchId: branchA,
    );
    expect(branchAOnly.debts, hasLength(1));
    expect(branchAOnly.debts.single.type, 'receivable');
  });
}
