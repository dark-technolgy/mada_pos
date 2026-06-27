import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/database/database.dart';
import '../../../core/smart/smart_search.dart';
import '../../../core/utils/currency_conversion.dart';

class PosScreenLoadResult {
  const PosScreenLoadResult({
    required this.products,
    required this.categories,
    required this.currencies,
    required this.defaultCurrencyCode,
    required this.defaultExchangeRate,
  });

  final List<Product> products;
  final List<Category> categories;
  final List<Currency> currencies;
  final String defaultCurrencyCode;
  final double defaultExchangeRate;
}

class PosScreenService {
  const PosScreenService();

  Future<PosScreenLoadResult> loadScreenData(AppDatabase db) async {
    final products =
        await (db.select(db.products)
              ..where((product) => product.isActive.equals(true))
              ..orderBy([(product) => OrderingTerm.asc(product.nameAr)]))
            .get();
    final categories = await (db.select(
      db.categories,
    )..where((category) => category.isActive.equals(true))).get();
    final currencies =
        await (db.select(db.currencies)..orderBy([
              (currency) => OrderingTerm.desc(currency.isDefault),
              (currency) => OrderingTerm.asc(currency.code),
            ]))
            .get();
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    return PosScreenLoadResult(
      products: products,
      categories: categories,
      currencies: currencies,
      defaultCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      defaultExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
    );
  }

  List<Product> filterProducts({
    required List<Product> products,
    required String query,
    required int? selectedCategoryId,
  }) {
    return rankProductsBySearch(
      products: products,
      query: query,
      categoryId: selectedCategoryId,
    );
  }

  Product? findProductByBarcode(List<Product> products, String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    final normalized = _normalizeBarcode(trimmed);

    for (final product in products) {
      final productBarcode = product.barcode?.trim();
      if (productBarcode != null && productBarcode.isNotEmpty) {
        if (_normalizeBarcode(productBarcode) == normalized) {
          return product;
        }
      }

      final sku = product.sku?.trim();
      if (sku != null && sku.isNotEmpty) {
        if (_normalizeBarcode(sku) == normalized) {
          return product;
        }
      }
    }
    return null;
  }

  String _normalizeBarcode(String value) {
    final trimmed = value.trim();
    final withoutLeadingZeros = trimmed.replaceFirst(RegExp(r'^0+'), '');
    return (withoutLeadingZeros.isEmpty ? trimmed : withoutLeadingZeros)
        .toLowerCase();
  }

  double discountAmountFor({
    required double grossTotal,
    required double rawValue,
    required String discountType,
  }) {
    if (discountType == 'percentage') {
      return grossTotal * (rawValue.clamp(0, 100) / 100);
    }
    return rawValue;
  }

  Future<List<Customer>> loadActiveCustomers(AppDatabase db) {
    return (db.select(
      db.customers,
    )..where((customer) => customer.isActive.equals(true))).get();
  }
}
