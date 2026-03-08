import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/stat_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentInvoices = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  Map<String, Currency> _currencyMap = const {};
  String _displayCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _displayExchangeRate = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      final currencies = await db.select(db.currencies).get();
      final currencyMap = {
        for (final currency in currencies) currency.code: currency,
      };
      final defaultCurrency = CurrencyConversion.findDefaultCurrency(
        currencies,
      );
      // Today's sales
      final todaySales =
          await (db.select(db.invoices)
                ..where((i) => i.type.equals('sale'))
                ..where((i) => i.createdAt.isBiggerOrEqualValue(startOfDay))
                ..where((i) => i.status.isNotIn(['cancelled', 'draft'])))
              .get();

      final todayTotal = todaySales.fold(
        0.0,
        (sum, inv) =>
            sum +
            CurrencyConversion.toBase(
              inv.total,
              currencyCode: inv.currencyCode,
              exchangeRate: inv.exchangeRate,
            ),
      );
      final todayProfit = todaySales.fold(
        0.0,
        (sum, inv) =>
            sum +
            CurrencyConversion.toBase(
              inv.total - inv.subtotal + inv.discountAmount,
              currencyCode: inv.currencyCode,
              exchangeRate: inv.exchangeRate,
            ),
      );

      // Monthly sales
      final monthlySales =
          await (db.select(db.invoices)
                ..where((i) => i.type.equals('sale'))
                ..where((i) => i.createdAt.isBiggerOrEqualValue(startOfMonth))
                ..where((i) => i.status.isNotIn(['cancelled', 'draft'])))
              .get();

      final monthlyTotal = monthlySales.fold(
        0.0,
        (sum, inv) =>
            sum +
            CurrencyConversion.toBase(
              inv.total,
              currencyCode: inv.currencyCode,
              exchangeRate: inv.exchangeRate,
            ),
      );

      // Total counts
      final totalProducts = await (db.select(
        db.products,
      )..where((p) => p.isActive.equals(true))).get();
      final totalCustomers = await db.select(db.customers).get();

      // Outstanding debts
      final activeDebts = await (db.select(
        db.debts,
      )..where((d) => d.status.isIn(['active', 'partial']))).get();
      final totalDebts = activeDebts.fold(
        0.0,
        (sum, d) =>
            sum +
            CurrencyConversion.toBase(
              d.remainingAmount,
              currencyCode: d.currencyCode,
              currencies: currencyMap,
            ),
      );

      // Recent invoices
      final recent =
          await (db.select(db.invoices)
                ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
                ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
                ..limit(10))
              .get();

      // Low stock products
      final products = await (db.select(
        db.products,
      )..where((p) => p.isActive.equals(true))).get();
      final stocks = await db.select(db.stock).get();
      final lowStock = <Map<String, dynamic>>[];
      for (final prod in products) {
        final productStocks = stocks.where((s) => s.productId == prod.id);
        final totalQty = productStocks.fold(0.0, (sum, s) => sum + s.quantity);
        if (totalQty <= prod.minStockLevel && prod.minStockLevel > 0) {
          lowStock.add({
            'name': prod.nameAr,
            'stock': totalQty,
            'minStock': prod.minStockLevel,
          });
        }
      }

      setState(() {
        _stats = {
          'todaySales': todayTotal,
          'todayCount': todaySales.length,
          'todayProfit': todayProfit,
          'monthlySales': monthlyTotal,
          'monthlyCount': monthlySales.length,
          'totalProducts': totalProducts.length,
          'totalCustomers': totalCustomers.length,
          'totalDebts': totalDebts,
        };
        _recentInvoices = recent
            .map(
              (i) => {
                'number': i.invoiceNumber,
                'type': i.type,
                'total': i.total,
                'currencyCode': i.currencyCode,
                'status': i.status,
                'date': i.createdAt,
              },
            )
            .toList();
        _lowStockProducts = lowStock;
        _currencyMap = currencyMap;
        _displayCurrencyCode =
            defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode;
        _displayExchangeRate = CurrencyConversion.normalizeRate(
          _displayCurrencyCode,
          defaultCurrency?.exchangeRate,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.dashboardLoadFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDisplayBaseAmount(double baseAmount) {
    final displayAmount = CurrencyConversion.fromBase(
      baseAmount,
      currencyCode: _displayCurrencyCode,
      exchangeRate: _displayExchangeRate,
    );
    return CurrencyFormatter.format(
      displayAmount,
      _displayCurrencyCode,
      symbol: _currencyMap[_displayCurrencyCode]?.symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.welcomeBack}، ${user?.fullName ?? ""} 👋',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
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
                      _buildQuickAction(
                        context,
                        Icons.add_shopping_cart_rounded,
                        l10n.newSale,
                        AppColors.primaryGradient,
                        () => context.go('/pos'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickAction(
                        context,
                        Icons.person_add_rounded,
                        l10n.addCustomer,
                        AppColors.accentGradient,
                        () => context.go('/customers/add'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickAction(
                        context,
                        Icons.add_box_rounded,
                        l10n.addProduct,
                        AppColors.successGradient,
                        () => context.go('/products/add'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── STAT CARDS ───
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: l10n.todaySales,
                      value: _formatDisplayBaseAmount(
                        (_stats['todaySales'] ?? 0) as double,
                      ),
                      icon: Icons.trending_up_rounded,
                      gradient: AppColors.primaryGradient,
                      subtitle: '${_stats['todayCount'] ?? 0} ${l10n.invoices}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: l10n.todayProfit,
                      value: _formatDisplayBaseAmount(
                        (_stats['todayProfit'] ?? 0) as double,
                      ),
                      icon: Icons.account_balance_wallet_rounded,
                      gradient: AppColors.accentGradient,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: l10n.totalDebtsLabel,
                      value: _formatDisplayBaseAmount(
                        (_stats['totalDebts'] ?? 0) as double,
                      ),
                      icon: Icons.receipt_long_rounded,
                      gradient: AppColors.warningGradient,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: l10n.monthlySalesLabel,
                      value: _formatDisplayBaseAmount(
                        (_stats['monthlySales'] ?? 0) as double,
                      ),
                      icon: Icons.calendar_month_rounded,
                      gradient: AppColors.successGradient,
                      subtitle:
                          '${_stats['monthlyCount'] ?? 0} ${l10n.invoices}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── CHARTS & TABLES ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent Transactions
                  Expanded(
                    flex: 3,
                    child: _buildRecentTransactions(context, isDark),
                  ),
                  const SizedBox(width: 16),
                  // Low Stock & Quick Stats
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildLowStockAlert(context, isDark),
                        const SizedBox(height: 16),
                        _buildQuickStats(context, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
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

  Widget _buildRecentTransactions(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
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
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/invoices'),
                child: Text(l10n.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentInvoices.isEmpty)
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
            ..._recentInvoices.map((inv) => _buildTransactionRow(inv, isDark)),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> inv, bool isDark) {
    final l10n = context.l10n;
    final typeLabel = switch (inv['type']) {
      'sale' => l10n.sales,
      'purchase' => l10n.purchases,
      'sale_return' => l10n.returns,
      'purchase_return' => l10n.returns,
      _ => inv['type'],
    };
    final statusColor = switch (inv['status']) {
      'paid' => AppColors.success,
      'partial' => AppColors.warning,
      'unpaid' => AppColors.error,
      _ => AppColors.darkTextMuted,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv['number'] ?? '',
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
                CurrencyFormatter.format(
                  (inv['total'] ?? 0) as double,
                  (inv['currencyCode'] ?? CurrencyConversion.baseCurrencyCode)
                      as String,
                ),
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
                  inv['status'] == 'paid'
                      ? l10n.paid
                      : inv['status'] == 'partial'
                      ? l10n.partial
                      : l10n.unpaid,
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

  Widget _buildLowStockAlert(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
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
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lowStockProducts.isEmpty)
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
            ..._lowStockProducts
                .take(5)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p['name'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${p['stock']}/${p['minStock']}',
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

  Widget _buildQuickStats(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickStats,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickStatRow(
            l10n.products,
            '${_stats['totalProducts'] ?? 0}',
            Icons.inventory_2_rounded,
            isDark,
          ),
          _buildQuickStatRow(
            l10n.customers,
            '${_stats['totalCustomers'] ?? 0}',
            Icons.people_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
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
