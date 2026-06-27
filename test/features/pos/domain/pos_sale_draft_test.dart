import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/domain/pos_sale_draft.dart';

Future<Product> _insertProduct(AppDatabase database, String name) async {
  final id = await database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          nameAr: name,
          sellingPrice: const Value(14800),
        ),
      );

  return (database.select(
    database.products,
  )..where((product) => product.id.equals(id))).getSingle();
}

void main() {
  group('PosSaleDraft', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('adds same product by increasing quantity', () async {
      final product = await _insertProduct(database, 'Draft Product');
      var draft = const PosSaleDraft();

      draft = draft.addProduct(product);
      draft = draft.addProduct(product);

      expect(draft.cart, hasLength(1));
      expect(draft.cart.single.quantity, 2);
    });

    test(
      'updates currency for cart prices and fixed invoice discount',
      () async {
        final product = await _insertProduct(database, 'Currency Product');
        var draft = const PosSaleDraft(
          invoiceDiscount: 1480,
          discountType: 'fixed',
          currencyCode: 'IQD',
          exchangeRate: 1,
        ).addProduct(product);

        draft = draft.updateCurrency(currencyCode: 'USD', exchangeRate: 1480);

        expect(draft.currencyCode, 'USD');
        expect(draft.cart.single.unitPrice, closeTo(10, 0.001));
        expect(draft.invoiceDiscount, closeTo(1, 0.001));
      },
    );

    test(
      'resetAfterHold clears sale state but keeps selected currency',
      () async {
        final product = await _insertProduct(database, 'Reset Product');
        final customerId = await database
            .into(database.customers)
            .insert(CustomersCompanion.insert(name: 'Draft Customer'));
        final customer = await (database.select(
          database.customers,
        )..where((item) => item.id.equals(customerId))).getSingle();

        final draft = PosSaleDraft(
          selectedCustomer: customer,
          invoiceDiscount: 50,
          discountType: 'percentage',
          paymentMethod: 'card',
          currencyCode: 'USD',
          exchangeRate: 1480,
        ).addProduct(product);

        final cleared = draft.resetAfterHold();

        expect(cleared.cart, isEmpty);
        expect(cleared.selectedCustomer, isNull);
        expect(cleared.invoiceDiscount, 0);
        expect(cleared.discountType, 'fixed');
        expect(cleared.paymentMethod, 'cash');
        expect(cleared.currencyCode, 'USD');
      },
    );
  });
}
