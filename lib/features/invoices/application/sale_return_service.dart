import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class SaleReturnLine {
  const SaleReturnLine({
    required this.invoiceItemId,
    required this.quantity,
  });

  final int invoiceItemId;
  final double quantity;
}

class RecordSaleReturnResult {
  const RecordSaleReturnResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.total,
  });

  final int invoiceId;
  final String invoiceNumber;
  final DateTime createdAt;
  final double total;
}

class SaleReturnService {
  const SaleReturnService();

  /// Prior returns linked to [originalInvoiceId], summed by original sale line id.
  Future<Map<int, double>> alreadyReturnedBySourceLine(
    AppDatabase db, {
    required int originalInvoiceId,
  }) async {
    final returns = await (db.select(db.invoices)
          ..where((i) => i.returnedFromId.equals(originalInvoiceId))
          ..where((i) => i.type.equals('sale_return')))
        .get();
    if (returns.isEmpty) return {};
    final returnIds = returns.map((r) => r.id).toList();
    final rows = await (db.select(db.invoiceItems)
          ..where((it) => it.invoiceId.isIn(returnIds)))
        .get();

    final map = <int, double>{};
    for (final it in rows) {
      final sid = it.sourceInvoiceItemId;
      if (sid == null) continue;
      map[sid] = (map[sid] ?? 0) + it.quantity;
    }
    return map;
  }

  /// Remaining quantity that can still be returned per original [InvoiceItem.id].
  Future<Map<int, double>> remainingReturnableQuantities(
    AppDatabase db, {
    required int originalInvoiceId,
    required List<InvoiceItem> originalItems,
  }) async {
    final returned = await alreadyReturnedBySourceLine(
      db,
      originalInvoiceId: originalInvoiceId,
    );
    return {
      for (final oi in originalItems)
        oi.id: ((oi.quantity - (returned[oi.id] ?? 0)).clamp(0.0, double.infinity))
            .toDouble(),
    };
  }

  Future<int> _resolveWarehouseId(AppDatabase db, Invoice original) async {
    if (original.warehouseId != null) return original.warehouseId!;
    final rows = await (db.select(db.warehouses)
          ..where((w) => w.isDefault.equals(true))
          ..limit(1))
        .get();
    if (rows.isNotEmpty) return rows.first.id;
    final any = await (db.select(db.warehouses)..limit(1)).get();
    if (any.isNotEmpty) return any.first.id;
    throw const SaleReturnException('No warehouse available');
  }

