import 'package:drift/drift.dart' hide Column;

import '../database/database.dart';
import '../utils/currency_conversion.dart';

enum SmartInsightSeverity { info, success, warning, alert }

enum SmartInsightKind {
  salesTrendUp,
  salesTrendDown,
  slowDay,
  lowStock,
  overdueDebts,
  topProductToday,
  businessHealthy,
  staleHeldInvoices,
}

class SmartInsight {
  const SmartInsight({
    required this.kind,
    required this.severity,
    this.params = const {},
    this.actionRoute,
  });

  final SmartInsightKind kind;
  final SmartInsightSeverity severity;
  final Map<String, Object?> params;
  final String? actionRoute;
}

class SmartTopProduct {
  const SmartTopProduct({
    required this.productId,
    required this.name,
    required this.quantitySold,
    required this.revenueBase,
  });

  final int productId;
  final String name;
  final double quantitySold;
  final double revenueBase;
}

class SmartInsightsResult {
  const SmartInsightsResult({
    required this.insights,
    required this.topProductsToday,
    required this.salesChangePercent,
  });

  final List<SmartInsight> insights;
  final List<SmartTopProduct> topProductsToday;
  final double? salesChangePercent;
}

class SmartInsightsService {
  const SmartInsightsService();

  Future<SmartInsightsResult> load(
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
    final startOfYesterday = startOfDay.subtract(const Duration(days: 1));
    final last7Days = startOfDay.subtract(const Duration(days: 7));

    final currencies = await db.select(db.currencies).get();
    final currencyMap = {for (final c in currencies) c.code: c};

    final todaySales = await _salesInRange(
      db,
      startOfDay,
      effectiveNow,
      branchId: branchId,
    );
    final yesterdaySales = await _salesInRange(
      db,
      startOfYesterday,
      startOfYesterday.add(
        Duration(
          hours: effectiveNow.hour,
          minutes: effectiveNow.minute,
          seconds: effectiveNow.second,
        ),
      ),
      branchId: branchId,
    );
    final weekSales = await _salesInRange(
      db,
      last7Days,
      startOfDay,
      branchId: branchId,
    );

    final todayAmount = _sumInvoicesBase(todaySales, currencyMap);
    final yesterdayAmount = _sumInvoicesBase(yesterdaySales, currencyMap);
    final weekAvg =
        weekSales.isEmpty ? 0.0 : _sumInvoicesBase(weekSales, currencyMap) / 7;

    double? changePercent;
    if (yesterdayAmount > 0) {
      changePercent = ((todayAmount - yesterdayAmount) / yesterdayAmount) * 100;
    }

    final insights = <SmartInsight>[];

    if (changePercent != null) {
      if (changePercent >= 15) {
        insights.add(
          SmartInsight(
            kind: SmartInsightKind.salesTrendUp,
            severity: SmartInsightSeverity.success,
            params: {'percent': changePercent.round()},
          ),
        );
      } else if (changePercent <= -15) {
        insights.add(
          SmartInsight(
            kind: SmartInsightKind.salesTrendDown,
            severity: SmartInsightSeverity.warning,
            params: {'percent': changePercent.abs().round()},
          ),
        );
      }
    }

    if (weekAvg > 0 && todayAmount < weekAvg * 0.5 && effectiveNow.hour >= 12) {
      insights.add(
        const SmartInsight(
          kind: SmartInsightKind.slowDay,
          severity: SmartInsightSeverity.info,
        ),
      );
    }

    final lowStockCount = await _countLowStockProducts(db);
    if (lowStockCount > 0) {
      insights.add(
        SmartInsight(
          kind: SmartInsightKind.lowStock,
          severity: SmartInsightSeverity.alert,
          params: {'count': lowStockCount},
          actionRoute: '/inventory',
        ),
      );
    }

    final overdueDebtsQuery = db.select(db.debts)
      ..where((d) => d.status.isIn(['active', 'partial']))
      ..where((d) => d.dueDate.isNotNull())
      ..where((d) => d.dueDate.isSmallerThanValue(startOfDay));
    if (branchId != null) {
      overdueDebtsQuery.where((d) => d.branchId.equals(branchId));
    }
    final overdueDebts = await overdueDebtsQuery.get();
    if (overdueDebts.isNotEmpty) {
      insights.add(
        SmartInsight(
          kind: SmartInsightKind.overdueDebts,
          severity: SmartInsightSeverity.warning,
          params: {'count': overdueDebts.length},
          actionRoute: '/debts',
        ),
      );
    }

    final topProducts = await _topProductsToday(
      db,
      startOfDay,
      effectiveNow,
      branchId: branchId,
    );

    if (topProducts.isNotEmpty) {
      insights.add(
        SmartInsight(
          kind: SmartInsightKind.topProductToday,
          severity: SmartInsightSeverity.info,
          params: {'name': topProducts.first.name},
          actionRoute: '/pos',
        ),
      );
    }

    final staleHeldCutoff = effectiveNow.subtract(const Duration(hours: 24));
    final staleHeldQuery = db.select(db.invoices)
      ..where((i) => i.isHeld.equals(true))
      ..where((i) => i.createdAt.isSmallerThanValue(staleHeldCutoff));
    if (branchId != null) {
      staleHeldQuery.where((i) => i.branchId.equals(branchId));
    }
    final staleHeldCount = await staleHeldQuery.get();
    if (staleHeldCount.isNotEmpty) {
      insights.add(
        SmartInsight(
          kind: SmartInsightKind.staleHeldInvoices,
          severity: SmartInsightSeverity.warning,
          params: {'count': staleHeldCount.length},
          actionRoute: '/pos',
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const SmartInsight(
          kind: SmartInsightKind.businessHealthy,
          severity: SmartInsightSeverity.success,
        ),
      );
    }

    return SmartInsightsResult(
      insights: insights,
      topProductsToday: topProducts,
      salesChangePercent: changePercent,
    );
  }

  Future<List<Invoice>> _salesInRange(
    AppDatabase db,
    DateTime from,
    DateTime to, {
    int? branchId,
  }) {
    final query = db.select(db.invoices)
      ..where((i) => i.type.equals('sale'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(from))
      ..where((i) => i.createdAt.isSmallerThanValue(to));
    if (branchId != null) {
      query.where((i) => i.branchId.equals(branchId));
    }
    return query.get();
  }

  double _sumInvoicesBase(
    List<Invoice> invoices,
    Map<String, Currency> currencyMap,
  ) {
    return invoices.fold(
      0.0,
      (sum, invoice) =>
          sum +
          CurrencyConversion.toBase(
            invoice.total,
            currencyCode: invoice.currencyCode,
            exchangeRate: invoice.exchangeRate,
          ),
    );
  }

  Future<int> _countLowStockProducts(AppDatabase db) async {
    final products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
    final stockRows = await db.select(db.stock).get();
    var count = 0;
    for (final product in products) {
      if (product.minStockLevel <= 0) continue;
      final qty = stockRows
          .where((s) => s.productId == product.id)
          .fold<double>(0, (a, b) => a + b.quantity);
      if (qty <= product.minStockLevel) count++;
    }
    return count;
  }

  Future<List<SmartTopProduct>> _topProductsToday(
    AppDatabase db,
    DateTime from,
    DateTime to, {
    int? branchId,
  }) async {
    final sales = await _salesInRange(db, from, to, branchId: branchId);
    if (sales.isEmpty) return const [];

    final invoiceIds = sales.map((i) => i.id).toList();
    final items = await (db.select(db.invoiceItems)
          ..where((item) => item.invoiceId.isIn(invoiceIds)))
        .get();

    final products = await db.select(db.products).get();
    final productById = {for (final p in products) p.id: p};

    final qtyByProduct = <int, double>{};
    final revenueByProduct = <int, double>{};

    for (final item in items) {
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
      revenueByProduct[item.productId] =
          (revenueByProduct[item.productId] ?? 0) + item.total;
    }

    final ranked = qtyByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(5).map((entry) {
      final product = productById[entry.key];
      return SmartTopProduct(
        productId: entry.key,
        name: product?.nameAr ?? '#${entry.key}',
        quantitySold: entry.value,
        revenueBase: revenueByProduct[entry.key] ?? 0,
      );
    }).toList();
  }
}
