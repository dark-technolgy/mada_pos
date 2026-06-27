import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class PurchaseReturnLine {
  const PurchaseReturnLine({
    required this.invoiceItemId,
    required this.quantity,
  });

  final int invoiceItemId;
  final double quantity;
}

class RecordPurchaseReturnResult {
  const RecordPurchaseReturnResult({
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

class PurchaseReturnService {
  const PurchaseReturnService();

  Future<Map<int, double>> alreadyReturnedBySourceLine(
    AppDatabase db, {
    required int originalInvoiceId,
  }) async {
    final returns = await (db.select(db.invoices)
          ..where((i) => i.returnedFromId.equals(originalInvoiceId))
          ..where((i) => i.type.equals('purchase_return')))
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
    throw const PurchaseReturnException('No warehouse available');
  }

  Future<void> _applyStockOut(
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

    if (existing == null || existing.quantity + 1e-9 < quantity) {
      throw const PurchaseReturnException('Insufficient stock for return');
    }

    await (db.update(db.stock)..where((s) => s.id.equals(existing.id))).write(
      StockCompanion(
        quantity: Value(existing.quantity - quantity),
        lastUpdated: Value(createdAt),
      ),
    );

    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            productId: productId,
            warehouseFromId: Value(warehouseId),
            quantity: quantity,
            type: 'out',
            referenceType: const Value('invoice'),
            referenceId: Value(returnInvoiceId),
            userId: Value(userId),
          ),
        );
  }

  Future<void> _reducePayableDebtsForInvoice(
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
              d.type == 'payable' &&
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

  Future<void> _adjustSupplierBalance(
    AppDatabase db, {
    required int supplierId,
    required double returnTotal,
  }) async {
    final supplier = await (db.select(db.suppliers)
          ..where((s) => s.id.equals(supplierId)))
        .getSingleOrNull();
    if (supplier == null) return;
    final newBal = (supplier.balance - returnTotal).clamp(0.0, double.infinity);
    await (db.update(db.suppliers)..where((s) => s.id.equals(supplierId))).write(
      SuppliersCompanion(
        balance: Value(newBal.toDouble()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<RecordPurchaseReturnResult> recordPurchaseReturn(
    AppDatabase db, {
    required User user,
    required Invoice original,
    required List<PurchaseReturnLine> lines,
  }) async {
    if (original.type != 'purchase') {
      throw const PurchaseReturnException('Only purchase invoices can be returned');
    }
    if (original.status == 'draft' || original.status == 'cancelled') {
      throw const PurchaseReturnException('Invalid purchase status for return');
    }

    final rawLines = lines.where((l) => l.quantity > 0).toList();
    if (rawLines.isEmpty) {
      throw const PurchaseReturnException('No return quantities');
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
        throw const PurchaseReturnException('Invalid line item');
      }
      final priorReturned = returnedBefore[line.invoiceItemId] ?? 0;
      final remaining = item.quantity - priorReturned;
      if (remaining < 0) {
        throw const PurchaseReturnException('Invalid return history for this purchase');
      }
      if (line.quantity > remaining) {
        throw PurchaseReturnException(
          'Return qty cannot exceed remaining qty ($remaining) for this line',
        );
      }
      final unitTotal = item.quantity > 0 ? item.total / item.quantity : 0.0;
      final lineTotal = unitTotal * line.quantity;
      subtotal += lineTotal;
      createdItems.add((item: item, returnQty: line.quantity, lineTotal: lineTotal));
    }

    final invoiceNumber = await db.getNextInvoiceNumber('purchase_return');
    final createdAt = DateTime.now();
    final total = subtotal;

    return await db.transaction(() async {
      final returnId = await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: invoiceNumber,
              type: 'purchase_return',
              supplierId: Value(original.supplierId),
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

        await _applyStockOut(
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
              supplierId: Value(original.supplierId),
              amount: total,
              currencyCode: Value(original.currencyCode),
              paymentMethod: Value(original.paymentMethod),
              userId: Value(user.id),
              notes: const Value('purchase_return'),
            ),
          );

      if (original.supplierId != null) {
        await _adjustSupplierBalance(
          db,
          supplierId: original.supplierId!,
          returnTotal: total,
        );
        await _reducePayableDebtsForInvoice(
          db,
          invoiceId: original.id,
          amount: total,
          currencyCode: original.currencyCode,
        );
      }

      return RecordPurchaseReturnResult(
        invoiceId: returnId,
        invoiceNumber: invoiceNumber,
        createdAt: createdAt,
        total: total,
      );
    });
  }
}

class PurchaseReturnException implements Exception {
  const PurchaseReturnException(this.message);
  final String message;

  @override
  String toString() => message;
}
