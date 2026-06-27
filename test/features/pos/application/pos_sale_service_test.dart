import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/pos/application/pos_sale_service.dart';
import 'package:mada_pos/features/pos/domain/pos_cart_item.dart';
import 'package:mada_pos/features/pos/domain/pos_payment_split.dart';
import 'package:mada_pos/features/pos/domain/pos_pricing.dart';

User _buildUser() {
  return User(
    id: 1,
    username: 'admin',
    passwordHash: 'hash',
    fullName: 'Admin User',
    role: 'admin',
    isActive: true,
    createdAt: DateTime(2026, 3, 9),
    updatedAt: DateTime(2026, 3, 9),
  );
}

Future<Product> _insertProduct(AppDatabase database, String name) async {
  final id = await database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          nameAr: name,
          sellingPrice: const Value(10000),
        ),
      );

  return (database.select(
    database.products,
  )..where((product) => product.id.equals(id))).getSingle();
}

void main() {
  group('PosSaleService', () {
    late AppDatabase database;
    late PosSaleService service;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      service = PosSaleService(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('holds and recalls a sale using typed cart items', () async {
      final product = await _insertProduct(database, 'Held Product');
      final customerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Held Customer'));
      final customer = await (database.select(
        database.customers,
      )..where((item) => item.id.equals(customerId))).getSingle();

      final cart = [
        PosCartItem(
          product: product,
          quantity: 2,
          baseUnitPrice: 10000,
          unitPrice: 10000,
          discount: 1500,
        ),
      ];
      final summary = PosPricing.summarize(
        lines: cart.map((item) => item.toLinePricing()),
        invoiceDiscount: 1000,
        discountType: 'fixed',
      );

      final invoiceNumber = await service.holdSale(
        user: _buildUser(),
        cart: cart,
        customer: customer,
        summary: summary,
        invoiceDiscount: 1000,
        discountType: 'fixed',
        paymentMethod: 'cash',
        currencyCode: 'IQD',
        exchangeRate: 1,
      );

      expect(invoiceNumber, 'INV-000001');

      final heldInvoices = await service.listHeldInvoicesForUser(1);
      expect(heldInvoices, hasLength(1));
      expect(heldInvoices.single.isHeld, isTrue);

      final recalled = await service.recallHeldSale(heldInvoices.single.id);

      expect(recalled.customer?.name, 'Held Customer');
      expect(recalled.cart, hasLength(1));
      expect(recalled.cart.single.product.nameAr, 'Held Product');
      expect(recalled.cart.single.quantity, 2);
      expect(recalled.cart.single.discount, 1500);

      final invoicesAfterRecall = await service.listHeldInvoicesForUser(1);
      expect(invoicesAfterRecall, isEmpty);
    });

    test('completes sale and records payment and stock movement', () async {
      final product = await _insertProduct(database, 'Sale Product');
      await database
          .into(database.stock)
          .insert(
            StockCompanion.insert(
              productId: product.id,
              warehouseId: 1,
              quantity: const Value(5),
            ),
          );

      final cart = [
        PosCartItem(
          product: product,
          quantity: 2,
          baseUnitPrice: 10000,
          unitPrice: 10000,
          discount: 0,
        ),
      ];
      final summary = PosPricing.summarize(
        lines: cart.map((item) => item.toLinePricing()),
        invoiceDiscount: 0,
        discountType: 'fixed',
      );

      final result = await service.completeSale(
        user: _buildUser(),
        cart: cart,
        customer: null,
        summary: summary,
        discountType: 'fixed',
        paymentSplits: const [
          PosPaymentSplit(method: 'cash', amount: 20000),
        ],
        currencyCode: 'IQD',
        exchangeRate: 1,
      );

      expect(result.invoiceNumber, 'INV-000001');

      final invoices = await database.select(database.invoices).get();
      final payments = await database.select(database.payments).get();
      final stockMovements = await database
          .select(database.stockMovements)
          .get();
      final stock = await database.select(database.stock).getSingle();

      expect(invoices, hasLength(1));
      expect(invoices.single.status, 'paid');
      expect(payments, hasLength(1));
      expect(payments.single.amount, 20000);
      expect(stockMovements, hasLength(1));
      expect(stockMovements.single.quantity, 2);
      expect(stock.quantity, 3);
    });
  });
}
