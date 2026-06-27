import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/expenses/application/expenses_service.dart';

void main() {
  const service = ExpensesService();

  test('ExpensesService loads creates filters and deletes expenses', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await service.createExpense(
      database,
      payload: const ExpenseFormPayload(
        category: 'Transport',
        amount: 10,
        currencyCode: 'USD',
        description: 'Taxi',
        userId: 1,
      ),
    );
    await service.createExpense(
      database,
      payload: ExpenseFormPayload(
        category: 'Operations',
        amount: 5000,
        currencyCode: 'IQD',
        description: 'Paper',
        userId: 1,
      ),
    );

    final loaded = await service.loadScreenData(database);

    expect(loaded.expenses, hasLength(2));
    expect(loaded.displayCurrencyCode, 'IQD');

    final filtered = service.filterExpenses(
      expenses: loaded.expenses,
      searchQuery: 'Taxi',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 1)),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.category, 'Transport');
    expect(
      service.totalExpensesBase(loaded.expenses, loaded.currencyMap),
      19800,
    );

    await service.deleteExpense(database, filtered.single.id);

    final remaining = await database.select(database.expenses).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.description, 'Paper');
  });

  test('ExpensesService filters loaded expenses by branch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final branchId = await database.into(database.branches).insert(
          BranchesCompanion.insert(name: 'Main', code: const Value('M')),
        );
    await service.createExpense(
      database,
      payload: ExpenseFormPayload(
        category: 'Branch',
        amount: 42,
        currencyCode: 'IQD',
        branchId: branchId,
      ),
    );
    await service.createExpense(
      database,
      payload: const ExpenseFormPayload(
        category: 'Global',
        amount: 99,
        currencyCode: 'IQD',
      ),
    );

    final branchOnly = await service.loadScreenData(
      database,
      branchId: branchId,
    );
    expect(branchOnly.expenses, hasLength(1));
    expect(branchOnly.expenses.single.amount, 42);
  });

  test('ExpensesService respects date filters inclusively', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            category: 'Old',
            amount: 100,
            description: const Value('Old expense'),
            createdAt: Value(DateTime(2026, 3, 1)),
          ),
        );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            category: 'New',
            amount: 200,
            description: const Value('New expense'),
            createdAt: Value(DateTime(2026, 3, 9, 10)),
          ),
        );

    final loaded = await service.loadScreenData(database);
    final filtered = service.filterExpenses(
      expenses: loaded.expenses,
      searchQuery: '',
      startDate: DateTime(2026, 3, 9),
      endDate: DateTime(2026, 3, 9),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.category, 'New');
  });
}
