import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/application/pos_smart_service.dart';

Product _product(int id, String name) {
  return Product(
    id: id,
    nameAr: name,
    purchasePrice: 1,
    sellingPrice: 1,
    minStockLevel: 0,
    isActive: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  const service = PosSmartService();

  test('suggestionsForCart recommends co-purchased products', () {
    final pairs = {
      1: [2, 3],
      2: [1],
    };
    final products = [_product(1, 'A'), _product(2, 'B'), _product(3, 'C')];

    final suggestions = service.suggestionsForCart(
      pairsByProduct: pairs,
      cartProductIds: [1],
      allProducts: products,
    );

    expect(suggestions.map((p) => p.id), contains(2));
    expect(suggestions.map((p) => p.id), isNot(contains(1)));
  });
}
