import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/smart/smart_insights_service.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardSmartInsightsSection extends StatelessWidget {
  const DashboardSmartInsightsSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.insights,
    required this.topProducts,
    required this.salesChangePercent,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<SmartInsight> insights;
  final List<SmartTopProduct> topProducts;
  final double? salesChangePercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.smartInsights,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            if (salesChangePercent != null) ...[
              const Spacer(),
              _TrendChip(
                percent: salesChangePercent!,
                isDark: isDark,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final insight in insights)
              _InsightCard(
                insight: insight,
                l10n: l10n,
                isDark: isDark,
                onTap: insight.actionRoute == null
                    ? null
                    : () => context.go(insight.actionRoute!),
              ),
          ],
        ),
        if (topProducts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.topSellingToday,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...topProducts.take(3).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '×${p.quantitySold == p.quantitySold.roundToDouble() ? p.quantitySold.toInt() : p.quantitySold.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.percent, required this.isDark});

  final double percent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (up ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: up ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 4),
          Text(
            '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: up ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.insight,
    required this.l10n,
    required this.isDark,
    this.onTap,
  });

  final SmartInsight insight;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _severityColors(insight.severity);
    final title = _titleFor(insight);
    final message = _messageFor(insight);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(insight.kind), size: 18, color: colors.fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(SmartInsight insight) {
    return switch (insight.kind) {
      SmartInsightKind.salesTrendUp => l10n.salesTrendUp,
      SmartInsightKind.salesTrendDown => l10n.salesTrendDown,
      SmartInsightKind.slowDay => l10n.slowDayInsight,
      SmartInsightKind.lowStock => l10n.lowStockAlert,
      SmartInsightKind.overdueDebts => l10n.overdueDebtsInsight,
      SmartInsightKind.topProductToday => l10n.topProductToday,
      SmartInsightKind.businessHealthy => l10n.businessHealthy,
      SmartInsightKind.staleHeldInvoices => l10n.staleHeldInvoicesInsight,
    };
  }

  String _messageFor(SmartInsight insight) {
    return switch (insight.kind) {
      SmartInsightKind.salesTrendUp => l10n.salesTrendUpMessage(
          insight.params['percent'] as int? ?? 0,
        ),
      SmartInsightKind.salesTrendDown => l10n.salesTrendDownMessage(
          insight.params['percent'] as int? ?? 0,
        ),
      SmartInsightKind.slowDay => l10n.slowDayInsightMessage,
      SmartInsightKind.lowStock => l10n.lowStockAlertMessage(
          insight.params['count'] as int? ?? 0,
        ),
      SmartInsightKind.overdueDebts => l10n.overdueDebtsInsightMessage(
          insight.params['count'] as int? ?? 0,
        ),
      SmartInsightKind.topProductToday => l10n.topProductTodayMessage(
          insight.params['name'] as String? ?? '',
        ),
      SmartInsightKind.businessHealthy => l10n.businessHealthyMessage,
      SmartInsightKind.staleHeldInvoices => l10n.staleHeldInvoicesInsightMessage(
          insight.params['count'] as int? ?? 0,
        ),
    };
  }

  IconData _iconFor(SmartInsightKind kind) {
    return switch (kind) {
      SmartInsightKind.salesTrendUp => Icons.trending_up_rounded,
      SmartInsightKind.salesTrendDown => Icons.trending_down_rounded,
      SmartInsightKind.slowDay => Icons.insights_rounded,
      SmartInsightKind.lowStock => Icons.inventory_2_outlined,
      SmartInsightKind.overdueDebts => Icons.account_balance_wallet_outlined,
      SmartInsightKind.topProductToday => Icons.star_rounded,
      SmartInsightKind.businessHealthy => Icons.check_circle_outline_rounded,
      SmartInsightKind.staleHeldInvoices => Icons.pause_circle_outline_rounded,
    };
  }

  ({Color fg, Color border}) _severityColors(SmartInsightSeverity severity) {
    return switch (severity) {
      SmartInsightSeverity.success => (
          fg: AppColors.success,
          border: AppColors.success.withValues(alpha: 0.35),
        ),
      SmartInsightSeverity.warning => (
          fg: AppColors.warning,
          border: AppColors.warning.withValues(alpha: 0.35),
        ),
      SmartInsightSeverity.alert => (
          fg: AppColors.error,
          border: AppColors.error.withValues(alpha: 0.35),
        ),
      SmartInsightSeverity.info => (
          fg: AppColors.primary,
          border: AppColors.primary.withValues(alpha: 0.35),
        ),
    };
  }
}
