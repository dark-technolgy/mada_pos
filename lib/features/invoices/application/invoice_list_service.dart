import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import 'invoice_list_filter_state.dart';

class InvoiceListLoadResult {
  const InvoiceListLoadResult({
    required this.invoices,
    required this.customers,
    required this.suppliers,
    required this.itemDiscountTotals,
    required this.currencyMap,
    required this.displayCurrencyCode,
    required this.displayExchangeRate,
    required this.restoredFilterState,
  });

  final List<Invoice> invoices;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final Map<int, double> itemDiscountTotals;
  final Map<String, Currency> currencyMap;
  final String displayCurrencyCode;
  final double displayExchangeRate;
  final InvoiceListFilterState restoredFilterState;
}

class InvoiceListService {
  const InvoiceListService();

  Future<InvoiceListLoadResult> loadScreenData(
    AppDatabase db, {
    required String filtersSettingKey,
  }) async {
    final invoices = await (db.select(
      db.invoices,
    )..orderBy([(invoice) => OrderingTerm.desc(invoice.createdAt)])).get();
    final customers = await db.select(db.customers).get();
    final suppliers = await db.select(db.suppliers).get();
    final currencies = await db.select(db.currencies).get();
    final invoiceItems = await db.select(db.invoiceItems).get();
    final savedFilters =
        await (db.select(db.settings)
              ..where((setting) => setting.key.equals(filtersSettingKey)))
            .getSingleOrNull();

    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);
    final itemDiscountTotals = <int, double>{};
    for (final item in invoiceItems) {
      itemDiscountTotals.update(
        item.invoiceId,
        (value) => value + item.discount,
        ifAbsent: () => item.discount,
      );
    }

    return InvoiceListLoadResult(
      invoices: invoices,
      customers: customers,
      suppliers: suppliers,
      itemDiscountTotals: itemDiscountTotals,
      currencyMap: currencyMap,
      displayCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      displayExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
      restoredFilterState: InvoiceListFilterState.fromJsonString(
        savedFilters?.value,
      ),
    );
  }

  Future<void> persistFilterState(
    AppDatabase db, {
    required String filtersSettingKey,
    required InvoiceListFilterState filterState,
  }) async {
    final payload = filterState.toJsonString();

    try {
      final updatedRows =
          await (db.update(
            db.settings,
          )..where((setting) => setting.key.equals(filtersSettingKey))).write(
            SettingsCompanion(value: Value(payload), group: const Value('ui')),
          );

      if (updatedRows == 0) {
        try {
          await db
              .into(db.settings)
              .insert(
                SettingsCompanion.insert(
                  key: filtersSettingKey,
                  value: payload,
                  group: const Value('ui'),
                ),
              );
        } on Exception {
          await (db.update(
            db.settings,
          )..where((setting) => setting.key.equals(filtersSettingKey))).write(
            SettingsCompanion(value: Value(payload), group: const Value('ui')),
          );
        }
      }
    } on StateError {
      return;
    }
  }

  List<Invoice> filterInvoices({
    required List<Invoice> invoices,
    required int tabIndex,
    required InvoiceListFilterState filterState,
    required Map<int, double> itemDiscountTotals,
    required String Function(Invoice invoice) counterpartyNameResolver,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final startOfToday = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final startOfWeek = startOfToday.subtract(
      Duration(days: effectiveNow.weekday - 1),
    );
    final startOfMonth = DateTime(effectiveNow.year, effectiveNow.month, 1);
    final customFrom = filterState.customFromDate == null
        ? null
        : DateTime(
            filterState.customFromDate!.year,
            filterState.customFromDate!.month,
            filterState.customFromDate!.day,
          );
    final customTo = filterState.customToDate == null
        ? null
        : DateTime(
            filterState.customToDate!.year,
            filterState.customToDate!.month,
            filterState.customToDate!.day,
            23,
            59,
            59,
            999,
          );

    return invoices.where((invoice) {
      if (!_invoiceMatchesTab(invoice.type, tabIndex)) {
        return false;
      }
      if (filterState.dateFilter == 'today' &&
          invoice.createdAt.isBefore(startOfToday)) {
        return false;
      }
      if (filterState.dateFilter == 'thisWeek' &&
          invoice.createdAt.isBefore(startOfWeek)) {
        return false;
      }
      if (filterState.dateFilter == 'thisMonth' &&
          invoice.createdAt.isBefore(startOfMonth)) {
        return false;
      }
      if (filterState.dateFilter == 'custom') {
        if (customFrom != null && invoice.createdAt.isBefore(customFrom)) {
          return false;
        }
        if (customTo != null && invoice.createdAt.isAfter(customTo)) {
          return false;
        }
      }
      if (filterState.statusFilter != 'all' &&
          invoice.status != filterState.statusFilter) {
        return false;
      }
      if (filterState.paymentFilter != 'all' &&
          invoice.paymentMethod != filterState.paymentFilter) {
        return false;
      }
      if (filterState.currencyFilter != 'all' &&
          invoice.currencyCode != filterState.currencyFilter) {
        return false;
      }
      if (filterState.discountOnly) {
        final itemDiscount = itemDiscountTotals[invoice.id] ?? 0;
        if (invoice.discountAmount <= 0 && itemDiscount <= 0) {
          return false;
        }
      }
      if (filterState.searchQuery.isNotEmpty) {
        final q = filterState.searchQuery;
        return invoice.invoiceNumber.contains(q) ||
            counterpartyNameResolver(invoice).contains(q);
      }
      return true;
    }).toList()..sort(
      (left, right) => _compareInvoices(
        left,
        right,
        filterState: filterState,
        counterpartyNameResolver: counterpartyNameResolver,
      ),
    );
  }

  /// Tab 0: sales, 1: purchases, 2: return invoices (`sale_return` / `purchase_return`).
  static bool _invoiceMatchesTab(String invoiceType, int tabIndex) {
    return switch (tabIndex) {
      0 => invoiceType == 'sale',
      1 => invoiceType == 'purchase',
      2 =>
        invoiceType == 'sale_return' || invoiceType == 'purchase_return',
      _ => false,
    };
  }

  List<String> availableCurrencies(List<Invoice> invoices) {
    final codes =
        invoices.map((invoice) => invoice.currencyCode).toSet().toList()
          ..sort();
    return codes;
  }

  int _compareInvoices(
    Invoice left,
    Invoice right, {
    required InvoiceListFilterState filterState,
    required String Function(Invoice invoice) counterpartyNameResolver,
  }) {
    int comparison;
    switch (filterState.sortField) {
      case 'customer':
        comparison = counterpartyNameResolver(left)
            .toLowerCase()
            .compareTo(counterpartyNameResolver(right).toLowerCase());
        break;
      case 'amount':
        final leftBase = CurrencyConversion.toBase(
          left.total,
          currencyCode: left.currencyCode,
          exchangeRate: left.exchangeRate,
        );
        final rightBase = CurrencyConversion.toBase(
          right.total,
          currencyCode: right.currencyCode,
          exchangeRate: right.exchangeRate,
        );
        comparison = leftBase.compareTo(rightBase);
        break;
      case 'date':
      default:
        comparison = left.createdAt.compareTo(right.createdAt);
        break;
    }

    if (comparison == 0) {
      comparison = left.invoiceNumber.compareTo(right.invoiceNumber);
    }

    return filterState.sortAscending ? comparison : -comparison;
  }
}
