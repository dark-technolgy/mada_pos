import 'package:drift/drift.dart' show OrderingTerm;

import '../database/database.dart';
import '../smart/smart_search.dart';

enum GlobalSearchResultType { product, customer, invoice }

class GlobalSearchResult {
  const GlobalSearchResult({
    required this.type,
    required this.title,
    this.subtitle,
    required this.route,
    this.invoiceId,
  });

  final GlobalSearchResultType type;
  final String title;
  final String? subtitle;
  final String route;
  final int? invoiceId;
}

class GlobalSearchService {
  const GlobalSearchService();

  Future<List<GlobalSearchResult>> search(
    AppDatabase db, {
    required String query,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final normalized = normalizeSearchText(trimmed);
    final results = <GlobalSearchResult>[];

    final products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
    final rankedProducts = rankProductsBySearch(products: products, query: trimmed)
        .take(limit ~/ 2 + 2);
    for (final product in rankedProducts) {
      results.add(
        GlobalSearchResult(
          type: GlobalSearchResultType.product,
          title: product.nameAr,
          subtitle: product.barcode ?? product.sku,
          route: '/products/edit/${product.id}',
        ),
      );
    }

    final customers = await (db.select(db.customers)
          ..where((c) => c.isActive.equals(true)))
        .get();
    for (final customer in customers) {
      if (!_matchesCustomer(customer, normalized, trimmed)) continue;
      results.add(
        GlobalSearchResult(
          type: GlobalSearchResultType.customer,
          title: customer.name,
          subtitle: customer.phone,
          route: '/customers/edit/${customer.id}',
        ),
      );
      if (results.length >= limit) break;
    }

    if (results.length < limit) {
      final invoices = await (db.select(db.invoices)
            ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
            ..limit(200))
          .get();
      final lower = trimmed.toLowerCase();
      for (final invoice in invoices) {
        if (!invoice.invoiceNumber.toLowerCase().contains(lower)) continue;
        results.add(
          GlobalSearchResult(
            type: GlobalSearchResultType.invoice,
            title: invoice.invoiceNumber,
            subtitle: invoice.type,
            route: '/invoices',
            invoiceId: invoice.id,
          ),
        );
        if (results.length >= limit) break;
      }
    }

    return results.take(limit).toList();
  }

  bool _matchesCustomer(Customer customer, String normalized, String raw) {
    final name = normalizeSearchText(customer.name);
    final phone = customer.phone?.trim() ?? '';
    if (name.contains(normalized)) return true;
    if (phone.isNotEmpty && phone.contains(raw)) return true;
    return false;
  }
}
