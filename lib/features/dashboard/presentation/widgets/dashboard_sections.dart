import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../application/dashboard_service.dart';

class DashboardHeaderSection extends StatelessWidget {
  const DashboardHeaderSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.user,
    required this.onNewSale,
    required this.onAddCustomer,
    required this.onAddProduct,
    this.onCustomize,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final User? user;
  final VoidCallback onNewSale;
  final VoidCallback onAddCustomer;
  final VoidCallback onAddProduct;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.welcomeBack}، ${user?.fullName ?? ''} 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.overviewOfToday,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (onCustomize != null) ...[
              IconButton(
                tooltip: l10n.dashboardCustomize,
                onPressed: onCustomize,
                icon: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 4),
            ],
            _QuickActionButton(
              icon: Icons.add_shopping_cart_rounded,
              label: l10n.newSale,
              gradient: AppColors.primaryGradient,
              onTap: onNewSale,
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              icon: Icons.person_add_rounded,
              label: l10n.addCustomer,
              gradient: AppColors.accentGradient,
              onTap: onAddCustomer,
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              icon: Icons.add_box_rounded,
              label: l10n.addProduct,
              gradient: AppColors.successGradient,
              onTap: onAddProduct,
            ),
          ],
        ),
      ],
    );
  }
}

class DashboardStatsSection extends StatelessWidget {
  const DashboardStatsSection({
    super.key,
    required this.l10n,
    required this.stats,
    required this.formatDisplayBaseAmount,
    this.showProfit = true,
  });

  final AppLocalizations l10n;
  final DashboardStats stats;
  final String Function(double amount) formatDisplayBaseAmount;
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: l10n.todaySales,
            value: formatDisplayBaseAmount(stats.todaySales),
            icon: Icons.trending_up_rounded,
            gradient: AppColors.primaryGradient,
            subtitle: '${stats.todayCount} ${l10n.invoices}',
          ),
        ),
        if (showProfit) ...[
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: l10n.todayProfit,
              value: formatDisplayBaseAmount(stats.todayProfit),
              icon: Icons.account_balance_wallet_rounded,
              gradient: AppColors.accentGradient,
            ),
          ),
        ],
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: l10n.totalDebtsLabel,
            value: formatDisplayBaseAmount(stats.totalDebts),
            icon: Icons.receipt_long_rounded,
            gradient: AppColors.warningGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: l10n.monthlySalesLabel,
            value: formatDisplayBaseAmount(stats.monthlySales),
            icon: Icons.calendar_month_rounded,
            gradient: AppColors.successGradient,
            subtitle: '${stats.monthlyCount} ${l10n.invoices}',
          ),
        ),
      ],
    );
  }
}

class DashboardExecutiveKpisSection extends StatelessWidget {
  const DashboardExecutiveKpisSection({
    super.key,
    required this.l10n,
    required this.stats,
    required this.formatDisplayBaseAmount,
  });

  final AppLocalizations l10n;
  final DashboardStats stats;
  final String Function(double amount) formatDisplayBaseAmount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: l10n.grossMargin,
            value: '${stats.grossMarginPercent.toStringAsFixed(1)}%',
            icon: Icons.percent_rounded,
            gradient: AppColors.accentGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: l10n.collectionRate,
            value: '${stats.collectionRatePercent.toStringAsFixed(1)}%',
            icon: Icons.payments_outlined,
            gradient: AppColors.successGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: l10n.overdueDebtsCount,
            value: '${stats.overdueDebtsCount}',
            icon: Icons.warning_amber_rounded,
            gradient: AppColors.warningGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: l10n.heldInvoicesCount,
            value: '${stats.heldInvoicesCount}',
            icon: Icons.pause_circle_outline_rounded,
            gradient: AppColors.primaryGradient,
          ),
        ),
      ],
    );
  }
}

