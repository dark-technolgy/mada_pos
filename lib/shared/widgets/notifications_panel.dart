import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_ext.dart';
import '../../core/services/app_notifications_service.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({super.key});

  String _titleForKind(BuildContext context, AppNotificationKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      AppNotificationKind.lowStock => l10n.notificationLowStock,
      AppNotificationKind.overdueDebt => l10n.notificationOverdueDebts,
      AppNotificationKind.staleHeldInvoice => l10n.notificationStaleHeld,
      AppNotificationKind.salesTrend => l10n.notificationSalesDown,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appNotificationsProvider);
    final l10n = context.l10n;

    return async.when(
      loading: () => const SizedBox(
        width: 280,
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Text(l10n.errorOccurred),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.noNotifications),
          );
        }
        return SizedBox(
          width: 320,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = items[index];
              final color = switch (n.severity) {
                AppNotificationSeverity.alert => AppColors.error,
                AppNotificationSeverity.warning => AppColors.warning,
                _ => AppColors.primary,
              };
              return ListTile(
                dense: true,
                leading: Icon(Icons.notifications_active_outlined, color: color),
                title: Text(
                  _titleForKind(context, n.kind),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: n.subtitle == null
                    ? null
                    : Text(n.subtitle!, style: const TextStyle(fontSize: 12)),
                onTap: n.actionRoute == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        context.go(n.actionRoute!);
                      },
              );
            },
          ),
        );
      },
    );
  }
}
