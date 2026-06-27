import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../application/reports_service.dart';

class ReportVisualItem {
  const ReportVisualItem({
    required this.name,
    required this.value,
    required this.color,
  });

  final String name;
  final double value;
  final Color color;
}

class ReportsTypeTabsSection extends StatelessWidget {
  const ReportsTypeTabsSection({
    super.key,
    required this.selectedReport,
    required this.onReportChanged,
    required this.isDark,
    required this.l10n,
  });

  final String selectedReport;
  final ValueChanged<String> onReportChanged;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: AppColors.cardShadow(isDark),
        ),
        child: Row(
          children: [
            _ReportTabButton(
              type: 'sales',
              label: l10n.sales,
              icon: Icons.trending_up_rounded,
              selectedReport: selectedReport,
              isDark: isDark,
              onTap: onReportChanged,
            ),
            const SizedBox(width: 8),
            _ReportTabButton(
              type: 'products',
              label: l10n.products,
              icon: Icons.inventory_2_outlined,
              selectedReport: selectedReport,
              isDark: isDark,
              onTap: onReportChanged,
            ),
            const SizedBox(width: 8),
            _ReportTabButton(
              type: 'financial',
              label: l10n.financial,
              icon: Icons.account_balance_wallet_outlined,
              selectedReport: selectedReport,
              isDark: isDark,
              onTap: onReportChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsSummarySection extends StatelessWidget {
  const ReportsSummarySection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalProfit,
    required this.formatAmount,
    this.showProfit = true,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalProfit;
  final String Function(double amount) formatAmount;
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _ReportSummaryCard(
            label: l10n.sales,
            value: formatAmount(totalSales.abs()),
            color: AppColors.success,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _ReportSummaryCard(
            label: l10n.purchases,
            value: formatAmount(totalPurchases.abs()),
            color: AppColors.warning,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _ReportSummaryCard(
            label: l10n.expenses,
            value: formatAmount(totalExpenses.abs()),
            color: AppColors.error,
            isDark: isDark,
          ),
          if (showProfit) ...[
            const SizedBox(width: 16),
            _ReportSummaryCard(
              label: l10n.profit,
              value: formatAmount(totalProfit.abs()),
              color: totalProfit >= 0 ? AppColors.success : AppColors.error,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class ReportsContentSection extends StatelessWidget {
  const ReportsContentSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.selectedReport,
    required this.dailySales,
    required this.categorySales,
    required this.financialEntries,
    required this.topProducts,
    required this.formatAmount,
    required this.formatCompactAmount,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final String selectedReport;
  final List<ReportTimePoint> dailySales;
  final List<ReportBreakdownItem> categorySales;
  final List<ReportVisualItem> financialEntries;
  final List<ReportBreakdownItem> topProducts;
  final String Function(double amount) formatAmount;
  final String Function(double amount) formatCompactAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _ReportsCardFrame(
              isDark: isDark,
              title: switch (selectedReport) {
                'products' => l10n.salesByCategory,
                'financial' => l10n.financialBreakdown,
                _ => l10n.dailySalesLabel,
              },
              child: switch (selectedReport) {
                'products' => _CategoryPieChart(
                  isDark: isDark,
                  l10n: l10n,
                  items: categorySales,
                ),
                'financial' => _FinancialPieChart(
                  isDark: isDark,
                  l10n: l10n,
                  items: financialEntries,
                ),
                _ => _SalesBarChart(
                  isDark: isDark,
                  l10n: l10n,
                  dailySales: dailySales,
                  formatCompactAmount: formatCompactAmount,
                ),
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _ReportsCardFrame(
              isDark: isDark,
              title: switch (selectedReport) {
                'products' => l10n.categoryBreakdown,
                'financial' => l10n.financialBreakdown,
                _ => l10n.topProducts,
              },
              child: _DetailsPanel(
                isDark: isDark,
                l10n: l10n,
                items: switch (selectedReport) {
                  'products' =>
                    categorySales
                        .map(
                          (item) => ReportVisualItem(
                            name: item.name,
                            value: item.total,
                            color: AppColors.primary,
                          ),
                        )
                        .toList(),
                  'financial' => financialEntries,
                  _ =>
                    topProducts
                        .map(
                          (item) => ReportVisualItem(
                            name: item.name,
                            value: item.total,
                            color: AppColors.primary,
                          ),
                        )
                        .toList(),
                },
                formatAmount: formatAmount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTabButton extends StatelessWidget {
  const _ReportTabButton({
    required this.type,
    required this.label,
    required this.icon,
    required this.selectedReport,
    required this.isDark,
    required this.onTap,
  });

  final String type;
  final String label;
  final IconData icon;
  final String selectedReport;
  final bool isDark;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedReport == type;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(type),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: AppColors.cardShadow(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsCardFrame extends StatelessWidget {
  const _ReportsCardFrame({
    required this.isDark,
    required this.title,
    required this.child,
  });

  final bool isDark;
  final String title;
  final Widget child;

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
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({
    required this.isDark,
    required this.l10n,
    required this.dailySales,
    required this.formatCompactAmount,
  });

  final bool isDark;
  final AppLocalizations l10n;
  final List<ReportTimePoint> dailySales;
  final String Function(double amount) formatCompactAmount;

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return _NoDataLabel(isDark: isDark, label: l10n.noData);
    }

    final maxAmount = dailySales.fold<double>(
      0.0,
      (currentMax, point) =>
          point.amount > currentMax ? point.amount : currentMax,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAmount * 1.2,
        barGroups: dailySales.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.amount,
                color: AppColors.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= dailySales.length) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormatter.formatDate(
                      dailySales[value.toInt()].date,
                    ).substring(0, 5),
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  formatCompactAmount(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                .withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({
    required this.isDark,
    required this.l10n,
    required this.items,
  });

  final bool isDark;
  final AppLocalizations l10n;
  final List<ReportBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _NoDataLabel(isDark: isDark, label: l10n.noData);
    }

    const colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final total = items.fold<double>(0.0, (sum, item) => sum + item.total);

    return PieChart(
      PieChartData(
        sections: items.asMap().entries.map((entry) {
          final percentage = total > 0 ? entry.value.total / total * 100 : 0.0;
          return PieChartSectionData(
            value: entry.value.total,
            title: '${percentage.toStringAsFixed(0)}%',
            color: colors[entry.key % colors.length],
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}

class _FinancialPieChart extends StatelessWidget {
  const _FinancialPieChart({
    required this.isDark,
    required this.l10n,
    required this.items,
  });

  final bool isDark;
  final AppLocalizations l10n;
  final List<ReportVisualItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _NoDataLabel(isDark: isDark, label: l10n.noData);
    }

    final total = items.fold<double>(
      0.0,
      (sum, item) => sum + item.value.abs(),
    );

    return PieChart(
      PieChartData(
        sections: items.map((item) {
          final value = item.value.abs();
          final percentage = total > 0 ? value / total * 100 : 0.0;
          return PieChartSectionData(
            value: value,
            title: '${percentage.toStringAsFixed(0)}%',
            color: item.color,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.isDark,
    required this.l10n,
    required this.items,
    required this.formatAmount,
  });

  final bool isDark;
  final AppLocalizations l10n;
  final List<ReportVisualItem> items;
  final String Function(double amount) formatAmount;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _NoDataLabel(isDark: isDark, label: l10n.noData);
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: item.color.withValues(alpha: 0.1),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: item.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            item.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            formatAmount(item.value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
        );
      },
    );
  }
}

class _NoDataLabel extends StatelessWidget {
  const _NoDataLabel({required this.isDark, required this.label});

  final bool isDark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }
}
