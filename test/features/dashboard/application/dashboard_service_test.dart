import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/dashboard/application/dashboard_service.dart';

void main() {
  const service = DashboardService();

  test(
    'DashboardService aggregates stats recent invoices and low stock',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Customer A'));
      final lowStockProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Low Stock Product',
              minStockLevel: const Value(5),
              sellingPrice: const Value(10),
            ),
          );
      final healthyProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Healthy Product',
              minStockLevel: const Value(2),
              sellingPrice: const Value(15),
            ),
          );

      await database
          .into(database.stock)
          .insert(
            StockCompanion.insert(
              productId: lowStockProductId,
              warehouseId: 1,
              quantity: const Value(3),
            ),
          );
      await database
          .into(database.stock)
          .insert(
            StockCompanion.insert(
              productId: healthyProductId,
              warehouseId: 1,
              quantity: const Value(10),
            ),
          );

      final now = DateTime(2026, 3, 9, 12);
      await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-TODAY-001',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(18),
              discountAmount: const Value(2),
              total: const Value(20),
              paidAmount: const Value(20),
              remaining: const Value(0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480),
              status: const Value('paid'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-MONTH-001',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10000),
              total: const Value(10000),
              paidAmount: const Value(10000),
              remaining: const Value(0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1),
              status: const Value('paid'),
              createdAt: Value(DateTime(2026, 3, 2, 10)),
              updatedAt: Value(DateTime(2026, 3, 2, 10)),
            ),
          );
      await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-DRAFT-001',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(999),
              total: const Value(999),
              paidAmount: const Value(0),
              remaining: const Value(999),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1),
              status: const Value('draft'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await database
          .into(database.debts)
          .insert(
            DebtsCompanion.insert(
              type: 'receivable',
              originalAmount: 10,
              remainingAmount: 10,
              currencyCode: const Value('USD'),
              status: const Value('active'),
            ),
          );

      final result = await service.loadDashboardData(database, now: now);

      expect(result.stats.todaySales, 29600);
      expect(result.stats.todayCount, 1);
      expect(result.stats.todayProfit, closeTo(29600, 1));
      expect(result.stats.overdueDebtsCount, 0);
      expect(result.stats.heldInvoicesCount, 0);
      expect(result.stats.monthlySales, 39600);
      expect(result.stats.monthlyCount, 2);
      expect(result.stats.totalProducts, 2);
      expect(result.stats.totalCustomers, 1);
      expect(result.stats.totalDebts, 14800);

      expect(
        result.recentInvoices.map((invoice) => invoice.number),
        contains('INV-TODAY-001'),
      );
      expect(
        result.recentInvoices.map((invoice) => invoice.number),
        isNot(contains('INV-DRAFT-001')),
      );

      expect(result.lowStockProducts, hasLength(1));
      expect(result.lowStockProducts.first.name, 'Low Stock Product');
      expect(result.lowStockProducts.first.stock, 3);
      expect(result.lowStockProducts.first.minStock, 5);
      expect(result.displayCurrencyCode, 'IQD');
    },
  );
}