  Future<void> _applyStockIn(
    AppDatabase db, {
    required int productId,
    required int warehouseId,
    required double quantity,
    required int returnInvoiceId,
    required int userId,
    required DateTime createdAt,
  }) async {
    final existing = await (db.select(db.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.stock)..where((s) => s.id.equals(existing.id))).write(
        StockCompanion(
          quantity: Value(existing.quantity + quantity),
          lastUpdated: Value(createdAt),
        ),
      );
    } else {
      await db
          .into(db.stock)
          .insert(
            StockCompanion.insert(
              productId: productId,
              warehouseId: warehouseId,
              quantity: Value(quantity),
              lastUpdated: Value(createdAt),
            ),
          );
    }

    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            productId: productId,
            warehouseToId: Value(warehouseId),
            quantity: quantity,
            type: 'in',
            referenceType: const Value('invoice'),
            referenceId: Value(returnInvoiceId),
            userId: Value(userId),
          ),
        );
  }

  Future<void> _reduceReceivableDebtsForInvoice(
    AppDatabase db, {
    required int invoiceId,
    required double amount,
    required String currencyCode,
  }) async {
    if (amount <= 1e-9) return;
    var left = amount;
    final debts = await (db.select(db.debts)
          ..where((d) => d.invoiceId.equals(invoiceId)))
        .get();
    final targets = debts
        .where(
          (d) =>
              d.type == 'receivable' &&
              d.currencyCode == currencyCode &&
              d.remainingAmount > 1e-9,
        )
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final now = DateTime.now();
    for (final d in targets) {
      if (left <= 1e-9) break;
      final take = d.remainingAmount < left ? d.remainingAmount : left;
      final newRem = d.remainingAmount - take;
      final status = newRem <= 1e-9 ? 'paid' : 'partial';
      await (db.update(db.debts)..where((x) => x.id.equals(d.id))).write(
        DebtsCompanion(
          remainingAmount: Value(newRem),
          status: Value(status),
          updatedAt: Value(now),
        ),
      );
      left -= take;
    }
  }

  Future<void> _adjustCustomerBalance(
    AppDatabase db, {
    required int customerId,
    required double returnTotal,
  }) async {
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    if (customer == null) return;
    final newBal = customer.balance - returnTotal;
    await (db.update(db.customers)..where((c) => c.id.equals(customerId))).write(
      CustomersCompanion(
        balance: Value(newBal),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<RecordSaleReturnResult> recordSaleReturn(
    AppDatabase db, {
    required User user,
    required Invoice original,
    required List<SaleReturnLine> lines,
  }) async {
    if (original.type != 'sale') {
      throw const SaleReturnException('Only sale invoices can be returned');
    }
    if (original.isHeld || original.status == 'draft') {
      throw const SaleReturnException('Draft or held sales cannot be returned');
    }
    if (original.status == 'cancelled') {
      throw const SaleReturnException('Cancelled invoice cannot be returned');
    }

    final rawLines = lines.where((l) => l.quantity > 0).toList();
    if (rawLines.isEmpty) {
      throw const SaleReturnException('No return quantities');
    }

    final originalItems = await (db.select(db.invoiceItems)
          ..where((i) => i.invoiceId.equals(original.id)))
        .get();

    final returnedBefore = await alreadyReturnedBySourceLine(
      db,
      originalInvoiceId: original.id,
    );

    double subtotal = 0;
    final warehouseId = await _resolveWarehouseId(db, original);
    final createdItems = <({
      InvoiceItem item,
      double returnQty,
      double lineTotal,
    })>[];

    for (final line in rawLines) {
      InvoiceItem? item;
      for (final i in originalItems) {
        if (i.id == line.invoiceItemId) {
          item = i;
          break;
        }
      }
      if (item == null) {
        throw const SaleReturnException('Invalid line item');
      }
      final priorReturned = returnedBefore[line.invoiceItemId] ?? 0;
      final remaining = item.quantity - priorReturned;
      if (remaining < 0) {
        throw const SaleReturnException('Invalid return history for this sale');
      }
      if (line.quantity > remaining) {
        throw SaleReturnException(
          'Return qty cannot exceed remaining qty ($remaining) for this line',
        );
      }
      final unitTotal = item.quantity > 0 ? item.total / item.quantity : 0.0;
      final lineTotal = unitTotal * line.quantity;
      subtotal += lineTotal;
      createdItems.add((item: item, returnQty: line.quantity, lineTotal: lineTotal));
    }

    final invoiceNumber = await db.getNextInvoiceNumber('sale_return');
    final createdAt = DateTime.now();
    final total = subtotal;

    return await db.transaction(() async {
      final returnId = await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: invoiceNumber,
              type: 'sale_return',
              customerId: Value(original.customerId),
              userId: user.id,
              warehouseId: Value(warehouseId),
              returnedFromId: Value(original.id),
              subtotal: Value(subtotal),
              discountAmount: const Value(0),
              discountType: const Value('fixed'),
              total: Value(total),
              paidAmount: Value(total),
              remaining: const Value(0),
              currencyCode: Value(original.currencyCode),
              exchangeRate: Value(original.exchangeRate),
              paymentMethod: Value(original.paymentMethod),
              status: const Value('paid'),
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );

      for (final row in createdItems) {
        final item = row.item;
        await db
            .into(db.invoiceItems)
            .insert(
              InvoiceItemsCompanion.insert(
                invoiceId: returnId,
                productId: item.productId,
                quantity: row.returnQty,
                unitPrice: item.unitPrice,
                discount: Value(
                  item.quantity > 0
                      ? (item.discount * row.returnQty / item.quantity)
                      : 0.0,
                ),
                total: row.lineTotal,
                warehouseId: Value(item.warehouseId ?? warehouseId),
                sourceInvoiceItemId: Value(item.id),
              ),
            );

        await _applyStockIn(
          db,
          productId: item.productId,
          warehouseId: item.warehouseId ?? warehouseId,
          quantity: row.returnQty,
          returnInvoiceId: returnId,
          userId: user.id,
          createdAt: createdAt,
        );
      }

      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              invoiceId: Value(returnId),
              customerId: Value(original.customerId),
              amount: total,
              currencyCode: Value(original.currencyCode),
              paymentMethod: Value(original.paymentMethod),
              userId: Value(user.id),
              notes: const Value('sale_return'),
            ),
          );

      if (original.customerId != null) {
        await _adjustCustomerBalance(
          db,
          customerId: original.customerId!,
          returnTotal: total,
        );
        await _reduceReceivableDebtsForInvoice(
          db,
          invoiceId: original.id,
          amount: total,
          currencyCode: original.currencyCode,
        );
      }

      return RecordSaleReturnResult(
        invoiceId: returnId,
        invoiceNumber: invoiceNumber,
        createdAt: createdAt,
        total: total,
      );
    });
  }
}

class SaleReturnException implements Exception {
  const SaleReturnException(this.message);
  final String message;

  @override
  String toString() => message;
}
