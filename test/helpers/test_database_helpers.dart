import 'package:drift/drift.dart' show Value;
import 'package:mada_pos/core/database/database.dart';

/// Inserts a product with stock in the default warehouse (id 1 after seed).
Future<int> insertProductWithStock(
  AppDatabase db, {
  required String nameAr,
  double sellingPrice = 10000,
  double stockQty = 100,
  int warehouseId = 1,
}) async {
  final productId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          nameAr: nameAr,
          sellingPrice: Value(sellingPrice),
        ),
      );
  await db.into(db.stock).insert(
        StockCompanion.insert(
          productId: productId,
          warehouseId: warehouseId,
          quantity: Value(stockQty),
        ),
      );
  return productId;
}
