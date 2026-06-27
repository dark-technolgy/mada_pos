import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';

class DashboardStats {
  const DashboardStats({
    required this.todaySales,
    required this.todayCount,
    required this.todayProfit,
    required this.monthlySales,
    required this.monthlyCount,
    required this.totalProducts,
    required this.totalCustomers,
    required this.totalDebts,
    required this.overdueDebtsCount,
    required this.heldInvoicesCount,
    required this.grossMarginPercent,
    required this.collectionRatePercent,
    this.topCustomerName,
    this.topCustomerSalesBase = 0,
  });

  final double todaySales;
  final int todayCount;
  final double todayProfit;
  final double monthlySales;
  final int monthlyCount;
  final int totalProducts;
  final int totalCustomers;
  final double totalDebts;
  final int overdueDebtsCount;
  final int heldInvoicesCount;
  final double grossMarginPercent;
  final double collectionRatePercent;
  final String? topCustomerName;
  final double topCustomerSalesBase;
}

class DashboardRecentInvoice {
  const DashboardRecentInvoice({
    required this.number,
    required this.type,
    required this.total,
    required this.currencyCode,
    required this.status,
    required this.date,
  });

  final String number;
  final String type;
  final double total;
  final String currencyCode;
  final String status;
  final DateTime date;
}

class DashboardLowStockProduct {
  const DashboardLowStockProduct({
    required this.name,
    required this.stock,
    required this.minStock,
  });

  final String name;
  final double stock;
  final double minStock;
}

class DashboardLoadResult {
  const DashboardLoadResult({
    required this.stats,
    required this.recentInvoices,
    required this.lowStockProducts,
    required this.currencyMap,
    required this.displayCurrencyCode,
    required this.displayExchangeRate,
  });

  final DashboardStats stats;
  final List<DashboardRecentInvoice> recentInvoices;
  final List<DashboardLowStockProduct> lowStockProducts;
  final Map<String, Currency> currencyMap;
  final String displayCurrencyCode;
  final double displayExchangeRate;
}

class DashboardService {
  const DashboardService();

