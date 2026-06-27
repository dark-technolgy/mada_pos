import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';

class ReportTimePoint {
  const ReportTimePoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}

class ReportBreakdownItem {
  const ReportBreakdownItem({required this.name, required this.total});

  final String name;
  final double total;
}

class ReportsLoadResult {
  const ReportsLoadResult({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalProfit,
    required this.dailySales,
    required this.topProducts,
    required this.categorySales,
    required this.currencyMap,
    required this.reportCurrencyCode,
    required this.reportExchangeRate,
  });

  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalProfit;
  final List<ReportTimePoint> dailySales;
  final List<ReportBreakdownItem> topProducts;
  final List<ReportBreakdownItem> categorySales;
  final Map<String, Currency> currencyMap;
  final String reportCurrencyCode;
  final double reportExchangeRate;
}

class ReportsService {
  const ReportsService();

  Future<ReportsLoadResult> loadReportData(
    AppDatabase db, {
    required DateTime startDate,
    required DateTime endDate,
    required String unknownLabel,
    required String withoutCategoryLabel,
    int? branchId,
  }) async {
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);
    final rangeStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final rangeEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final salesQuery = db.select(db.invoices)
      ..where((i) => i.type.equals('sale'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(rangeStart))
      ..where((i) => i.createdAt.isSmallerOrEqualValue(rangeEnd));
    if (branchId != null) {
      salesQuery.where((i) => i.branchId.equals(branchId));
    }
    final salesInvoices = await salesQuery.get();

    final purchaseQuery = db.select(db.invoices)
      ..where((i) => i.type.equals('purchase'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(rangeStart))
      ..where((i) => i.createdAt.isSmallerOrEqualValue(rangeEnd));
    if (branchId != null) {
      purchaseQuery.where((i) => i.branchId.equals(branchId));
    }
    final purchaseInvoices = await purchaseQuery.get();

    final expensesQuery = db.select(db.expenses)
      ..where((e) => e.createdAt.isBiggerOrEqualValue(rangeStart))
      ..where((e) => e.createdAt.isSmallerOrEqualValue(rangeEnd));
    if (branchId != null) {
      expensesQuery.where((e) => e.branchId.equals(branchId));
    }
    final filteredExpenses = await expensesQuery.get();

    double toBase(Invoice invoice) => CurrencyConversion.toBase(
      invoice.total,
      currencyCode: invoice.currencyCode,
      exchangeRate: invoice.exchangeRate,
    );

    final totalSales = salesInvoices.fold<double>(0, (s, i) => s + toBase(i));
    final totalPurchases =
        purchaseInvoices.fold<double>(0, (s, i) => s + toBase(i));
    final totalExpenses = filteredExpenses.fold<double>(
      0,
      (sum, expense) =>
          sum +
          CurrencyConversion.toBase(
            expense.amount,
            currencyCode: expense.currencyCode,
            currencies: currencyMap,
          ),
    );
    final totalProfit = totalSales - totalPurchases - totalExpenses;

    final dailySalesMap = <DateTime, double>{};
    for (final invoice in salesInvoices) {
      final day = DateTime(
        invoice.createdAt.year,
        invoice.createdAt.month,
        invoice.createdAt.day,
      );
      dailySalesMap[day] = (dailySalesMap[day] ?? 0) + toBase(invoice);
    }
    final dailySales = dailySalesMap.entries
        .map((e) => ReportTimePoint(date: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final saleIds = salesInvoices.map((i) => i.id).toList();
    final saleInvoicesById = {for (final i in salesInvoices) i.id: i};
    final productSales = <int, double>{};

    if (saleIds.isNotEmpty) {
      final items = await (db.select(db.invoiceItems)
            ..where((item) => item.invoiceId.isIn(saleIds)))
          .get();
      for (final item in items) {
        final invoice = saleInvoicesById[item.invoiceId];
        if (invoice == null) continue;
        productSales[item.productId] =
            (productSales[item.productId] ?? 0) +
            CurrencyConversion.toBase(
              item.total,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            );
      }
    }

    final products = productSales.keys.isEmpty
        ? <Product>[]
        : await (db.select(db.products)
              ..where((p) => p.id.isIn(productSales.keys.toList())))
            .get();
    final productsById = {for (final p in products) p.id: p};

    final categorySalesMap = <int, double>{};
    for (final entry in productSales.entries) {
      final categoryId = productsById[entry.key]?.categoryId;
      if (categoryId == null) continue;
      categorySalesMap[categoryId] =
          (categorySalesMap[categoryId] ?? 0) + entry.value;
    }

    final categories = categorySalesMap.keys.isEmpty
        ? <Category>[]
        : await (db.select(db.categories)
              ..where((c) => c.id.isIn(categorySalesMap.keys.toList())))
            .get();
    final categoriesById = {for (final c in categories) c.id: c};

    final topProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categorySales = categorySalesMap.entries
        .map(
          (entry) => ReportBreakdownItem(
            name: categoriesById[entry.key]?.nameAr ?? withoutCategoryLabel,
            total: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return ReportsLoadResult(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      totalExpenses: totalExpenses,
      totalProfit: totalProfit,
      dailySales: dailySales,
      topProducts: topProducts
          .take(10)
          .map(
            (entry) => ReportBreakdownItem(
              name: productsById[entry.key]?.nameAr ?? unknownLabel,
              total: entry.value,
            ),
          )
          .toList(),
      categorySales: categorySales,
      currencyMap: currencyMap,
      reportCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      reportExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
    );
  }
}
