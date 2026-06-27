import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/smart/smart_search.dart';

Product _product({
  required int id,
  required String nameAr,
  String? barcode,
}) {
  return Product(
    id: id,
    nameAr: nameAr,
    barcode: barcode,
    purchasePrice: 1,
    sellingPrice: 1,
    minStockLevel: 0,
    isActive: true,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  group('smart_search', () {
    test('normalizeSearchText unifies Arabic alef', () {
      expect(normalizeSearchText('أرز'), normalizeSearchText('ارز'));
    });

    test('rankProductsBySearch prioritizes barcode match', () {
      final products = [
        _product(id: 1, nameAr: 'حليب'),
        _product(id: 2, nameAr: 'أرز', barcode: '12345'),
      ];

      final ranked = rankProductsBySearch(products: products, query: '12345');
      expect(ranked.first.id, 2);
    });

    test('rankProductsBySearch matches tokenized Arabic name', () {
      final products = [
        _product(id: 1, nameAr: 'زيت زيتون بكر'),
        _product(id: 2, nameAr: 'سكر'),
      ];

      final ranked = rankProductsBySearch(products: products, query: 'زيتون');
      expect(ranked.length, 1);
      expect(ranked.first.id, 1);
    });
  });
}
