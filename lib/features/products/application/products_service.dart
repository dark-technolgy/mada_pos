import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/database/database.dart';

class ProductsLoadResult {
  const ProductsLoadResult({
    required this.products,
    required this.categories,
    required this.categoryNamesById,
  });

  final List<Product> products;
  final List<Category> categories;
  final Map<int, String> categoryNamesById;
}

class ProductsService {
  const ProductsService();

  Future<ProductsLoadResult> loadScreenData(AppDatabase db) async {
    final products = await (db.select(
      db.products,
    )..orderBy([(product) => OrderingTerm.asc(product.nameAr)])).get();
    final categories = await db.select(db.categories).get();

    return ProductsLoadResult(
      products: products,
      categories: categories,
      categoryNamesById: {
        for (final category in categories) category.id: category.nameAr,
      },
    );
  }

  List<Product> filterProducts({
    required List<Product> products,
    required String searchQuery,
    required int? categoryId,
    required bool showInactive,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return products
        .where((product) {
          if (!showInactive && !product.isActive) {
            return false;
          }
          if (categoryId != null && product.categoryId != categoryId) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return product.nameAr.toLowerCase().contains(normalizedQuery) ||
              (product.nameEn?.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              (product.barcode?.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              (product.sku?.toLowerCase().contains(normalizedQuery) ?? false);
        })
        .toList(growable: false);
  }

  String categoryNameFor(int? categoryId, Map<int, String> categoryNamesById) {
    if (categoryId == null) {
      return '-';
    }

    return categoryNamesById[categoryId] ?? '-';
  }

  Future<void> deleteProduct(AppDatabase db, int productId) {
    return (db.delete(
      db.products,
    )..where((product) => product.id.equals(productId))).go();
  }
}
