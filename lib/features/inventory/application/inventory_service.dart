import 'package:drift/drift.dart';
import '../../../core/database/database.dart';

class InventoryStockItem {
  const InventoryStockItem({
    required this.product,
    required this.quantity,
    required this.status,
    this.suggestedReorderQty,
  });

  final Product product;
  final double quantity;
  final String status;
  /// Units to order to reach 2× minimum stock (null when not applicable).
  final double? suggestedReorderQty;
}

/// Suggested reorder when at or below minimum stock level.
double? computeSuggestedReorderQty(Product product, double quantity) {
  final min = product.minStockLevel;
  if (min <= 0) return null;
  if (quantity > min) return null;
  final target = min * 2;
  final needed = target - quantity;
  if (needed <= 0) return null;
  return needed;
}

class InventoryLoadResult {
  const InventoryLoadResult({required this.items});

  final List<InventoryStockItem> items;

  int get lowCount => items.where((item) => item.status == 'low').length;
  int get outCount => items.where((item) => item.status == 'out').length;
}

class InventoryService {
  const InventoryService();

  Future<InventoryLoadResult> loadStock(AppDatabase db) async {
    // Optimized: Use a query that calculates totals at the DB level
    final query = db.select(db.products).join([
      leftOuterJoin(
        db.stock,
        db.stock.productId.equalsExp(db.products.id),
      ),
    ]);

    query.where(db.products.isActive.equals(true));

    final rows = await query.get();
    final itemsMap = <int, InventoryStockItem>{};

    for (final row in rows) {
      final product = row.readTable(db.products);
      final stockEntry = row.readTableOrNull(db.stock);
      final qty = stockEntry?.quantity ?? 0.0;

      if (itemsMap.containsKey(product.id)) {
        final existing = itemsMap[product.id]!;
        final newQty = existing.quantity + qty;
        itemsMap[product.id] = InventoryStockItem(
          product: product,
          quantity: newQty,
          status: _computeStatus(product, newQty),
          suggestedReorderQty: computeSuggestedReorderQty(product, newQty),
        );
      } else {
        itemsMap[product.id] = InventoryStockItem(
          product: product,
          quantity: qty,
          status: _computeStatus(product, qty),
          suggestedReorderQty: computeSuggestedReorderQty(product, qty),
        );
      }
    }

    return InventoryLoadResult(items: itemsMap.values.toList());
  }

  String _computeStatus(Product product, double quantity) {
    if (quantity <= 0) return 'out';
    if (quantity <= product.minStockLevel) return 'low';
    return 'ok';
  }

  List<InventoryStockItem> filterItems({
    required List<InventoryStockItem> items,
    required String query,
    required String filter,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return items
        .where((item) {
          if (filter == 'low' && item.status != 'low') return false;
          if (filter == 'out' && item.status != 'out') return false;
          if (normalizedQuery.isEmpty) return true;

          return item.product.nameAr.toLowerCase().contains(normalizedQuery) ||
              (item.product.barcode?.toLowerCase().contains(normalizedQuery) ??
                  false);
        })
        .toList(growable: false);
  }
}
