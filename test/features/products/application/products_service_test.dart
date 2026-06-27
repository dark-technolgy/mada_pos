import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/products/application/products_service.dart';

void main() {
  const service = ProductsService();

  test(
    'ProductsService loads products and categories with lookup map',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final categoryId = await database
          .into(database.categories)
          .insert(CategoriesCompanion.insert(nameAr: 'Electronics'));
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Phone',
              categoryId: Value(categoryId),
              barcode: const Value('12345'),
              sku: const Value('SKU-01'),
              purchasePrice: const Value(100),
              sellingPrice: const Value(150),
            ),
          );

      final result = await service.loadScreenData(database);

      expect(result.products, hasLength(1));
      expect(result.categories, hasLength(1));
      expect(result.categoryNamesById[categoryId], 'Electronics');
    },
  );

  test('ProductsService filters by search category and active state', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final categoryIdA = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'A'));
    final categoryIdB = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'B'));

    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'هاتف',
            nameEn: const Value('Phone'),
            barcode: const Value('ABC123'),
            sku: const Value('SKU-1'),
            categoryId: Value(categoryIdA),
            purchasePrice: const Value(100),
            sellingPrice: const Value(150),
            isActive: const Value(true),
          ),
        );
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'حاسبة',
            nameEn: const Value('Calculator'),
            barcode: const Value('XYZ999'),
            sku: const Value('SKU-2'),
            categoryId: Value(categoryIdB),
            purchasePrice: const Value(20),
            sellingPrice: const Value(35),
            isActive: const Value(false),
          ),
        );

    final products = await database.select(database.products).get();

    final bySearch = service.filterProducts(
      products: products,
      searchQuery: 'phone',
      categoryId: null,
      showInactive: false,
    );
    final byCategory = service.filterProducts(
      products: products,
      searchQuery: '',
      categoryId: categoryIdA,
      showInactive: true,
    );
    final withInactive = service.filterProducts(
      products: products,
      searchQuery: 'sku-2',
      categoryId: null,
      showInactive: true,
    );

    expect(bySearch.map((product) => product.id), [1]);
    expect(byCategory.map((product) => product.id), [1]);
    expect(withInactive.map((product) => product.id), [2]);
  });

  test('ProductsService deletes product rows', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Delete Me',
            purchasePrice: const Value(50),
            sellingPrice: const Value(70),
          ),
        );

    await service.deleteProduct(database, productId);

    final products = await database.select(database.products).get();
    expect(products, isEmpty);
  });
}
