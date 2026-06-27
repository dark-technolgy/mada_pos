import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/ui_preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../application/report_filter_state.dart';
import '../application/reports_service.dart';
import 'widgets/reports_sections.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _filterPersistDelay = Duration(milliseconds: 200);

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReport = 'sales';
  final ReportsService _reportsService = const ReportsService();
  final UiPreferencesService _prefsService = const UiPreferencesService();

  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalExpenses = 0;
  double _totalProfit = 0;
  List<ReportTimePoint> _dailySales = [];
  List<ReportBreakdownItem> _topProducts = [];
  List<ReportBreakdownItem> _categorySales = [];
  Map<String, Currency> _currencyMap = const {};
  String _reportCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _reportExchangeRate = 1.0;

  bool _isLoading = true;
  String? _loadError;
  Timer? _persistTimer;

  ReportFilterState get _filterState => ReportFilterState(
    startDate: _startDate,
    endDate: _endDate,
    selectedReport: _selectedReport,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final db = ref.read(databaseProvider);
    final raw = await _prefsService.read(db, ReportFilterState.settingsKey);
    final filters = ReportFilterState.fromJsonString(raw);
    setState(() {
      _startDate = filters.startDate;
      _endDate = filters.endDate;
      _selectedReport = filters.selectedReport;
    });
    await _loadReportData();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_filterPersistDelay, () async {
      final db = ref.read(databaseProvider);
      await _prefsService.write(
        db,
        ReportFilterState.settingsKey,
        _filterState.toJsonString(),
      );
    });
  }

  void _applyFilters(ReportFilterState filters) {
    setState(() {
      _startDate = filters.startDate;
      _endDate = filters.endDate;
      _selectedReport = filters.selectedReport;
    });
    _schedulePersist();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final l10n = context.l10n;
    final db = ref.read(databaseProvider);

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final reportData = await _reportsService.loadReportData(
        db,
        startDate: _startDate,
        endDate: _endDate,
        unknownLabel: l10n.unknown,
        withoutCategoryLabel: l10n.withoutCategory,
        branchId: ref.read(activeBranchIdProvider),
      );

      if (!mounted) return;
      setState(() {
        _totalSales = reportData.totalSales;
        _totalPurchases = reportData.totalPurchases;
        _totalExpenses = reportData.totalExpenses;
        _totalProfit = reportData.totalProfit;
        _dailySales = reportData.dailySales;
        _topProducts = reportData.topProducts;
        _categorySales = reportData.categorySales;
        _currencyMap = reportData.currencyMap;
        _reportCurrencyCode = reportData.reportCurrencyCode;
        _reportExchangeRate = reportData.reportExchangeRate;
        _isLoading = false;
      });
    } catch (e, st) {
      await AppLogger.record('Reports load', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '${l10n.error}: $e';
      });
    }
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

  Future<void> _exportReportExcel() async {
    final l10n = context.l10n;
    final showProfit =
        ref.read(sessionManagerProvider).hasPermission('view_profit');
    try {
      final rows = <List<String>>[
        [l10n.sales, _formatReportAmount(_totalSales.abs())],
        [l10n.purchases, _formatReportAmount(_totalPurchases.abs())],
        [l10n.expenses, _formatReportAmount(_totalExpenses.abs())],
        if (showProfit)
          [l10n.profit, _formatReportAmount(_totalProfit.abs())],
        ['', ''],
        [l10n.topProducts, ''],
        ..._topProducts.map(
          (p) => [p.name, _formatReportAmount(p.total.abs())],
        ),
      ];
      final path = await ExcelExportService.exportSheet(
        suggestedFileName:
            'report_${DateFormatter.formatDate(_startDate)}_${DateFormatter.formatDate(_endDate)}',
        sheetData: ExcelSheetData(
          sheetName: l10n.reports,
          headers: [l10n.name, l10n.amount],
          rows: rows,
        ),
      );
      if (!mounted) return;
      if (path != null) {
        AppFeedback.success(context, l10n.exportedTo(path));
      }
    } catch (e, st) {
      await AppLogger.record('Reports export', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.error(context, l10n.error);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range != null) {
      _applyFilters(
        _filterState.copyWith(startDate: range.start, endDate: range.end),
      );
    }
  }

  void _applyQuickRange(int days) {
    final now = DateTime.now();
    _applyFilters(
      _filterState.copyWith(
        startDate: now.subtract(Duration(days: days)),
        endDate: now,
      ),
    );
  }

  List<ReportVisualItem> _financialEntries(
    BuildContext context, {
    required bool showProfit,
  }) {
    final l10n = context.l10n;
    return [
      ReportVisualItem(
        name: l10n.sales,
        value: _totalSales,
        color: AppColors.success,
      ),
      ReportVisualItem(
        name: l10n.purchases,
        value: _totalPurchases,
        color: AppColors.warning,
      ),
      ReportVisualItem(
        name: l10n.expenses,
        value: _totalExpenses,
        color: AppColors.error,
      ),
      if (showProfit)
        ReportVisualItem(
          name: l10n.profit,
          value: _totalProfit,
          color: _totalProfit >= 0 ? AppColors.primary : AppColors.error,
        ),
    ].where((item) => item.value != 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showProfit =
        ref.watch(sessionManagerProvider).hasPermission('view_profit');

    ref.listen<int?>(activeBranchIdProvider, (previous, next) {
      if (previous != next && mounted && !_isLoading && _loadError == null) {
        _loadReportData();
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
        body: ErrorView(message: _loadError!, onRetry: _loadReportData),
      );
    }

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
                onPressed: _exportReportExcel,
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text('${l10n.export} ${l10n.excel}'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(l10n.changePeriod),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(l10n.last7Days),
                  onPressed: () => _applyQuickRange(7),
                ),
                ActionChip(
                  label: Text(l10n.last30Days),
                  onPressed: () => _applyQuickRange(30),
                ),
                ActionChip(
                  label: Text(l10n.thisMonth),
                  onPressed: () {
                    final now = DateTime.now();
                    _applyFilters(
                      _filterState.copyWith(
                        startDate: DateTime(now.year, now.month, 1),
                        endDate: now,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ReportsTypeTabsSection(
            selectedReport: _selectedReport,
            onReportChanged: (value) {
              setState(() => _selectedReport = value);
              _schedulePersist();
            },
            isDark: isDark,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          ReportsSummarySection(
            l10n: l10n,
            isDark: isDark,
            totalSales: _totalSales,
            totalPurchases: _totalPurchases,
            totalExpenses: _totalExpenses,
            totalProfit: _totalProfit,
            formatAmount: _formatReportAmount,
            showProfit: showProfit,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReportsContentSection(
              l10n: l10n,
              isDark: isDark,
              selectedReport: _selectedReport,
              dailySales: _dailySales,
              categorySales: _categorySales,
              financialEntries:
                  _financialEntries(context, showProfit: showProfit),
              topProducts: _topProducts,
              formatAmount: _formatReportAmount,
              formatCompactAmount: _formatCompactReportAmount,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