  Future<DashboardLoadResult> loadDashboardData(
    AppDatabase db, {
    DateTime? now,
    int? branchId,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final startOfDay = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final startOfMonth = DateTime(effectiveNow.year, effectiveNow.month, 1);

    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    final todaySalesQuery = db.select(db.invoices)
      ..where((invoice) => invoice.type.equals('sale'))
      ..where(
        (invoice) => invoice.createdAt.isBiggerOrEqualValue(startOfDay),
      )
      ..where(
        (invoice) => invoice.status.isNotIn(['cancelled', 'draft']),
      );
    if (branchId != null) {
      todaySalesQuery.where((invoice) => invoice.branchId.equals(branchId));
    }
    final todaySales = await todaySalesQuery.get();

    final monthlySalesQuery = db.select(db.invoices)
      ..where((invoice) => invoice.type.equals('sale'))
      ..where(
        (invoice) => invoice.createdAt.isBiggerOrEqualValue(startOfMonth),
      )
      ..where(
        (invoice) => invoice.status.isNotIn(['cancelled', 'draft']),
      );
    if (branchId != null) {
      monthlySalesQuery.where((invoice) => invoice.branchId.equals(branchId));
    }
    final monthlySales = await monthlySalesQuery.get();
    final activeProducts = await (db.select(
      db.products,
    )..where((product) => product.isActive.equals(true))).get();
    final customers = await db.select(db.customers).get();
    final activeDebtsQuery = db.select(db.debts)
      ..where((debt) => debt.status.isIn(['active', 'partial']));
    if (branchId != null) {
      activeDebtsQuery.where((debt) => debt.branchId.equals(branchId));
    }
    final activeDebts = await activeDebtsQuery.get();
    final overdueDebts = activeDebts
        .where(
          (debt) =>
              debt.dueDate != null && debt.dueDate!.isBefore(effectiveNow),
        )
        .length;
    final heldQuery = db.select(db.invoices)
      ..where((i) => i.isHeld.equals(true))
      ..where((i) => i.status.equals('draft'));
    if (branchId != null) {
      heldQuery.where((i) => i.branchId.equals(branchId));
    }
    final heldInvoices = await heldQuery.get();

    final recentQuery = db.select(db.invoices)
      ..where(
        (invoice) => invoice.status.isNotIn(['cancelled', 'draft']),
      )
      ..orderBy([(invoice) => OrderingTerm.desc(invoice.createdAt)])
      ..limit(10);
    if (branchId != null) {
      recentQuery.where((invoice) => invoice.branchId.equals(branchId));
    }
    final recentInvoices = await recentQuery.get();
    final stockRows = await db.select(db.stock).get();

    final todaySalesAmount = todaySales.fold<double>(
      0.0,
      (sum, invoice) =>
          sum +
          CurrencyConversion.toBase(
            invoice.total,
            currencyCode: invoice.currencyCode,
            exchangeRate: invoice.exchangeRate,
          ),
    );
    double todayCostBase = 0;
    if (todaySales.isNotEmpty) {
      final todayIds = todaySales.map((i) => i.id).toList();
      final todayItems = await (db.select(db.invoiceItems)
            ..where((item) => item.invoiceId.isIn(todayIds)))
          .get();
      final productIds = todayItems.map((i) => i.productId).toSet().toList();
      final costProducts = productIds.isEmpty
          ? <Product>[]
          : await (db.select(db.products)
                ..where((p) => p.id.isIn(productIds)))
              .get();
      final costById = {for (final p in costProducts) p.id: p.purchasePrice};
      for (final item in todayItems) {
        final invoice = todaySales.firstWhere((i) => i.id == item.invoiceId);
        final cost = (costById[item.productId] ?? 0) * item.quantity;
        todayCostBase += CurrencyConversion.toBase(
          cost,
          currencyCode: invoice.currencyCode,
          exchangeRate: invoice.exchangeRate,
        );
      }
    }
    final todayProfit = todaySalesAmount - todayCostBase;
    final grossMarginPercent = todaySalesAmount > 0
        ? (todayProfit / todaySalesAmount) * 100
        : 0.0;

    final receivableDebts =
        activeDebts.where((d) => d.type == 'receivable').toList();
    final totalReceivableOriginal = receivableDebts.fold<double>(
      0,
      (s, d) =>
          s +
          CurrencyConversion.toBase(
            d.originalAmount,
            currencyCode: d.currencyCode,
            currencies: currencyMap,
          ),
    );
    final totalReceivableRemaining = receivableDebts.fold<double>(
      0,
      (s, d) =>
          s +
          CurrencyConversion.toBase(
            d.remainingAmount,
            currencyCode: d.currencyCode,
            currencies: currencyMap,
          ),
    );
    final collectionRatePercent = totalReceivableOriginal > 0
        ? ((totalReceivableOriginal - totalReceivableRemaining) /
                totalReceivableOriginal) *
            100
        : 100.0;

    String? topCustomerName;
    double topCustomerSalesBase = 0;
    final customerTotals = <int, double>{};
    for (final invoice in todaySales) {
      final cid = invoice.customerId;
      if (cid == null) continue;
      customerTotals[cid] = (customerTotals[cid] ?? 0) +
          CurrencyConversion.toBase(
            invoice.total,
            currencyCode: invoice.currencyCode,
            exchangeRate: invoice.exchangeRate,
          );
    }
    if (customerTotals.isNotEmpty) {
      final topEntry = customerTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      topCustomerSalesBase = topEntry.value;
      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(topEntry.key)))
          .getSingleOrNull();
      topCustomerName = customer?.name;
    }
    final monthlySalesAmount = monthlySales.fold<double>(
      0.0,
      (sum, invoice) =>
          sum +
          CurrencyConversion.toBase(
            invoice.total,
            currencyCode: invoice.currencyCode,
            exchangeRate: invoice.exchangeRate,
          ),
    );
    final totalDebts = activeDebts.fold<double>(
      0.0,
      (sum, debt) =>
          sum +
          CurrencyConversion.toBase(
            debt.remainingAmount,
            currencyCode: debt.currencyCode,
            currencies: currencyMap,
          ),
    );

    final lowStockProducts = <DashboardLowStockProduct>[];
    for (final product in activeProducts) {
      final totalQuantity = stockRows
          .where((row) => row.productId == product.id)
          .fold<double>(0.0, (sum, row) => sum + row.quantity);

      if (totalQuantity <= product.minStockLevel && product.minStockLevel > 0) {
        lowStockProducts.add(
          DashboardLowStockProduct(
            name: product.nameAr,
            stock: totalQuantity,
            minStock: product.minStockLevel,
          ),
        );
      }
    }

    return DashboardLoadResult(
      stats: DashboardStats(
        todaySales: todaySalesAmount,
        todayCount: todaySales.length,
        todayProfit: todayProfit,
        monthlySales: monthlySalesAmount,
        monthlyCount: monthlySales.length,
        totalProducts: activeProducts.length,
        totalCustomers: customers.length,
        totalDebts: totalDebts,
        overdueDebtsCount: overdueDebts,
        heldInvoicesCount: heldInvoices.length,
        grossMarginPercent: grossMarginPercent,
        collectionRatePercent: collectionRatePercent,
        topCustomerName: topCustomerName,
        topCustomerSalesBase: topCustomerSalesBase,
      ),
      recentInvoices: recentInvoices
          .map(
            (invoice) => DashboardRecentInvoice(
              number: invoice.invoiceNumber,
              type: invoice.type,
              total: invoice.total,
              currencyCode: invoice.currencyCode,
              status: invoice.status,
              date: invoice.createdAt,
            ),
          )
          .toList(),
      lowStockProducts: lowStockProducts,
      currencyMap: currencyMap,
      displayCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      displayExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
    );
  }
}
