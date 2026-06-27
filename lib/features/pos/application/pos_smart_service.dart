import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';

/// Smart POS analytics: co-purchase, top sellers, stock levels.
class PosSmartService {
  const PosSmartService();

  Future<Map<int, double>> loadStockTotals(AppDatabase db) async {
    final rows = await db.select(db.stock).get();
    final totals = <int, double>{};
    for (final row in rows) {
      totals[row.productId] = (totals[row.productId] ?? 0) + row.quantity;
    }
    return totals;
  }

  Future<List<int>> loadTopSellerProductIds(
    AppDatabase db, {
    int lookbackDays = 7,
    int limit = 8,
  }) async {
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final sales = await (db.select(db.invoices)
          ..where((i) => i.type.equals('sale'))
          ..where((i) => i.status.isNotIn(['cancelled', 'draft', 'held']))
          ..where((i) => i.createdAt.isBiggerOrEqualValue(since)))
        .get();

    if (sales.isEmpty) return const [];

    final invoiceIds = sales.map((i) => i.id).toList();
    final items = await (db.select(db.invoiceItems)
          ..where((item) => item.invoiceId.isIn(invoiceIds)))
        .get();

    final qtyByProduct = <int, double>{};
    for (final item in items) {
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
    }

    final ranked = qtyByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(limit).map((e) => e.key).toList();
  }

  List<Product> productsFromIds(List<int> ids, List<Product> allProducts) {
    final byId = {for (final p in allProducts) p.id: p};
    return [
      for (final id in ids)
        if (byId[id] != null && byId[id]!.isActive) byId[id]!,
    ];
  }

  Future<Map<int, List<int>>> loadFrequentlyBoughtTogether(
    AppDatabase db, {
    int lookbackDays = 90,
    int maxSuggestionsPerProduct = 4,
  }) async {
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final sales = await (db.select(db.invoices)
          ..where((i) => i.type.equals('sale'))
          ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
          ..where((i) => i.createdAt.isBiggerOrEqualValue(since)))
        .get();

    if (sales.length < 3) return {};

    final invoiceIds = sales.map((i) => i.id).toList();
    final items = await (db.select(db.invoiceItems)
          ..where((item) => item.invoiceId.isIn(invoiceIds)))
        .get();

    final productsByInvoice = <int, Set<int>>{};
    for (final item in items) {
      productsByInvoice
          .putIfAbsent(item.invoiceId, () => {})
          .add(item.productId);
    }

    final pairCounts = <String, int>{};
    for (final productIds in productsByInvoice.values) {
      if (productIds.length < 2) continue;
      final list = productIds.toList()..sort();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final key = '${list[i]}:${list[j]}';
          pairCounts[key] = (pairCounts[key] ?? 0) + 1;
        }
      }
    }

    final suggestions = <int, List<MapEntry<int, int>>>{};

    for (final entry in pairCounts.entries) {
      final parts = entry.key.split(':');
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      final count = entry.value;

      suggestions.putIfAbsent(a, () => []).add(MapEntry(b, count));
      suggestions.putIfAbsent(b, () => []).add(MapEntry(a, count));
    }

    final result = <int, List<int>>{};
    for (final productId in suggestions.keys) {
      final ranked = List<MapEntry<int, int>>.from(suggestions[productId]!)
        ..sort((x, y) => y.value.compareTo(x.value));
      result[productId] = ranked
          .take(maxSuggestionsPerProduct)
          .map((e) => e.key)
          .toList();
    }
    return result;
  }

  List<Product> suggestionsForCart({
    required Map<int, List<int>> pairsByProduct,
    required List<int> cartProductIds,
    required List<Product> allProducts,
    int limit = 4,
  }) {
    if (cartProductIds.isEmpty) return const [];

    final scores = <int, int>{};
    for (final productId in cartProductIds) {
      final related = pairsByProduct[productId] ?? const [];
      for (var i = 0; i < related.length; i++) {
        final relatedId = related[i];
        if (cartProductIds.contains(relatedId)) continue;
        scores[relatedId] = (scores[relatedId] ?? 0) + (related.length - i);
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final productById = {for (final p in allProducts) p.id: p};
    final result = <Product>[];
    for (final entry in ranked) {
      final product = productById[entry.key];
      if (product != null && product.isActive) {
        result.add(product);
      }
      if (result.length >= limit) break;
    }
    return result;
  }
}
