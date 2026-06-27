import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class ProductFormLoadResult {
  const ProductFormLoadResult({
    required this.categories,
    required this.units,
    this.product,
  });

  final List<Category> categories;
  final List<Unit> units;
  final Product? product;
}

class ProductFormPayload {
  const ProductFormPayload({
    required this.nameAr,
    this.nameEn,
    this.nameKu,
    this.barcode,
    this.sku,
    this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.minStockLevel,
    this.initialStock = 0,
    this.categoryId,
    this.unitId,
    required this.isActive,
  });

  final String nameAr;
  final String? nameEn;
  final String? nameKu;
  final String? barcode;
  final String? sku;
  final String? description;
  final double purchasePrice;
  final double sellingPrice;
  final double minStockLevel;
  final double initialStock;
  final int? categoryId;
  final int? unitId;
  final bool isActive;
}

class ProductFormService {
  const ProductFormService();

  Future<ProductFormLoadResult> loadFormData(
    AppDatabase db, {
    int? productId,
  }) async {
    final categories = await (db.select(
      db.categories,
    )..where((category) => category.isActive.equals(true))).get();
    final units = await db.select(db.units).get();
    final product = productId == null
        ? null
        : await (db.select(
            db.products,
          )..where((entry) => entry.id.equals(productId))).getSingleOrNull();

    return ProductFormLoadResult(
      categories: categories,
      units: units,
      product: product,
    );
  }

  Future<void> saveProduct(
    AppDatabase db, {
    required ProductFormPayload payload,
    int? productId,
  }) async {
    if (productId != null) {
      await (db.update(
        db.products,
      )..where((product) => product.id.equals(productId))).write(
        ProductsCompanion(
          nameAr: Value(payload.nameAr),
          nameEn: Value(payload.nameEn),
          nameKu: Value(payload.nameKu),
          barcode: Value(payload.barcode),
          sku: Value(payload.sku),
          description: Value(payload.description),
          categoryId: Value(payload.categoryId),
          unitId: Value(payload.unitId),
          purchasePrice: Value(payload.purchasePrice),
          sellingPrice: Value(payload.sellingPrice),
          minStockLevel: Value(payload.minStockLevel),
          isActive: Value(payload.isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    final insertedProductId = await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: payload.nameAr,
            nameEn: Value(payload.nameEn),
            nameKu: Value(payload.nameKu),
            barcode: Value(payload.barcode),
            sku: Value(payload.sku),
            description: Value(payload.description),
            categoryId: Value(payload.categoryId),
            unitId: Value(payload.unitId),
            purchasePrice: Value(payload.purchasePrice),
            sellingPrice: Value(payload.sellingPrice),
            minStockLevel: Value(payload.minStockLevel),
            isActive: Value(payload.isActive),
          ),
        );

    if (payload.initialStock <= 0) {
      return;
    }

    final warehouse = await (db.select(
      db.warehouses,
    )..limit(1)).getSingleOrNull();
    if (warehouse == null) {
      return;
    }

    await db
        .into(db.stock)
        .insert(
          StockCompanion.insert(
            productId: insertedProductId,
            warehouseId: warehouse.id,
            quantity: Value(payload.initialStock),
          ),
        );
  }
}
