import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class InvoiceVoidException implements Exception {
  const InvoiceVoidException(this.message);
  final String message;

  @override
  String toString() => message;
}

class InvoiceVoidService {
  const InvoiceVoidService();

  Future<void> voidInvoice(
    AppDatabase db, {
    required Invoice invoice,
    required User user,
  }) async {
    if (invoice.status == 'cancelled') {
      throw const InvoiceVoidException('already-cancelled');
    }
    if (invoice.status == 'draft' || invoice.isHeld) {
      throw const InvoiceVoidException('draft-or-held');
    }
    if (invoice.type == 'sale_return' || invoice.type == 'purchase_return') {
      throw const InvoiceVoidException('return-invoice');
    }

    final hasReturns = await (db.select(db.invoices)
          ..where((i) => i.returnedFromId.equals(invoice.id)))
        .get();
    if (hasReturns.isNotEmpty) {
      throw const InvoiceVoidException('has-returns');
    }

    final items = await (db.select(db.invoiceItems)
          ..where((i) => i.invoiceId.equals(invoice.id)))
        .get();

    final warehouseId = await _resolveWarehouseId(db, invoice);

    await db.transaction(() async {
      for (final item in items) {
        if (invoice.type == 'sale') {
          await _adjustStock(
            db,
            productId: item.productId,
            warehouseId: item.warehouseId ?? warehouseId,
            delta: item.quantity,
            invoiceId: invoice.id,
            userId: user.id,
            movementType: 'in',
          );
        } else if (invoice.type == 'purchase') {
          await _adjustStock(
            db,
            productId: item.productId,
            warehouseId: item.warehouseId ?? warehouseId,
            delta: -item.quantity,
            invoiceId: invoice.id,
            userId: user.id,
            movementType: 'out',
          );
        }
      }

      await (db.update(db.invoices)..where((i) => i.id.equals(invoice.id)))
          .write(
        InvoicesCompanion(
          status: const Value('cancelled'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<int> _resolveWarehouseId(AppDatabase db, Invoice invoice) async {
    if (invoice.warehouseId != null) return invoice.warehouseId!;
    final rows = await (db.select(db.warehouses)
          ..where((w) => w.isDefault.equals(true))
          ..limit(1))
        .get();
    if (rows.isNotEmpty) return rows.first.id;
    final any = await (db.select(db.warehouses)..limit(1)).get();
    if (any.isEmpty) {
      throw const InvoiceVoidException('no-warehouse');
    }
    return any.first.id;
  }

  Future<void> _adjustStock(
    AppDatabase db, {
    required int productId,
    required int warehouseId,
    required double delta,
    required int invoiceId,
    required int userId,
    required String movementType,
  }) async {
    if (delta == 0) return;

    final existing = await (db.select(db.stock)
          ..where((s) => s.productId.equals(productId))
          ..where((s) => s.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    final now = DateTime.now();
    if (existing != null) {
      final nextQty = existing.quantity + delta;
      if (nextQty < 0) {
        throw const InvoiceVoidException('insufficient-stock');
      }
      await (db.update(db.stock)..where((s) => s.id.equals(existing.id))).write(
        StockCompanion(quantity: Value(nextQty), lastUpdated: Value(now)),
      );
    } else if (delta > 0) {
      await db.into(db.stock).insert(
            StockCompanion.insert(
              productId: productId,
              warehouseId: warehouseId,
              quantity: Value(delta),
              lastUpdated: Value(now),
            ),
          );
    } else {
      throw const InvoiceVoidException('insufficient-stock');
    }

    await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: productId,
            quantity: delta.abs(),
            type: movementType,
            referenceType: const Value('invoice_void'),
            referenceId: Value(invoiceId),
            userId: Value(userId),
            warehouseToId: movementType == 'in' ? Value(warehouseId) : const Value.absent(),
            warehouseFromId:
                movementType == 'out' ? Value(warehouseId) : const Value.absent(),
          ),
        );
  }
}
