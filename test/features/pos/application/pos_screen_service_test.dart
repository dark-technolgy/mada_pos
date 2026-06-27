import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/application/pos_screen_service.dart';

void main() {
  const service = PosScreenService();

  test(
    'loadScreenData returns sorted active products and default currency',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final categoryId = await database
          .into(database.categories)
          .insert(CategoriesCompanion.insert(nameAr: 'Category A'));
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'ب',
              categoryId: Value(categoryId),
              sellingPrice: const Value(10.0),
            ),
          );
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'ا',
              categoryId: Value(categoryId),
              sellingPrice: const Value(20.0),
            ),
          );

      final result = await service.loadScreenData(database);

      expect(result.products.map((product) => product.nameAr).toList(), [
        'ا',
        'ب',
      ]);
      expect(result.categories, isNotEmpty);
      expect(result.currencies, isNotEmpty);
      expect(result.defaultCurrencyCode, isNotEmpty);
    },
  );

  test('filterProducts matches search and category filters', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final foodCategoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'Food'));
    final drinkCategoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'Drink'));
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Apple Juice',
            categoryId: Value(drinkCategoryId),
            barcode: const Value('123'),
            sellingPrice: const Value(5.0),
          ),
        );
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Bread',
            categoryId: Value(foodCategoryId),
            sku: const Value('FOOD-1'),
            sellingPrice: const Value(2.0),
          ),
        );

    final products = await service
        .loadScreenData(database)
        .then((result) => result.products);

    expect(
      service.filterProducts(
        products: products,
        query: 'Apple',
        selectedCategoryId: null,
      ),
      hasLength(1),
    );
    expect(
      service.filterProducts(
        products: products,
        query: '123',
        selectedCategoryId: null,
      ),
      hasLength(1),
    );
    expect(
      service.filterProducts(
        products: products,
        query: '',
        selectedCategoryId: foodCategoryId,
      ),
      hasLength(1),
    );
  });

  test('findProductByBarcode and discountAmountFor work as expected', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Barcode Product',
            barcode: const Value('ABC123'),
            sellingPrice: const Value(10.0),
          ),
        );

    final products = await service
        .loadScreenData(database)
        .then((result) => result.products);
    final matchedProduct = service.findProductByBarcode(products, 'ABC123');

    expect(matchedProduct?.nameAr, 'Barcode Product');
    expect(
      service.findProductByBarcode(products, '000ABC123')?.nameAr,
      'Barcode Product',
    );
    expect(
      service.discountAmountFor(
        grossTotal: 200,
        rawValue: 10,
        discountType: 'percentage',
      ),
      20,
    );
    expect(
      service.discountAmountFor(
        grossTotal: 200,
        rawValue: 15,
        discountType: 'fixed',
      ),
      15,
    );
  });

  test('loadActiveCustomers returns only active customers', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Active Customer'));
    await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Inactive Customer',
            isActive: const Value(false),
          ),
        );

    final customers = await service.loadActiveCustomers(database);

    expect(customers.map((customer) => customer.name), ['Active Customer']);
  });
}
