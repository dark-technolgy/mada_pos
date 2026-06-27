import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_payment_split.dart';
import '../domain/pos_pricing.dart';

class RecallHeldSaleResult {
  const RecallHeldSaleResult({
    required this.invoice,
    required this.customer,
    required this.cart,
  });

  final Invoice invoice;
  final Customer? customer;
  final List<PosCartItem> cart;
}

class CompleteSaleResult {
  const CompleteSaleResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.summary,
  });

  final int invoiceId;
  final String invoiceNumber;
  final DateTime createdAt;
  final PosPricingSummary summary;
}

class PosSaleService {
  PosSaleService(this._db);

  final AppDatabase _db;

  Future<int> _defaultWarehouseId() async {
    final rows = await (_db.select(_db.warehouses)
          ..where((w) => w.isDefault.equals(true))
          ..limit(1))
        .get();
    if (rows.isNotEmpty) return rows.first.id;
    final any = await (_db.select(_db.warehouses)..limit(1)).get();
    if (any.isEmpty) {
      throw StateError('No warehouse configured');
    }
    return any.first.id;
  }

  Future<String> holdSale({
    required User user,
    required List<PosCartItem> cart,
    required Customer? customer,
    required PosPricingSummary summary,
    required double invoiceDiscount,
    required String discountType,
    required String paymentMethod,
    required String currencyCode,
    required double exchangeRate,
  }) async {
    final invoiceNumber = await _db.getNextInvoiceNumber('sale');
    final heldInvoiceId = await _db
        .into(_db.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: invoiceNumber,
            type: 'sale',
            customerId: Value(customer?.id),
            userId: user.id,
            subtotal: Value(summary.subtotal),
            discountAmount: Value(summary.invoiceDiscountAmount),
            discountType: Value(discountType),
            taxAmount: Value(summary.taxAmount),
            total: Value(summary.total),
            paidAmount: const Value(0),
            remaining: Value(summary.total),
            currencyCode: Value(currencyCode),
            exchangeRate: Value(exchangeRate),
            paymentMethod: Value(paymentMethod),
            status: const Value('draft'),
            isHeld: const Value(true),
          ),
        );

    for (final item in cart) {
      await _db
          .into(_db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: heldInvoiceId,
              productId: item.product.id,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discount: Value(item.discount),
              total: item.total,
            ),
          );
    }

    return invoiceNumber;
  }

  Future<List<Invoice>> listHeldInvoicesForUser(int userId) {
    return (_db.select(_db.invoices)
          ..where((invoice) => invoice.userId.equals(userId))
          ..where((invoice) => invoice.isHeld.equals(true))
          ..where((invoice) => invoice.status.equals('draft'))
          ..orderBy([(invoice) => OrderingTerm.desc(invoice.createdAt)]))
        .get();
  }

  Future<RecallHeldSaleResult> recallHeldSale(int invoiceId) async {
    final invoice = await (_db.select(
      _db.invoices,
    )..where((item) => item.id.equals(invoiceId))).getSingle();

    final heldItems = await (_db.select(
      _db.invoiceItems,
    )..where((item) => item.invoiceId.equals(invoiceId))).get();

    final productIds = heldItems.map((item) => item.productId).toSet().toList();
    final products = productIds.isEmpty
        ? <Product>[]
        : await (_db.select(
            _db.products,
          )..where((product) => product.id.isIn(productIds))).get();
    final productsById = {for (final product in products) product.id: product};

    Customer? customer;
    if (invoice.customerId != null) {
      customer =
          await (_db.select(_db.customers)
                ..where((item) => item.id.equals(invoice.customerId!)))
              .getSingleOrNull();
    }

    final cart = heldItems
        .map((item) {
          final product = productsById[item.productId];
          if (product == null) return null;

          return PosCartItem(
            product: product,
            quantity: item.quantity,
            baseUnitPrice: CurrencyConversion.toBase(
              item.unitPrice,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            ),
            unitPrice: item.unitPrice,
            discount: item.discount,
          );
        })
        .whereType<PosCartItem>()
        .toList(growable: false);

    await (_db.delete(
      _db.invoiceItems,
    )..where((item) => item.invoiceId.equals(invoiceId))).go();
    await (_db.delete(
      _db.invoices,
    )..where((item) => item.id.equals(invoiceId))).go();

    return RecallHeldSaleResult(
      invoice: invoice,
      customer: customer,
      cart: cart,
    );
  }

  Future<CompleteSaleResult> completeSale({
    required User user,
    required List<PosCartItem> cart,
    required Customer? customer,
    required PosPricingSummary summary,
    required String discountType,
    required List<PosPaymentSplit> paymentSplits,
    required String currencyCode,
    required double exchangeRate,
    int? branchId,
  }) async {
    if (paymentSplits.isEmpty) {
      throw ArgumentError('At least one payment split is required');
    }
    final splitSum = paymentSplits.fold<double>(0, (s, p) => s + p.amount);
    if ((splitSum - summary.total).abs() > 0.01) {
      throw StateError('Payment splits must equal invoice total');
    }

    final invoiceNumber = await _db.getNextInvoiceNumber('sale');
    final createdAt = DateTime.now();
    final paymentMethod =
        paymentSplits.length == 1 ? paymentSplits.first.method : 'split';

    final invoiceId = await _db
        .into(_db.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: invoiceNumber,
            type: 'sale',
            customerId: Value(customer?.id),
            userId: user.id,
            branchId: Value(branchId),
            subtotal: Value(summary.subtotal),
            discountAmount: Value(summary.invoiceDiscountAmount),
            discountType: Value(discountType),
            taxAmount: Value(summary.taxAmount),
            total: Value(summary.total),
            paidAmount: Value(summary.total),
            remaining: const Value(0),
            currencyCode: Value(currencyCode),
            exchangeRate: Value(exchangeRate),
            paymentMethod: Value(paymentMethod),
            status: const Value('paid'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );

    for (final item in cart) {
      await _db
          .into(_db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: invoiceId,
              productId: item.product.id,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discount: Value(item.discount),
              total: item.total,
            ),
          );

      final warehouseId = await _defaultWarehouseId();
      final existingStock = await (_db.select(_db.stock)
            ..where((stock) => stock.productId.equals(item.product.id))
            ..where((stock) => stock.warehouseId.equals(warehouseId)))
          .getSingleOrNull();

      if (existingStock != null) {
        final nextQty = existingStock.quantity - item.quantity;
        if (nextQty < 0) {
          throw StateError(
            'Insufficient stock for ${item.product.nameAr}',
          );
        }
        await (_db.update(_db.stock)
              ..where((stock) => stock.id.equals(existingStock.id)))
            .write(
          StockCompanion(
            quantity: Value(nextQty),
            lastUpdated: Value(createdAt),
          ),
        );
      } else {
        throw StateError('No stock for ${item.product.nameAr}');
      }

      await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: item.product.id,
              warehouseFromId: Value(warehouseId),
              quantity: item.quantity,
              type: 'out',
              referenceType: const Value('invoice'),
              referenceId: Value(invoiceId),
              userId: Value(user.id),
            ),
          );
    }

    for (final split in paymentSplits) {
      await _db.into(_db.payments).insert(
            PaymentsCompanion.insert(
              invoiceId: Value(invoiceId),
              customerId: Value(customer?.id),
              amount: split.amount,
              currencyCode: Value(currencyCode),
              paymentMethod: Value(split.method),
              userId: Value(user.id),
            ),
          );
    }

    return CompleteSaleResult(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      createdAt: createdAt,
      summary: summary,
    );
  }
}
