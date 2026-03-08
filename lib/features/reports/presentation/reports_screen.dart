import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReport = 'sales';

  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalExpenses = 0;
  double _totalProfit = 0;
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _categorySales = [];
  Map<String, Currency> _currencyMap = const {};
  String _reportCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _reportExchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final db = ref.read(databaseProvider);
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    // Get invoices in date range
    final invoices = await db.select(db.invoices).get();
    final filteredInvoices = invoices
        .where(
          (i) =>
              i.createdAt.isAfter(
                _startDate.subtract(const Duration(days: 1)),
              ) &&
              i.createdAt.isBefore(_endDate.add(const Duration(days: 1))),
        )
        .toList();

    final salesInvoices = filteredInvoices.where(
      (i) => i.type == 'sale' && i.status != 'cancelled',
    );
    final purchaseInvoices = filteredInvoices.where(
      (i) => i.type == 'purchase' && i.status != 'cancelled',
    );

    _totalSales = salesInvoices.fold(
      0.0,
      (sum, i) =>
          sum +
          CurrencyConversion.toBase(
            i.total,
            currencyCode: i.currencyCode,
            exchangeRate: i.exchangeRate,
          ),
    );
    _totalPurchases = purchaseInvoices.fold(
      0.0,
      (sum, i) =>
          sum +
          CurrencyConversion.toBase(
            i.total,
            currencyCode: i.currencyCode,
            exchangeRate: i.exchangeRate,
          ),
    );

    // Expenses
    final expenses = await db.select(db.expenses).get();
    final filteredExpenses = expenses.where(
      (e) =>
          e.createdAt.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          e.createdAt.isBefore(_endDate.add(const Duration(days: 1))),
    );
    _totalExpenses = filteredExpenses.fold(
      0.0,
      (sum, e) =>
          sum +
          CurrencyConversion.toBase(
            e.amount,
            currencyCode: e.currencyCode,
            currencies: currencyMap,
          ),
    );

    _totalProfit = _totalSales - _totalPurchases - _totalExpenses;

    final saleInvoicesById = {
      for (final invoice in salesInvoices) invoice.id: invoice,
    };

    // Daily sales for chart
    final dailyMap = <String, double>{};
    for (final inv in salesInvoices) {
      final day = DateFormatter.formatDate(inv.createdAt);
      dailyMap[day] =
          (dailyMap[day] ?? 0) +
          CurrencyConversion.toBase(
            inv.total,
            currencyCode: inv.currencyCode,
            exchangeRate: inv.exchangeRate,
          );
    }
    _dailySales = dailyMap.entries
        .map((e) => {'date': e.key, 'amount': e.value})
        .toList();

    // Top products
    final invoiceItems = await db.select(db.invoiceItems).get();
    final products = await db.select(db.products).get();
    final productSales = <int, double>{};
    for (final item in invoiceItems) {
      final inv = saleInvoicesById[item.invoiceId];
      if (inv == null) continue;
      productSales[item.productId] =
          (productSales[item.productId] ?? 0) +
          CurrencyConversion.toBase(
            item.total,
            currencyCode: inv.currencyCode,
            exchangeRate: inv.exchangeRate,
          );
    }
    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _topProducts = sortedProducts.take(10).map((e) {
      final product = products.where((p) => p.id == e.key).firstOrNull;
      return {
        'name': product?.nameAr ?? context.l10n.unknown,
        'total': e.value,
      };
    }).toList();

    // Category sales
    final categories = await db.select(db.categories).get();
    final catSales = <int, double>{};
    for (final item in invoiceItems) {
      if (!saleInvoicesById.containsKey(item.invoiceId)) continue;
      final product = products.where((p) => p.id == item.productId).firstOrNull;
      final invoice = saleInvoicesById[item.invoiceId];
      if (invoice == null) continue;
      if (product?.categoryId != null) {
        catSales[product!.categoryId!] =
            (catSales[product.categoryId!] ?? 0) +
            CurrencyConversion.toBase(
              item.total,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            );
      }
    }
    _categorySales = catSales.entries.map((e) {
      final cat = categories.where((c) => c.id == e.key).firstOrNull;
      return {
        'name': cat?.nameAr ?? context.l10n.withoutCategory,
        'total': e.value,
      };
    }).toList();

    setState(() {
      _currencyMap = currencyMap;
      _reportCurrencyCode =
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode;
      _reportExchangeRate = CurrencyConversion.normalizeRate(
        _reportCurrencyCode,
        defaultCurrency?.exchangeRate,
      );
    });
  }

  String _formatReportAmount(double baseAmount) {
    final displayAmount = CurrencyConversion.fromBase(
      baseAmount,
      currencyCode: _reportCurrencyCode,
      exchangeRate: _reportExchangeRate,
    );
    return CurrencyFormatter.format(
      displayAmount,
      _reportCurrencyCode,
      symbol: _currencyMap[_reportCurrencyCode]?.symbol,
    );
  }

  String _formatCompactReportAmount(double baseAmount) {
    final displayAmount = CurrencyConversion.fromBase(
      baseAmount,
      currencyCode: _reportCurrencyCode,
      exchangeRate: _reportExchangeRate,
    );
    return CurrencyFormatter.formatCompact(displayAmount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.reports,
            subtitle:
                '${DateFormatter.formatDate(_startDate)} - ${DateFormatter.formatDate(_endDate)}',
            actions: [
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: _startDate,
                      end: _endDate,
                    ),
                  );
                  if (range != null) {
                    _startDate = range.start;
                    _endDate = range.end;
                    _loadReportData();
                  }
                },
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(l10n.changePeriod),
              ),
            ],
          ),
          // Report type selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildReportTab(
                  'sales',
                  l10n.sales,
                  Icons.trending_up_rounded,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildReportTab(
                  'products',
                  l10n.products,
                  Icons.inventory_2_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildReportTab(
                  'financial',
                  l10n.financial,
                  Icons.account_balance_wallet_outlined,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSummaryCard(
                  l10n.sales,
                  _totalSales,
                  AppColors.success,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  l10n.purchases,
                  _totalPurchases,
                  AppColors.warning,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  l10n.expenses,
                  _totalExpenses,
                  AppColors.error,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  l10n.profit,
                  _totalProfit,
                  _totalProfit >= 0 ? AppColors.success : AppColors.error,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Chart and Data
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chart
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (_selectedReport) {
                              'products' => l10n.salesByCategory,
                              'financial' => l10n.financialBreakdown,
                              _ => l10n.dailySalesLabel,
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: switch (_selectedReport) {
                              'products' => _buildCategoryPieChart(isDark),
                              'financial' => _buildFinancialPieChart(isDark),
                              _ => _buildBarChart(isDark),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Top products / Details
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (_selectedReport) {
                              'products' => l10n.categoryBreakdown,
                              'financial' => l10n.financialBreakdown,
                              _ => l10n.topProducts,
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildDetailsPanel(context, isDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBarChart(bool isDark) {
    if (_dailySales.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            _dailySales.fold(0.0, (max, e) {
              final v = e['amount'] as double;
              return v > max ? v : max;
            }) *
            1.2,
        barGroups: _dailySales.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value['amount'],
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
                if (value.toInt() >= _dailySales.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dailySales[value.toInt()]['date'].toString().substring(
                      0,
                      5,
                    ),
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
                  _formatCompactReportAmount(value),
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

  Widget _buildCategoryPieChart(bool isDark) {
    if (_categorySales.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    final colors = [
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

    return PieChart(
      PieChartData(
        sections: _categorySales.asMap().entries.map((e) {
          final total = _categorySales.fold(
            0.0,
            (sum, item) => sum + (item['total'] as double),
          );
          final percentage = total > 0
              ? (e.value['total'] as double) / total * 100
              : 0;
          return PieChartSectionData(
            value: e.value['total'],
            title: '${percentage.toStringAsFixed(0)}%',
            color: colors[e.key % colors.length],
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

  Widget _buildFinancialPieChart(bool isDark) {
    final entries = _financialEntries(context);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((entry) {
          final total = entries.fold<double>(
            0,
            (sum, item) => sum + (item['value'] as double).abs(),
          );
          final value = (entry.value['value'] as double).abs();
          final percentage = total > 0 ? value / total * 100 : 0.0;
          return PieChartSectionData(
            value: value,
            title: '${percentage.toStringAsFixed(0)}%',
            color: entry.value['color'] as Color,
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

  Widget _buildDetailsPanel(BuildContext context, bool isDark) {
    final items = switch (_selectedReport) {
      'products' => _categorySales,
      'financial' => _financialEntries(context),
      _ => _topProducts,
    };

    if (items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final accentColor = item['color'] as Color? ?? AppColors.primary;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: accentColor.withValues(alpha: 0.1),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            item['name'] as String,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            _selectedReport == 'financial'
                ? _formatReportAmount(item['value'] as double)
                : _formatReportAmount(item['total'] as double),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _financialEntries(BuildContext context) {
    final l10n = context.l10n;
    return [
      {'name': l10n.sales, 'value': _totalSales, 'color': AppColors.success},
      {
        'name': l10n.purchases,
        'value': _totalPurchases,
        'color': AppColors.warning,
      },
      {
        'name': l10n.expenses,
        'value': _totalExpenses,
        'color': AppColors.error,
      },
      {
        'name': l10n.profit,
        'value': _totalProfit,
        'color': _totalProfit >= 0 ? AppColors.primary : AppColors.error,
      },
    ].where((item) => (item['value'] as double) != 0).toList();
  }

  Widget _buildReportTab(
    String type,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedReport == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedReport = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildSummaryCard(
    String label,
    double value,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
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
              _formatReportAmount(value.abs()),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
