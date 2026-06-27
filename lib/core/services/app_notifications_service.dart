import 'package:drift/drift.dart' hide Column;

import '../database/database.dart';
import '../smart/smart_insights_service.dart';

enum AppNotificationKind {
  lowStock,
  overdueDebt,
  staleHeldInvoice,
  salesTrend,
}

enum AppNotificationSeverity { info, warning, alert }

class AppNotification {
  const AppNotification({
    required this.kind,
    required this.severity,
    this.subtitle,
    this.actionRoute,
  });

  final AppNotificationKind kind;
  final AppNotificationSeverity severity;
  final String? subtitle;
  final String? actionRoute;
}

class AppNotificationsService {
  const AppNotificationsService();

  Future<List<AppNotification>> load(
    AppDatabase db, {
    DateTime? now,
    int? branchId,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final notifications = <AppNotification>[];

    final stockRows = await db.select(db.stock).get();
    final products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();
    for (final product in products) {
      if (product.minStockLevel <= 0) continue;
      final qty = stockRows
          .where((s) => s.productId == product.id)
          .fold<double>(0, (sum, s) => sum + s.quantity);
      if (qty <= product.minStockLevel) {
        notifications.add(
          AppNotification(
            kind: AppNotificationKind.lowStock,
            severity: AppNotificationSeverity.warning,
            subtitle: product.nameAr,
            actionRoute: '/inventory',
          ),
        );
        if (notifications.length >= 8) break;
      }
    }

    final overdueDebtsQuery = db.select(db.debts)
      ..where((d) => d.status.isIn(['active', 'partial']))
      ..where((d) => d.dueDate.isSmallerThanValue(effectiveNow));
    if (branchId != null) {
      overdueDebtsQuery.where((d) => d.branchId.equals(branchId));
    }
    final overdueDebts = await overdueDebtsQuery.get();
    if (overdueDebts.isNotEmpty) {
      notifications.add(
        AppNotification(
          kind: AppNotificationKind.overdueDebt,
          severity: AppNotificationSeverity.alert,
          subtitle: '${overdueDebts.length}',
          actionRoute: '/debts',
        ),
      );
    }

    final staleHeldQuery = db.select(db.invoices)
      ..where((i) => i.isHeld.equals(true))
      ..where((i) => i.status.equals('draft'))
      ..where(
        (i) => i.createdAt.isSmallerThanValue(
          effectiveNow.subtract(const Duration(hours: 24)),
        ),
      );
    if (branchId != null) {
      staleHeldQuery.where((i) => i.branchId.equals(branchId));
    }
    final staleHeld = await staleHeldQuery.get();
    if (staleHeld.isNotEmpty) {
      notifications.add(
        AppNotification(
          kind: AppNotificationKind.staleHeldInvoice,
          severity: AppNotificationSeverity.info,
          subtitle: '${staleHeld.length}',
          actionRoute: '/pos',
        ),
      );
    }

    final insights = await const SmartInsightsService().load(db, now: effectiveNow);
    for (final insight in insights.insights) {
      if (insight.kind == SmartInsightKind.salesTrendDown) {
        notifications.add(
          AppNotification(
            kind: AppNotificationKind.salesTrend,
            severity: AppNotificationSeverity.info,
            actionRoute: '/reports',
          ),
        );
        break;
      }
    }

    return notifications;
  }
}
