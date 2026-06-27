import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/smart/smart_insights_service.dart';

void main() {
  const service = SmartInsightsService();

  test('flags held invoices older than 24 hours', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            username: 'cashier',
            passwordHash: 'hash',
            fullName: 'Cashier',
          ),
        );

    final staleAt = DateTime.now().subtract(const Duration(hours: 30));
    await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'HOLD-001',
            type: 'sale',
            status: const Value('draft'),
            subtotal: const Value(100),
            total: const Value(100),
            userId: userId,
            isHeld: const Value(true),
            createdAt: Value(staleAt),
          ),
        );

    final result = await service.load(db);
    expect(
      result.insights.any((i) => i.kind == SmartInsightKind.staleHeldInvoices),
      isTrue,
    );
    final insight = result.insights.firstWhere(
      (i) => i.kind == SmartInsightKind.staleHeldInvoices,
    );
    expect(insight.params['count'], 1);
  });
}
