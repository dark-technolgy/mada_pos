import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/services/ui_preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../application/dashboard_layout_prefs.dart';
import '../application/dashboard_service.dart';
import '../../../core/smart/smart_insights_service.dart';
import '../../../core/services/update_service.dart';
import 'widgets/dashboard_sections.dart';
import 'widgets/dashboard_smart_insights.dart';
import 'widgets/dashboard_customize_dialog.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final DashboardService _dashboardService = const DashboardService();
  final SmartInsightsService _smartService = const SmartInsightsService();
  final UiPreferencesService _prefsService = const UiPreferencesService();

  DashboardStats _stats = const DashboardStats(
    todaySales: 0,
    todayCount: 0,
    todayProfit: 0,
    monthlySales: 0,
    monthlyCount: 0,
    totalProducts: 0,
    totalCustomers: 0,
    totalDebts: 0,
    overdueDebtsCount: 0,
    heldInvoicesCount: 0,
    grossMarginPercent: 0,
    collectionRatePercent: 100,
  );
  List<DashboardRecentInvoice> _recentInvoices = [];
  List<DashboardLowStockProduct> _lowStockProducts = [];
  Map<String, Currency> _currencyMap = const {};
  String _displayCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _displayExchangeRate = 1.0;
  bool _isLoading = true;
  String? _loadError;
  List<SmartInsight> _smartInsights = const [];
  List<SmartTopProduct> _topProductsToday = const [];
  double? _salesChangePercent;
  DashboardLayoutPrefs _layout = DashboardLayoutPrefs.defaults;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final db = ref.read(databaseProvider);
    final raw = await _prefsService.read(db, DashboardLayoutPrefs.settingsKey);
    setState(() {
      _layout = DashboardLayoutPrefs.fromJsonString(raw);
    });
    await _loadDashboardData();
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    final updater = UpdateService(githubUser: 'dark-technolgy', githubRepo: 'mada_pos');
    final update = await updater.checkForUpdate();
    if (update != null && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تحديث جديد متوفر'),
          content: Text('الإصدار ${update.latestVersion} متوفر الآن. هل تريد التحديث؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لاحقاً')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحديث الآن')),
          ],
        ),
      );
      if (confirm == true) {
        await updater.launchUpdate(update.downloadUrl);
      }
    }
  }

  Future<void> _loadDashboardData() async {
    final db = ref.read(databaseProvider);
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final branchId = ref.read(activeBranchIdProvider);
      final result = await _dashboardService.loadDashboardData(
        db,
        branchId: branchId,
      );
      final smart = await _smartService.load(db, branchId: branchId);

      setState(() {
        _stats = result.stats;
        _recentInvoices = result.recentInvoices;
        _lowStockProducts = result.lowStockProducts;
        _currencyMap = result.currencyMap;
        _displayCurrencyCode = result.displayCurrencyCode;
        _displayExchangeRate = result.displayExchangeRate;
        _smartInsights = smart.insights;
        _topProductsToday = smart.topProductsToday;
        _salesChangePercent = smart.salesChangePercent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = '${context.l10n.dashboardLoadFailed}: $e';
      });
    }
  }

  Future<void> _openCustomize() async {
    final updated = await DashboardCustomizeDialog.show(
      context,
      initial: _layout,
    );
    if (updated == null || !mounted) return;

    setState(() => _layout = updated);
    final db = ref.read(databaseProvider);
    await _prefsService.write(
      db,
      DashboardLayoutPrefs.settingsKey,
      updated.toJsonString(),
    );
    if (mounted) {
      AppFeedback.success(context, context.l10n.savedSuccessfully);
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
    final showProfit =
        ref.watch(sessionManagerProvider).hasPermission('view_profit');

    ref.listen<int?>(activeBranchIdProvider, (previous, next) {
      if (previous != next && mounted && !_isLoading && _loadError == null) {
        _loadDashboardData();
      }
    });

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: LoadingView(message: l10n.loading),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: ErrorView(
          message: _loadError!,
          onRetry: _loadDashboardData,
        ),
      );
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
              DashboardHeaderSection(
                l10n: l10n,
                isDark: isDark,
                user: user,
                onNewSale: () => context.go('/pos'),
                onAddCustomer: () => context.go('/customers/add'),
                onAddProduct: () => context.go('/products/add'),
                onCustomize: _openCustomize,
              ),
              if (_layout.showStats) ...[
                const SizedBox(height: 24),
                DashboardStatsSection(
                  l10n: l10n,
                  stats: _stats,
                  formatDisplayBaseAmount: _formatDisplayBaseAmount,
                  showProfit: showProfit,
                ),
                const SizedBox(height: 16),
                DashboardExecutiveKpisSection(
                  l10n: l10n,
                  stats: _stats,
                  formatDisplayBaseAmount: _formatDisplayBaseAmount,
                ),
                if (_stats.topCustomerName != null) ...[
                  const SizedBox(height: 16),
                  DashboardTopCustomerBanner(
                    l10n: l10n,
                    customerName: _stats.topCustomerName!,
                    salesAmount: _stats.topCustomerSalesBase,
                    formatDisplayBaseAmount: _formatDisplayBaseAmount,
                  ),
                ],
              ],
              if (_layout.showSmartInsights) ...[
                const SizedBox(height: 24),
                DashboardSmartInsightsSection(
                  l10n: l10n,
                  isDark: isDark,
                  insights: _smartInsights,
                  topProducts: _topProductsToday,
                  salesChangePercent: _salesChangePercent,
                ),
              ],
              if (_layout.showRecentTransactions || _layout.showLowStock) ...[
                const SizedBox(height: 24),
                DashboardContentSection(
                  l10n: l10n,
                  isDark: isDark,
                  recentInvoices: _recentInvoices,
                  lowStockProducts: _lowStockProducts,
                  stats: _stats,
                  onViewAllInvoices: () => context.go('/invoices'),
                  showRecentTransactions: _layout.showRecentTransactions,
                  showLowStock: _layout.showLowStock,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
