import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/products/application/product_form_service.dart';

void main() {
  const service = ProductFormService();

  test(
    'ProductFormService loads categories and units and creates stock entry',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final categoryId = await database
          .into(database.categories)
          .insert(CategoriesCompanion.insert(nameAr: 'Electronics'));

      final loaded = await service.loadFormData(database);
      expect(
        loaded.categories.any((category) => category.id == categoryId),
        isTrue,
      );
      expect(loaded.units, isNotEmpty);

      await service.saveProduct(
        database,
        payload: const ProductFormPayload(
          nameAr: 'Phone',
          nameEn: 'Phone',
          barcode: '123',
          sku: 'SKU-1',
          description: 'Smart phone',
          purchasePrice: 100,
          sellingPrice: 150,
          minStockLevel: 2,
          initialStock: 8,
          categoryId: null,
          unitId: null,
          isActive: true,
        ),
      );

      final products = await database.select(database.products).get();
      final stock = await database.select(database.stock).get();

      expect(products, hasLength(1));
      expect(products.first.nameAr, 'Phone');
      expect(stock, hasLength(1));
      expect(stock.first.quantity, 8);
    },
  );

  test('ProductFormService updates existing product', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Old Name',
            purchasePrice: const Value(10),
            sellingPrice: const Value(15),
            minStockLevel: const Value(1),
          ),
        );

    await service.saveProduct(
      database,
      productId: productId,
      payload: const ProductFormPayload(
        nameAr: 'New Name',
        nameKu: 'Naw',
        purchasePrice: 12,
        sellingPrice: 20,
        minStockLevel: 3,
        isActive: false,
      ),
    );

    final product = await (database.select(
      database.products,
    )..where((entry) => entry.id.equals(productId))).getSingle();

    expect(product.nameAr, 'New Name');
    expect(product.nameKu, 'Naw');
    expect(product.purchasePrice, 12);
    expect(product.sellingPrice, 20);
    expect(product.minStockLevel, 3);
    expect(product.isActive, isFalse);
  });
}
