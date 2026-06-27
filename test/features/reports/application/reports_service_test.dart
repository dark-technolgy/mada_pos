import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/reports/application/reports_service.dart';

void main() {
  const service = ReportsService();

  test(
    'ReportsService aggregates sales purchases expenses and breakdowns',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final categoryId = await database
          .into(database.categories)
          .insert(CategoriesCompanion.insert(nameAr: 'Beverages'));
      final topProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Cola',
              categoryId: Value(categoryId),
              sellingPrice: const Value(10.0),
            ),
          );
      final secondProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Water',
              categoryId: Value(categoryId),
              sellingPrice: const Value(5.0),
            ),
          );

      final now = DateTime(2026, 3, 9, 12);
      final saleUsdId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-USD-001',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(20.0),
              total: const Value(20.0),
              paidAmount: const Value(20.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: saleUsdId,
              productId: topProductId,
              quantity: 2,
              unitPrice: 10,
              total: 20,
              warehouseId: const Value(1),
            ),
          );

      final saleIqdId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-IQD-001',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(5000.0),
              total: const Value(5000.0),
              paidAmount: const Value(5000.0),
              remaining: const Value(0.0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
              createdAt: Value(now.subtract(const Duration(days: 1))),
              updatedAt: Value(now.subtract(const Duration(days: 1))),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: saleIqdId,
              productId: secondProductId,
              quantity: 1,
              unitPrice: 5000,
              total: 5000,
              warehouseId: const Value(1),
            ),
          );

      await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'PUR-001',
              type: 'purchase',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10.0),
              total: const Value(10.0),
              paidAmount: const Value(10.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              category: 'Operations',
              amount: 2000,
              currencyCode: const Value('IQD'),
              description: const Value('Transport'),
              createdAt: Value(now),
            ),
          );

      final result = await service.loadReportData(
        database,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 9, 23, 59),
        unknownLabel: 'Unknown',
        withoutCategoryLabel: 'No Category',
      );

      expect(result.totalSales, 34600);
      expect(result.totalPurchases, 14800);
      expect(result.totalExpenses, 2000);
      expect(result.totalProfit, 17800);

      expect(result.dailySales, hasLength(2));
      expect(result.dailySales.first.amount, 5000);
      expect(result.dailySales.last.amount, 29600);

      expect(result.topProducts.map((item) => item.name).toList(), [
        'Cola',
        'Water',
      ]);
      expect(result.topProducts.first.total, 29600);

      expect(result.categorySales, hasLength(1));
      expect(result.categorySales.first.name, 'Beverages');
      expect(result.categorySales.first.total, 34600);
      expect(result.reportCurrencyCode, 'IQD');
      expect(result.reportExchangeRate, 1.0);
    },
  );

  test('ReportsService filters sales and purchases by branch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final branchA = await database.into(database.branches).insert(
          BranchesCompanion.insert(name: 'Branch A', code: const Value('A')),
        );
    final branchB = await database.into(database.branches).insert(
          BranchesCompanion.insert(name: 'Branch B', code: const Value('B')),
        );

    final now = DateTime(2026, 3, 9, 12);
    await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'SALE-A',
            type: 'sale',
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(1000),
            total: const Value(1000),
            branchId: Value(branchA),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'SALE-B',
            type: 'sale',
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(5000),
            total: const Value(5000),
            branchId: Value(branchB),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await database.into(database.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'PUR-B',
            type: 'purchase',
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(2000),
            total: const Value(2000),
            branchId: Value(branchB),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    final filtered = await service.loadReportData(
      database,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 31),
      unknownLabel: 'Unknown',
      withoutCategoryLabel: 'No Category',
      branchId: branchA,
    );

    expect(filtered.totalSales, 1000);
    expect(filtered.totalPurchases, 0);
    expect(filtered.totalProfit, 1000);

    await database.into(database.expenses).insert(
          ExpensesCompanion.insert(
            category: 'Ops',
            amount: 300,
            branchId: Value(branchA),
            createdAt: Value(now),
          ),
        );
    await database.into(database.expenses).insert(
          ExpensesCompanion.insert(
            category: 'Ops',
            amount: 900,
            branchId: Value(branchB),
            createdAt: Value(now),
          ),
        );

    final withExpenses = await service.loadReportData(
      database,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 31),
      unknownLabel: 'Unknown',
      withoutCategoryLabel: 'No Category',
      branchId: branchA,
    );
    expect(withExpenses.totalExpenses, 300);
  });
}
