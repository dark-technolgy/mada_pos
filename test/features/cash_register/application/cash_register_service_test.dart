import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/cash_register/application/cash_register_service.dart';

void main() {
  const service = CashRegisterService();

  test('ensureActiveShift opens zero shift when none exists', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final userId = await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            username: 'cashier',
            passwordHash: 'hash',
            fullName: 'Cashier',
            role: const Value('cashier'),
          ),
        );

    const service = CashRegisterService();
    await service.ensureActiveShift(database, userId: userId);

    final shift = await service.activeShiftForUser(database, userId);
    expect(shift, isNotNull);
    expect(shift!.openingAmount, 0);
    expect(shift.closedAt, isNull);

    await service.ensureActiveShift(database, userId: userId);
    final stillOne = await service.activeShiftForUser(database, userId);
    expect(stillOne!.id, shift.id);
  });

  test('CashRegisterService opens and closes a shift', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final admin =
        await (database.select(database.users)..limit(1)).getSingle();

    expect(await service.activeShiftForUser(database, admin.id), isNull);

    await service.openShift(
      database,
      userId: admin.id,
      openingAmount: 500,
    );

    final open = await service.activeShiftForUser(database, admin.id);
    expect(open, isNotNull);
    expect(open!.openingAmount, 500);

    await service.closeShift(
      database,
      shiftId: open.id,
      expectedClosing: 500,
      actualAmount: 495,
    );

    expect(await service.activeShiftForUser(database, admin.id), isNull);

    final closed = await (database.select(database.cashRegister)
          ..where((c) => c.id.equals(open.id)))
        .getSingle();
    expect(closed.closedAt, isNotNull);
    expect(closed.difference, -5.0);
  });
}
