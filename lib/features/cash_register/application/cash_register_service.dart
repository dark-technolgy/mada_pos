import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class CashRegisterService {
  const CashRegisterService();

  Future<CashRegisterData?> activeShiftForUser(
    AppDatabase db,
    int userId,
  ) {
    return (db.select(db.cashRegister)
          ..where((c) => c.userId.equals(userId))
          ..where((c) => c.closedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Opens a shift with zero balance when none is active (no UI prompt).
  Future<void> ensureActiveShift(AppDatabase db, {required int userId}) async {
    final existing = await activeShiftForUser(db, userId);
    if (existing != null) return;
    await openShift(db, userId: userId, openingAmount: 0);
  }

  Future<void> openShift(
    AppDatabase db, {
    required int userId,
    required double openingAmount,
    String? notes,
  }) async {
    final existing = await activeShiftForUser(db, userId);
    if (existing != null) {
      throw const CashRegisterException('cash_register_already_open');
    }
    await db.into(db.cashRegister).insert(
          CashRegisterCompanion.insert(
            userId: userId,
            openingAmount: Value(openingAmount),
            notes: Value(notes),
          ),
        );
  }

  Future<void> closeShift(
    AppDatabase db, {
    required int shiftId,
    required double expectedClosing,
    required double actualAmount,
    String? notes,
  }) async {
    final row = await (db.select(db.cashRegister)
          ..where((c) => c.id.equals(shiftId)))
        .getSingleOrNull();
    if (row == null) {
      throw const CashRegisterException('shift_not_found');
    }
    if (row.closedAt != null) {
      throw const CashRegisterException('shift_already_closed');
    }
    final difference = actualAmount - expectedClosing;
    final noteParts = [
      if (row.notes != null && row.notes!.trim().isNotEmpty) row.notes!.trim(),
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    ];
    final combinedNotes =
        noteParts.isEmpty ? null : noteParts.join('\n');
    await (db.update(db.cashRegister)..where((c) => c.id.equals(shiftId))).write(
          CashRegisterCompanion(
            closingAmount: Value(expectedClosing),
            actualAmount: Value(actualAmount),
            difference: Value(difference),
            notes: Value(combinedNotes),
            closedAt: Value(DateTime.now()),
          ),
        );
  }
}

class CashRegisterException implements Exception {
  const CashRegisterException(this.code);
  final String code;

  @override
  String toString() => code;
}