class DashboardTopCustomerBanner extends StatelessWidget {
  const DashboardTopCustomerBanner({
    super.key,
    required this.l10n,
    required this.customerName,
    required this.salesAmount,
    required this.formatDisplayBaseAmount,
  });

  final AppLocalizations l10n;
  final String customerName;
  final double salesAmount;
  final String Function(double amount) formatDisplayBaseAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.topCustomerToday,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  customerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatDisplayBaseAmount(salesAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardContentSection extends StatelessWidget {
  const DashboardContentSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.recentInvoices,
    required this.lowStockProducts,
    required this.stats,
    required this.onViewAllInvoices,
    this.showRecentTransactions = true,
    this.showLowStock = true,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<DashboardRecentInvoice> recentInvoices;
  final List<DashboardLowStockProduct> lowStockProducts;
  final DashboardStats stats;
  final VoidCallback onViewAllInvoices;
  final bool showRecentTransactions;
  final bool showLowStock;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showRecentTransactions) {
      children.add(
        Expanded(
          flex: showLowStock ? 3 : 1,
          child: _RecentTransactionsCard(
            l10n: l10n,
            isDark: isDark,
            recentInvoices: recentInvoices,
            onViewAllInvoices: onViewAllInvoices,
          ),
        ),
      );
    }

    if (showLowStock) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 16));
      children.add(
        Expanded(
          flex: showRecentTransactions ? 2 : 1,
          child: Column(
            children: [
              _LowStockAlertCard(
                l10n: l10n,
                isDark: isDark,
                lowStockProducts: lowStockProducts,
              ),
              const SizedBox(height: 16),
              _QuickStatsCard(l10n: l10n, isDark: isDark, stats: stats),
            ],
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.32),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.l10n,
    required this.isDark,
    required this.recentInvoices,
    required this.onViewAllInvoices,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<DashboardRecentInvoice> recentInvoices;
  final VoidCallback onViewAllInvoices;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.lightTextMuted)
                .withValues(alpha: isDark ? 0.22 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentTransactions,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              TextButton(
                onPressed: onViewAllInvoices,
                child: Text(l10n.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentInvoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  l10n.noTransactionsYet,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
            )
          else
            ...recentInvoices.map(
              (invoice) =>
                  _TransactionRow(invoice: invoice, isDark: isDark, l10n: l10n),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.invoice,
    required this.isDark,
    required this.l10n,
  });

  final DashboardRecentInvoice invoice;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (invoice.type) {
      'sale' => l10n.sales,
      'purchase' => l10n.purchases,
      'sale_return' => l10n.returns,
      'purchase_return' => l10n.returns,
      _ => invoice.type,
    };
    final statusColor = switch (invoice.status) {
      'paid' => AppColors.success,
      'partial' => AppColors.warning,
      'unpaid' => AppColors.error,
      _ => AppColors.darkTextMuted,
    };
    final statusText = switch (invoice.status) {
      'paid' => l10n.paid,
      'partial' => l10n.partial,
      _ => l10n.unpaid,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                .withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.number,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(invoice.total, invoice.currencyCode),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({
    required this.l10n,
    required this.isDark,
    required this.lowStockProducts,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<DashboardLowStockProduct> lowStockProducts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.lightTextMuted)
                .withValues(alpha: isDark ? 0.22 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.stockAlert,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lowStockProducts.isEmpty)
            Text(
              l10n.stockHealthy,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            )
          else
            ...lowStockProducts
                .take(5)
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${product.stock}/${product.minStock}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({
    required this.l10n,
    required this.isDark,
    required this.stats,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.lightTextMuted)
                .withValues(alpha: isDark ? 0.22 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickStats,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _QuickStatRow(
            label: l10n.products,
            value: '${stats.totalProducts}',
            icon: Icons.inventory_2_rounded,
            isDark: isDark,
          ),
          _QuickStatRow(
            label: l10n.customers,
            value: '${stats.totalCustomers}',
            icon: Icons.people_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  const _QuickStatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
