import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/invoices/application/invoice_list_filter_state.dart';
import 'package:mada_pos/features/invoices/application/invoices_screen_service.dart';

void main() {
  const service = InvoicesScreenService();

  test('customerNameFor resolves cash, matched, and unknown names', () {
    final customers = [
      Customer(
        id: 1,
        name: 'Known Customer',
        phone: null,
        email: null,
        address: null,
        notes: null,
        balance: 0,
        creditLimit: 0,
        isActive: true,
        createdAt: DateTime(2026, 3, 9),
        updatedAt: DateTime(2026, 3, 9),
      ),
    ];

    expect(
      service.customerNameFor(
        customerId: null,
        customers: customers,
        cashCustomerLabel: 'Cash Customer',
        unknownLabel: 'Unknown',
      ),
      'Cash Customer',
    );
    expect(
      service.customerNameFor(
        customerId: 1,
        customers: customers,
        cashCustomerLabel: 'Cash Customer',
        unknownLabel: 'Unknown',
      ),
      'Known Customer',
    );
    expect(
      service.customerNameFor(
        customerId: 99,
        customers: customers,
        cashCustomerLabel: 'Cash Customer',
        unknownLabel: 'Unknown',
      ),
      'Unknown',
    );
  });

  test('calculateSummary converts mixed currencies into base totals', () {
    final invoices = [
      Invoice(
        id: 1,
        invoiceNumber: 'INV-1',
        type: 'sale',
        customerId: null,
        userId: 1,
        warehouseId: 1,
        subtotal: 10,
        discountAmount: 0,
        discountType: 'fixed',
        taxAmount: 0,
        total: 10,
        paidAmount: 8,
        remaining: 2,
        currencyCode: 'IQD',
        exchangeRate: 1,
        paymentMethod: 'cash',
        status: 'partial',
        isHeld: false,
        notes: null,
        createdAt: DateTime(2026, 3, 9),
        updatedAt: DateTime(2026, 3, 9),
      ),
      Invoice(
        id: 2,
        invoiceNumber: 'INV-2',
        type: 'sale',
        customerId: null,
        userId: 1,
        warehouseId: 1,
        subtotal: 1,
        discountAmount: 0,
        discountType: 'fixed',
        taxAmount: 0,
        total: 1,
        paidAmount: 1,
        remaining: 0,
        currencyCode: 'USD',
        exchangeRate: 1500,
        paymentMethod: 'card',
        status: 'paid',
        isHeld: false,
        notes: null,
        createdAt: DateTime(2026, 3, 9),
        updatedAt: DateTime(2026, 3, 9),
      ),
    ];

    final summary = service.calculateSummary(invoices);

    expect(summary.count, 2);
    expect(summary.totalBase, 1510);
    expect(summary.paidBase, 1508);
    expect(summary.remainingBase, 2);
  });

  test('activeFilterLabels describe current filters and sort', () {
    final labels = service.activeFilterLabels(
      filterState: InvoiceListFilterState(
        searchQuery: '',
        statusFilter: 'paid',
        paymentFilter: 'card',
        currencyFilter: 'USD',
        dateFilter: 'custom',
        customFromDate: DateTime(2026, 3, 1),
        customToDate: DateTime(2026, 3, 9),
        discountOnly: true,
        sortField: 'amount',
        sortAscending: true,
      ),
      labels: const InvoiceActiveFilterLabels(
        date: 'Date',
        today: 'Today',
        thisWeek: 'This Week',
        thisMonth: 'This Month',
        custom: 'Custom',
        all: 'All',
        from: 'From',
        to: 'To',
        status: 'Status',
        paymentMethod: 'Payment Method',
        cash: 'Cash',
        card: 'Card',
        transfer: 'Transfer',
        currency: 'Currency',
        discount: 'Discount',
        sortBy: 'Sort By',
        amount: 'Amount',
        customer: 'Customer',
        ascending: 'Ascending',
        descending: 'Descending',
      ),
      statusLabels: const InvoiceStatusTextLabels(
        paid: 'Paid',
        partial: 'Partial',
        unpaid: 'Unpaid',
        cancelled: 'Cancelled',
      ),
    );

    expect(labels, contains('Date: Custom'));
    expect(labels, contains('Status: Paid'));
    expect(labels, contains('Payment Method: Card'));
    expect(labels, contains('Currency: USD'));
    expect(labels, contains('Discount'));
    expect(labels.last, 'Sort By: Amount Ascending');
  });

  test(
    'loadInvoiceDetails returns related items products and cashier',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final productId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Invoice Product',
              sellingPrice: const Value(10.0),
            ),
          );

      final invoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-DETAIL-1',
              type: 'sale',
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10.0),
              total: const Value(10.0),
              paidAmount: const Value(10.0),
              remaining: const Value(0.0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: invoiceId,
              productId: productId,
              quantity: 1,
              unitPrice: 10,
              total: 10,
              discount: const Value(0),
              warehouseId: const Value(1),
            ),
          );

      final invoice = await (database.select(
        database.invoices,
      )..where((item) => item.id.equals(invoiceId))).getSingle();

      final details = await service.loadInvoiceDetails(database, invoice);

      expect(details.items, hasLength(1));
      expect(details.productsById[productId]?.nameAr, 'Invoice Product');
      expect(details.cashierName, 'مدير النظام');
    },
  );
}
