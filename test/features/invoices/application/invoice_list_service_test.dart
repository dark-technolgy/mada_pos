import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/invoice_list_filter_state.dart';
import 'package:mada_pos/features/invoices/application/invoice_list_service.dart';

void main() {
  const filtersSettingKey = 'invoices_last_filters';
  const service = InvoiceListService();

  test('InvoiceListFilterState parses invalid payload safely', () {
    final state = InvoiceListFilterState.fromJsonString('{invalid');

    expect(state.searchQuery, isEmpty);
    expect(state.statusFilter, 'all');
    expect(state.sortField, 'date');
    expect(state.sortAscending, isFalse);
  });

  test('InvoiceListService persists and restores filter state', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final filterState = InvoiceListFilterState(
      searchQuery: 'INV-2026',
      statusFilter: 'paid',
      paymentFilter: 'card',
      currencyFilter: 'USD',
      dateFilter: 'custom',
      customFromDate: DateTime(2026, 3, 1),
      customToDate: DateTime(2026, 3, 9),
      discountOnly: true,
      sortField: 'customer',
      sortAscending: true,
    );

    await service.persistFilterState(
      database,
      filtersSettingKey: filtersSettingKey,
      filterState: filterState,
    );

    final restored = await service.loadScreenData(
      database,
      filtersSettingKey: filtersSettingKey,
    );

    expect(restored.restoredFilterState.searchQuery, filterState.searchQuery);
    expect(restored.restoredFilterState.statusFilter, filterState.statusFilter);
    expect(
      restored.restoredFilterState.paymentFilter,
      filterState.paymentFilter,
    );
    expect(
      restored.restoredFilterState.currencyFilter,
      filterState.currencyFilter,
    );
    expect(restored.restoredFilterState.dateFilter, filterState.dateFilter);
    expect(
      restored.restoredFilterState.customFromDate,
      filterState.customFromDate,
    );
    expect(restored.restoredFilterState.customToDate, filterState.customToDate);
    expect(restored.restoredFilterState.discountOnly, isTrue);
    expect(restored.restoredFilterState.sortField, 'customer');
    expect(restored.restoredFilterState.sortAscending, isTrue);
  });

  test(
    'InvoiceListService filters and sorts invoices for the active tab',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final alphaCustomerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Alpha Customer'));
      final zuluCustomerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Zulu Customer'));
      final productId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Invoice Service Product',
              sellingPrice: const Value(10.0),
            ),
          );

      final alphaInvoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-ALPHA-001',
              type: 'sale',
              customerId: Value(alphaCustomerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10.0),
              discountAmount: const Value(1.0),
              total: const Value(9.0),
              paidAmount: const Value(9.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('card'),
              status: const Value('paid'),
              createdAt: Value(DateTime(2026, 3, 8, 10, 0)),
              updatedAt: Value(DateTime(2026, 3, 8, 10, 0)),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: alphaInvoiceId,
              productId: productId,
              quantity: 1,
              unitPrice: 10,
              discount: const Value(0),
              total: 10,
              warehouseId: const Value(1),
            ),
          );

      final zuluInvoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-ZULU-001',
              type: 'sale',
              customerId: Value(zuluCustomerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(20.0),
              total: const Value(20.0),
              paidAmount: const Value(20.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('card'),
              status: const Value('paid'),
              createdAt: Value(DateTime(2026, 3, 7, 10, 0)),
              updatedAt: Value(DateTime(2026, 3, 7, 10, 0)),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: zuluInvoiceId,
              productId: productId,
              quantity: 1,
              unitPrice: 20,
              discount: const Value(2),
              total: 20,
              warehouseId: const Value(1),
            ),
          );

      await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-PURCHASE-001',
              type: 'purchase',
              customerId: Value(alphaCustomerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(12.0),
              total: const Value(12.0),
              paidAmount: const Value(12.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('card'),
              status: const Value('paid'),
              createdAt: Value(DateTime(2026, 3, 8, 9, 0)),
              updatedAt: Value(DateTime(2026, 3, 8, 9, 0)),
            ),
          );

      final loaded = await service.loadScreenData(
        database,
        filtersSettingKey: filtersSettingKey,
      );

      final filtered = service.filterInvoices(
        invoices: loaded.invoices,
        tabIndex: 0,
        filterState: const InvoiceListFilterState(
          paymentFilter: 'card',
          currencyFilter: 'USD',
          discountOnly: true,
          sortField: 'customer',
          sortAscending: false,
        ),
        itemDiscountTotals: loaded.itemDiscountTotals,
        counterpartyNameResolver: (invoice) {
          final customer = loaded.customers.firstWhere(
            (entry) => entry.id == invoice.customerId,
          );
          return customer.name;
        },
        now: DateTime(2026, 3, 9, 12, 0),
      );

      expect(filtered.map((invoice) => invoice.invoiceNumber).toList(), [
        'INV-ZULU-001',
        'INV-ALPHA-001',
      ]);
    },
  );

  test(
    'InvoiceListService returns tab includes sale_return and purchase_return',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.into(database.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'RET-SALE-001',
              type: 'sale_return',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(5.0),
              total: const Value(5.0),
              paidAmount: const Value(5.0),
              remaining: const Value(0.0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
            ),
          );
      await database.into(database.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'RET-PUR-001',
              type: 'purchase_return',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(3.0),
              total: const Value(3.0),
              paidAmount: const Value(3.0),
              remaining: const Value(0.0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
            ),
          );

      final loaded = await service.loadScreenData(
        database,
        filtersSettingKey: filtersSettingKey,
      );

      final returnsTab = service.filterInvoices(
        invoices: loaded.invoices,
        tabIndex: 2,
        filterState: const InvoiceListFilterState(),
        itemDiscountTotals: loaded.itemDiscountTotals,
        counterpartyNameResolver: (_) => '',
      );

      expect(
        returnsTab.map((i) => i.invoiceNumber).toList()..sort(),
        ['RET-PUR-001', 'RET-SALE-001'],
      );

      final salesTab = service.filterInvoices(
        invoices: loaded.invoices,
        tabIndex: 0,
        filterState: const InvoiceListFilterState(),
        itemDiscountTotals: loaded.itemDiscountTotals,
        counterpartyNameResolver: (_) => '',
      );

      expect(salesTab, isEmpty);
    },
  );
}
