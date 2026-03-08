import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/services/invoice_list_export_service.dart';
import '../../../core/services/invoice_print_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  static const _filtersSettingKey = 'invoices_last_filters';
  static const _filterPersistDelay = Duration(milliseconds: 150);
  static const _defaultFilterState = _InvoiceFilterState();

  late TabController _tabController;
  late final TextEditingController _searchController;
  Timer? _persistFiltersTimer;
  Future<void> _persistFiltersTask = Future.value();
  List<Invoice> _invoices = [];
  List<Invoice> _filtered = [];
  List<Customer> _customers = [];
  Map<int, double> _itemDiscountTotals = {};
  Map<String, Currency> _currencyMap = const {};
  String _displayCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _displayExchangeRate = 1.0;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  String _currencyFilter = 'all';
  String _dateFilter = 'all';
  DateTime? _customFromDate;
  DateTime? _customToDate;
  bool _discountOnly = false;
  String _sortField = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _applyFilter();
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _persistFiltersTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final invoices = await (db.select(
      db.invoices,
    )..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).get();
    final customers = await db.select(db.customers).get();
    final currencies = await db.select(db.currencies).get();
    final invoiceItems = await db.select(db.invoiceItems).get();
    final savedFilters = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(_filtersSettingKey))).getSingleOrNull();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);
    final itemDiscountTotals = <int, double>{};
    for (final item in invoiceItems) {
      itemDiscountTotals.update(
        item.invoiceId,
        (value) => value + item.discount,
        ifAbsent: () => item.discount,
      );
    }

    final restoredFilterState = _parseSavedFilters(savedFilters?.value);
    _searchController.text = restoredFilterState.searchQuery;

    setState(() {
      _invoices = invoices;
      _customers = customers;
      _itemDiscountTotals = itemDiscountTotals;
      _currencyMap = currencyMap;
      _displayCurrencyCode =
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode;
      _displayExchangeRate = CurrencyConversion.normalizeRate(
        _displayCurrencyCode,
        defaultCurrency?.exchangeRate,
      );
      _searchQuery = restoredFilterState.searchQuery;
      _statusFilter = restoredFilterState.statusFilter;
      _paymentFilter = restoredFilterState.paymentFilter;
      _currencyFilter = restoredFilterState.currencyFilter;
      _dateFilter = restoredFilterState.dateFilter;
      _customFromDate = restoredFilterState.customFromDate;
      _customToDate = restoredFilterState.customToDate;
      _discountOnly = restoredFilterState.discountOnly;
      _sortField = restoredFilterState.sortField;
      _sortAscending = restoredFilterState.sortAscending;
      _applyFilter(persist: false);
    });
  }

  _InvoiceFilterState _parseSavedFilters(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return const _InvoiceFilterState();
    }

    try {
      final data = jsonDecode(rawValue) as Map<String, dynamic>;
      return _InvoiceFilterState(
        searchQuery: data['searchQuery'] as String? ?? '',
        statusFilter: data['statusFilter'] as String? ?? 'all',
        paymentFilter: data['paymentFilter'] as String? ?? 'all',
        currencyFilter: data['currencyFilter'] as String? ?? 'all',
        dateFilter: data['dateFilter'] as String? ?? 'all',
        customFromDate: _parseDate(data['customFromDate'] as String?),
        customToDate: _parseDate(data['customToDate'] as String?),
        discountOnly: data['discountOnly'] as bool? ?? false,
        sortField: data['sortField'] as String? ?? 'date',
        sortAscending: data['sortAscending'] as bool? ?? false,
      );
    } catch (_) {
      return const _InvoiceFilterState();
    }
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _persistFilterState() async {
    if (!mounted) return;

    final db = ref.read(databaseProvider);
    final payload = jsonEncode({
      'searchQuery': _searchQuery,
      'statusFilter': _statusFilter,
      'paymentFilter': _paymentFilter,
      'currencyFilter': _currencyFilter,
      'dateFilter': _dateFilter,
      'customFromDate': _customFromDate?.toIso8601String(),
      'customToDate': _customToDate?.toIso8601String(),
      'discountOnly': _discountOnly,
      'sortField': _sortField,
      'sortAscending': _sortAscending,
    });

    try {
      final updatedRows =
          await (db.update(
            db.settings,
          )..where((s) => s.key.equals(_filtersSettingKey))).write(
            SettingsCompanion(value: Value(payload), group: const Value('ui')),
          );
      if (updatedRows == 0) {
        try {
          await db
              .into(db.settings)
              .insert(
                SettingsCompanion.insert(
                  key: _filtersSettingKey,
                  value: payload,
                  group: const Value('ui'),
                ),
              );
        } on Exception {
          await (db.update(
            db.settings,
          )..where((s) => s.key.equals(_filtersSettingKey))).write(
            SettingsCompanion(value: Value(payload), group: const Value('ui')),
          );
        }
      }
    } on StateError {
      return;
    }
  }

  void _storeFilters() {
    _persistFiltersTimer?.cancel();
    _persistFiltersTimer = Timer(_filterPersistDelay, () {
      if (!mounted) return;
      _persistFiltersTask = _persistFiltersTask.then((_) async {
        await _persistFilterState();
      });
    });
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _statusFilter != _defaultFilterState.statusFilter ||
        _paymentFilter != _defaultFilterState.paymentFilter ||
        _currencyFilter != _defaultFilterState.currencyFilter ||
        _dateFilter != _defaultFilterState.dateFilter ||
        _customFromDate != null ||
        _customToDate != null ||
        _discountOnly != _defaultFilterState.discountOnly ||
        _sortField != _defaultFilterState.sortField ||
        _sortAscending != _defaultFilterState.sortAscending;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = _defaultFilterState.searchQuery;
      _statusFilter = _defaultFilterState.statusFilter;
      _paymentFilter = _defaultFilterState.paymentFilter;
      _currencyFilter = _defaultFilterState.currencyFilter;
      _dateFilter = _defaultFilterState.dateFilter;
      _customFromDate = _defaultFilterState.customFromDate;
      _customToDate = _defaultFilterState.customToDate;
      _discountOnly = _defaultFilterState.discountOnly;
      _sortField = _defaultFilterState.sortField;
      _sortAscending = _defaultFilterState.sortAscending;
      _applyFilter();
    });
  }

  double get _filteredTotalBase => _filtered.fold(
    0.0,
    (sum, invoice) =>
        sum +
        CurrencyConversion.toBase(
          invoice.total,
          currencyCode: invoice.currencyCode,
          exchangeRate: invoice.exchangeRate,
        ),
  );

  double get _filteredPaidBase => _filtered.fold(
    0.0,
    (sum, invoice) =>
        sum +
        CurrencyConversion.toBase(
          invoice.paidAmount,
          currencyCode: invoice.currencyCode,
          exchangeRate: invoice.exchangeRate,
        ),
  );

  double get _filteredRemainingBase => _filtered.fold(
    0.0,
    (sum, invoice) =>
        sum +
        CurrencyConversion.toBase(
          invoice.remaining,
          currencyCode: invoice.currencyCode,
          exchangeRate: invoice.exchangeRate,
        ),
  );

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

  String _getCustomerName(int? customerId) {
    final l10n = context.l10n;
    if (customerId == null) return l10n.cashCustomer;
    final c = _customers.where((c) => c.id == customerId);
    return c.isNotEmpty ? c.first.name : l10n.unknown;
  }

  double _totalDiscountFor(Invoice invoice) {
    return invoice.discountAmount + (_itemDiscountTotals[invoice.id] ?? 0);
  }

  void _applyFilter({bool persist = true}) {
    final type = ['sale', 'purchase', 'return'][_tabController.index];
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final customFrom = _customFromDate == null
        ? null
        : DateTime(
            _customFromDate!.year,
            _customFromDate!.month,
            _customFromDate!.day,
          );
    final customTo = _customToDate == null
        ? null
        : DateTime(
            _customToDate!.year,
            _customToDate!.month,
            _customToDate!.day,
            23,
            59,
            59,
            999,
          );
    _filtered = _invoices.where((inv) {
      if (inv.type != type) return false;
      if (_dateFilter == 'today' && inv.createdAt.isBefore(startOfToday)) {
        return false;
      }
      if (_dateFilter == 'thisWeek' && inv.createdAt.isBefore(startOfWeek)) {
        return false;
      }
      if (_dateFilter == 'thisMonth' && inv.createdAt.isBefore(startOfMonth)) {
        return false;
      }
      if (_dateFilter == 'custom') {
        if (customFrom != null && inv.createdAt.isBefore(customFrom)) {
          return false;
        }
        if (customTo != null && inv.createdAt.isAfter(customTo)) {
          return false;
        }
      }
      if (_statusFilter != 'all' && inv.status != _statusFilter) return false;
      if (_paymentFilter != 'all' && inv.paymentMethod != _paymentFilter) {
        return false;
      }
      if (_currencyFilter != 'all' && inv.currencyCode != _currencyFilter) {
        return false;
      }
      if (_discountOnly) {
        final itemDiscount = _itemDiscountTotals[inv.id] ?? 0;
        if (inv.discountAmount <= 0 && itemDiscount <= 0) return false;
      }
      if (_searchQuery.isNotEmpty) {
        return inv.invoiceNumber.contains(_searchQuery) ||
            _getCustomerName(inv.customerId).contains(_searchQuery);
      }
      return true;
    }).toList()..sort(_compareInvoices);
    if (persist) {
      _storeFilters();
    }
  }

  int _compareInvoices(Invoice left, Invoice right) {
    int comparison;
    switch (_sortField) {
      case 'customer':
        comparison = _getCustomerName(left.customerId).toLowerCase().compareTo(
          _getCustomerName(right.customerId).toLowerCase(),
        );
        break;
      case 'amount':
        final leftBase = CurrencyConversion.toBase(
          left.total,
          currencyCode: left.currencyCode,
          exchangeRate: left.exchangeRate,
        );
        final rightBase = CurrencyConversion.toBase(
          right.total,
          currencyCode: right.currencyCode,
          exchangeRate: right.exchangeRate,
        );
        comparison = leftBase.compareTo(rightBase);
        break;
      case 'date':
      default:
        comparison = left.createdAt.compareTo(right.createdAt);
        break;
    }

    if (comparison == 0) {
      comparison = left.invoiceNumber.compareTo(right.invoiceNumber);
    }

    return _sortAscending ? comparison : -comparison;
  }

  List<String> get _availableCurrencies {
    final codes =
        _invoices.map((invoice) => invoice.currencyCode).toSet().toList()
          ..sort();
    return codes;
  }

  List<String> _activeFilterLabels(AppLocalizations l10n) {
    final labels = <String>[];
    if (_dateFilter != 'all') {
      labels.add(
        '${l10n.date}: ${switch (_dateFilter) {
          'today' => l10n.today,
          'thisWeek' => l10n.thisWeek,
          'thisMonth' => l10n.thisMonth,
          'custom' => l10n.custom,
          _ => l10n.all,
        }}',
      );
    }
    if (_dateFilter == 'custom' &&
        _customFromDate != null &&
        _customToDate != null) {
      labels.add(
        '${l10n.from}: ${DateFormatter.formatDate(_customFromDate!)} ${l10n.to}: ${DateFormatter.formatDate(_customToDate!)}',
      );
    }
    if (_statusFilter != 'all') {
      labels.add('${l10n.status}: ${_getStatusText(_statusFilter)}');
    }
    if (_paymentFilter != 'all') {
      labels.add(
        '${l10n.paymentMethod}: ${switch (_paymentFilter) {
          'cash' => l10n.cash,
          'card' => l10n.card,
          'transfer' => l10n.transfer,
          _ => _paymentFilter,
        }}',
      );
    }
    if (_currencyFilter != 'all') {
      labels.add('${l10n.currency}: $_currencyFilter');
    }
    if (_discountOnly) {
      labels.add(l10n.discount);
    }
    labels.add(
      '${l10n.sortBy}: ${switch (_sortField) {
        'amount' => l10n.amount,
        'customer' => l10n.customer,
        _ => l10n.date,
      }} ${_sortAscending ? l10n.ascending : l10n.descending}',
    );
    return labels;
  }

  List<MapEntry<String, String>> _summaryItems(AppLocalizations l10n) {
    return [
      MapEntry(l10n.invoices, _filtered.length.toString()),
      MapEntry(l10n.amount, _formatDisplayBaseAmount(_filteredTotalBase)),
      MapEntry(l10n.paid, _formatDisplayBaseAmount(_filteredPaidBase)),
      MapEntry(
        l10n.remaining,
        _formatDisplayBaseAmount(_filteredRemainingBase),
      ),
    ];
  }

  Future<void> _exportFilteredInvoices() async {
    final l10n = context.l10n;
    try {
      await InvoiceListExportService.exportPdf(
        InvoiceListExportPayload(
          title: '${l10n.invoices} ${l10n.export} ${l10n.pdf}',
          generatedAt: DateTime.now(),
          generatedAtLabel: l10n.date,
          filtersLabel: l10n.filter,
          totalInvoicesLabel: l10n.invoices,
          invoiceNumberLabel: l10n.invoiceNumber,
          customerLabel: l10n.customer,
          dateLabel: l10n.date,
          amountLabel: l10n.amount,
          paidLabel: l10n.paid,
          remainingLabel: l10n.remaining,
          statusLabel: l10n.status,
          paymentMethodLabel: l10n.paymentMethod,
          currencyLabel: l10n.currency,
          summaryItems: _summaryItems(l10n),
          activeFilters: _activeFilterLabels(l10n),
          rows: _filtered
              .map(
                (invoice) => InvoiceListExportRow(
                  invoiceNumber: invoice.invoiceNumber,
                  customerName: _getCustomerName(invoice.customerId),
                  date: DateFormatter.formatDate(invoice.createdAt),
                  amount: CurrencyFormatter.format(
                    invoice.total,
                    invoice.currencyCode,
                  ),
                  paid: CurrencyFormatter.format(
                    invoice.paidAmount,
                    invoice.currencyCode,
                  ),
                  remaining: CurrencyFormatter.format(
                    invoice.remaining,
                    invoice.currencyCode,
                  ),
                  status: _getStatusText(invoice.status),
                  paymentMethod: switch (invoice.paymentMethod) {
                    'cash' => l10n.cash,
                    'card' => l10n.card,
                    'transfer' => l10n.transfer,
                    _ => invoice.paymentMethod,
                  },
                  currencyCode: invoice.currencyCode,
                ),
              )
              .toList(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invoiceSavedPrintFailed),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _showInvoiceDetails(Invoice invoice) async {
    final db = ref.read(databaseProvider);
    final invoiceItems = await (db.select(
      db.invoiceItems,
    )..where((item) => item.invoiceId.equals(invoice.id))).get();
    final productIds = invoiceItems
        .map((item) => item.productId)
        .toSet()
        .toList();
    final products = productIds.isEmpty
        ? <Product>[]
        : await (db.select(
            db.products,
          )..where((p) => p.id.isIn(productIds))).get();
    final productsById = {for (final product in products) product.id: product};
    final cashier = await (db.select(
      db.users,
    )..where((user) => user.id.equals(invoice.userId))).getSingleOrNull();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _InvoiceDetailsDialog(
        invoice: invoice,
        customerName: _getCustomerName(invoice.customerId),
        items: invoiceItems,
        productsById: productsById,
        cashierName: cashier?.fullName,
        statusText: _getStatusText(invoice.status),
        statusColor: _getStatusColor(invoice.status),
      ),
    );
  }

  Future<void> _pickCustomDate({required bool isFrom}) async {
    final l10n = context.l10n;
    final initialDate = isFrom
        ? (_customFromDate ?? DateTime.now().subtract(const Duration(days: 30)))
        : (_customToDate ?? DateTime.now());
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isFrom ? l10n.from : l10n.to,
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _customFromDate = pickedDate;
        if (_customToDate != null && _customToDate!.isBefore(pickedDate)) {
          _customToDate = pickedDate;
        }
      } else {
        _customToDate = pickedDate;
        if (_customFromDate != null && _customFromDate!.isAfter(pickedDate)) {
          _customFromDate = pickedDate;
        }
      }
      _applyFilter();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'partial':
        return AppColors.warning;
      case 'unpaid':
        return AppColors.error;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  String _getStatusText(String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'paid':
        return l10n.paid;
      case 'partial':
        return l10n.partial;
      case 'unpaid':
        return l10n.unpaid;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.invoices,
            subtitle: '${_filtered.length} ${l10n.invoices}',
            actions: [
              FilledButton.icon(
                onPressed: _filtered.isEmpty ? null : _exportFilteredInvoices,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('${l10n.export} ${l10n.pdf}'),
              ),
            ],
          ),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.saleInvoicesTab),
                Tab(text: l10n.purchaseInvoicesTab),
                Tab(text: l10n.returnsTab),
              ],
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: l10n.invoices,
                    value: _filtered.length.toString(),
                    icon: Icons.receipt_long_outlined,
                    gradient: AppColors.primaryGradient,
                    subtitle: l10n.currentCurrencyLabel(_displayCurrencyCode),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: l10n.amount,
                    value: _formatDisplayBaseAmount(_filteredTotalBase),
                    icon: Icons.payments_outlined,
                    gradient: AppColors.accentGradient,
                    subtitle: l10n.currentCurrencyLabel(_displayCurrencyCode),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: l10n.paid,
                    value: _formatDisplayBaseAmount(_filteredPaidBase),
                    icon: Icons.check_circle_outline,
                    gradient: AppColors.successGradient,
                    subtitle: l10n.currentCurrencyLabel(_displayCurrencyCode),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: l10n.remaining,
                    value: _formatDisplayBaseAmount(_filteredRemainingBase),
                    icon: Icons.pending_outlined,
                    gradient: AppColors.warningGradient,
                    subtitle: l10n.currentCurrencyLabel(_displayCurrencyCode),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SearchField(
                        controller: _searchController,
                        hintText: l10n.searchByInvoiceNumberCustomer,
                        onChanged: (v) {
                          setState(() {
                            _searchQuery = v;
                            _applyFilter();
                          });
                        },
                        onClear: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDateFilter(isDark),
                    if (_dateFilter == 'custom') ...[
                      _buildCustomDateButton(isDark, isFrom: true),
                      _buildCustomDateButton(isDark, isFrom: false),
                    ],
                    ..._buildStatusFilters(isDark),
                    _buildPaymentFilter(isDark),
                    _buildCurrencyFilter(isDark),
                    _buildSortFieldFilter(isDark),
                    _buildSortDirectionFilter(isDark),
                    if (_hasActiveFilters)
                      OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 16,
                        ),
                        label: Text(l10n.clearFilters),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    FilterChip(
                      label: Text(l10n.discount),
                      selected: _discountOnly,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: _discountOnly ? Colors.white : null,
                      ),
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          _discountOnly = selected;
                          _applyFilter();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Table
          Expanded(
            child: _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noInvoices,
                    subtitle: l10n.invoicesWillAppearAfterOperations,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightBg,
                              ),
                              columns: [
                                DataColumn(label: Text(l10n.invoiceNumber)),
                                DataColumn(label: Text(l10n.customer)),
                                DataColumn(label: Text(l10n.date)),
                                DataColumn(label: Text(l10n.currency)),
                                DataColumn(label: Text(l10n.amount)),
                                DataColumn(label: Text(l10n.paid)),
                                DataColumn(label: Text(l10n.remaining)),
                                DataColumn(label: Text(l10n.discount)),
                                DataColumn(label: Text(l10n.status)),
                                DataColumn(label: Text(l10n.invoicePayment)),
                              ],
                              rows: _filtered.map((inv) {
                                return DataRow(
                                  onSelectChanged: (_) =>
                                      _showInvoiceDetails(inv),
                                  cells: [
                                    DataCell(
                                      Text(
                                        inv.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _getCustomerName(inv.customerId),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        DateFormatter.formatDate(inv.createdAt),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        inv.currencyCode,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        CurrencyFormatter.format(
                                          inv.total,
                                          inv.currencyCode,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        CurrencyFormatter.format(
                                          inv.paidAmount,
                                          inv.currencyCode,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        CurrencyFormatter.format(
                                          inv.remaining,
                                          inv.currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: inv.remaining > 0
                                              ? AppColors.error
                                              : AppColors.success,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _totalDiscountFor(inv) > 0
                                            ? CurrencyFormatter.format(
                                                _totalDiscountFor(inv),
                                                inv.currencyCode,
                                              )
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _totalDiscountFor(inv) > 0
                                              ? AppColors.warning
                                              : (isDark
                                                    ? AppColors
                                                          .darkTextSecondary
                                                    : AppColors
                                                          .lightTextSecondary),
                                          fontWeight: _totalDiscountFor(inv) > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            inv.status,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusText(inv.status),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(inv.status),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(switch (inv.paymentMethod) {
                                        'cash' => l10n.cash,
                                        'card' => l10n.card,
                                        'transfer' => l10n.transfer,
                                        _ => inv.paymentMethod,
                                      }, style: const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildStatusFilters(bool isDark) {
    final l10n = context.l10n;
    return [
      _buildStatusChip(l10n.all, 'all', isDark),
      const SizedBox(width: 6),
      _buildStatusChip(l10n.paid, 'paid', isDark),
      const SizedBox(width: 6),
      _buildStatusChip(l10n.partial, 'partial', isDark),
      const SizedBox(width: 6),
      _buildStatusChip(l10n.unpaid, 'unpaid', isDark),
    ];
  }

  Widget _buildPaymentFilter(bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paymentFilter,
          borderRadius: BorderRadius.circular(10),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('${l10n.paymentMethod}: ${l10n.all}'),
            ),
            DropdownMenuItem(
              value: 'cash',
              child: Text('${l10n.paymentMethod}: ${l10n.cash}'),
            ),
            DropdownMenuItem(
              value: 'card',
              child: Text('${l10n.paymentMethod}: ${l10n.card}'),
            ),
            DropdownMenuItem(
              value: 'transfer',
              child: Text('${l10n.paymentMethod}: ${l10n.transfer}'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _paymentFilter = value;
              _applyFilter();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateFilter(bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _dateFilter,
          borderRadius: BorderRadius.circular(10),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('${l10n.date}: ${l10n.all}'),
            ),
            DropdownMenuItem(
              value: 'today',
              child: Text('${l10n.date}: ${l10n.today}'),
            ),
            DropdownMenuItem(
              value: 'thisWeek',
              child: Text('${l10n.date}: ${l10n.thisWeek}'),
            ),
            DropdownMenuItem(
              value: 'thisMonth',
              child: Text('${l10n.date}: ${l10n.thisMonth}'),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text('${l10n.date}: ${l10n.custom}'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _dateFilter = value;
              if (_dateFilter == 'custom') {
                _customToDate ??= DateTime.now();
                _customFromDate ??= DateTime.now().subtract(
                  const Duration(days: 30),
                );
              }
              _applyFilter();
            });
          },
        ),
      ),
    );
  }

  Widget _buildCustomDateButton(bool isDark, {required bool isFrom}) {
    final l10n = context.l10n;
    final selectedDate = isFrom ? _customFromDate : _customToDate;
    final label = isFrom ? l10n.from : l10n.to;

    return OutlinedButton.icon(
      onPressed: () => _pickCustomDate(isFrom: isFrom),
      icon: const Icon(Icons.date_range_outlined, size: 16),
      label: Text(
        '$label: ${selectedDate == null ? '-' : DateFormatter.formatDate(selectedDate)}',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildCurrencyFilter(bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currencyFilter,
          borderRadius: BorderRadius.circular(10),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('${l10n.currency}: ${l10n.all}'),
            ),
            ..._availableCurrencies.map(
              (code) => DropdownMenuItem(
                value: code,
                child: Text('${l10n.currency}: $code'),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _currencyFilter = value;
              _applyFilter();
            });
          },
        ),
      ),
    );
  }

  Widget _buildSortFieldFilter(bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortField,
          borderRadius: BorderRadius.circular(10),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: 'date',
              child: Text('${l10n.sortBy}: ${l10n.date}'),
            ),
            DropdownMenuItem(
              value: 'amount',
              child: Text('${l10n.sortBy}: ${l10n.amount}'),
            ),
            DropdownMenuItem(
              value: 'customer',
              child: Text('${l10n.sortBy}: ${l10n.customer}'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _sortField = value;
              _applyFilter();
            });
          },
        ),
      ),
    );
  }

  Widget _buildSortDirectionFilter(bool isDark) {
    final l10n = context.l10n;
    return FilterChip(
      label: Text(_sortAscending ? l10n.ascending : l10n.descending),
      selected: _sortAscending,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 11,
        color: _sortAscending ? Colors.white : null,
      ),
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      onSelected: (selected) {
        setState(() {
          _sortAscending = selected;
          _applyFilter();
        });
      },
    );
  }

  Widget _buildStatusChip(String label, String value, bool isDark) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      visualDensity: VisualDensity.compact,
      onSelected: (v) {
        setState(() {
          _statusFilter = v ? value : 'all';
          _applyFilter();
        });
      },
    );
  }
}

class _InvoiceFilterState {
  const _InvoiceFilterState({
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.paymentFilter = 'all',
    this.currencyFilter = 'all',
    this.dateFilter = 'all',
    this.customFromDate,
    this.customToDate,
    this.discountOnly = false,
    this.sortField = 'date',
    this.sortAscending = false,
  });

  final String searchQuery;
  final String statusFilter;
  final String paymentFilter;
  final String currencyFilter;
  final String dateFilter;
  final DateTime? customFromDate;
  final DateTime? customToDate;
  final bool discountOnly;
  final String sortField;
  final bool sortAscending;
}

class _InvoiceDetailsDialog extends StatelessWidget {
  const _InvoiceDetailsDialog({
    required this.invoice,
    required this.customerName,
    required this.items,
    required this.productsById,
    required this.cashierName,
    required this.statusText,
    required this.statusColor,
  });

  final Invoice invoice;
  final String customerName;
  final List<InvoiceItem> items;
  final Map<int, Product> productsById;
  final String? cashierName;
  final String statusText;
  final Color statusColor;

  double get _grossSubtotal =>
      items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  double get _itemDiscountTotal =>
      items.fold(0.0, (sum, item) => sum + item.discount);

  String _formatAmount(double amount) {
    return CurrencyFormatter.format(amount, invoice.currencyCode);
  }

  String _localizedPaymentMethod(AppLocalizations l10n) {
    return switch (invoice.paymentMethod) {
      'cash' => l10n.cash,
      'card' => l10n.card,
      'transfer' => l10n.transfer,
      _ => invoice.paymentMethod,
    };
  }

  Future<void> _printInvoice(BuildContext context) async {
    final l10n = context.l10n;

    try {
      await InvoicePrintService.printInvoice(
        InvoicePrintPayload(
          labels: InvoicePrintLabels(
            saleInvoiceTitle: l10n.saleInvoice,
            invoiceNumberLabel: l10n.invoiceNumber,
            dateLabel: l10n.date,
            customerLabel: l10n.customer,
            cashierLabel: l10n.cashier,
            paymentLabel: l10n.payment,
            currencyLabel: l10n.currency,
            nameLabel: l10n.name,
            quantityLabel: l10n.quantity,
            unitPriceLabel: l10n.unitPrice,
            discountLabel: l10n.discount,
            subtotalLabel: l10n.subtotal,
            itemDiscountsLabel: l10n.itemDiscountsLabel,
            invoiceDiscountSummaryLabel: l10n.invoiceDiscountLabel,
            totalLabel: l10n.total,
            walkInCustomerLabel: l10n.walkInCustomer,
          ),
          invoiceNumber: invoice.invoiceNumber,
          createdAt: invoice.createdAt,
          paymentMethod: _localizedPaymentMethod(l10n),
          currencyCode: invoice.currencyCode,
          subtotal: _grossSubtotal,
          itemDiscountAmount: _itemDiscountTotal,
          discountAmount: invoice.discountAmount,
          total: invoice.total,
          items: items
              .map(
                (item) => InvoicePrintItem(
                  name: productsById[item.productId]?.nameAr ?? l10n.unknown,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  discount: item.discount,
                  total: item.total,
                  barcode: productsById[item.productId]?.barcode,
                ),
              )
              .toList(),
          customerName: customerName,
          cashierName: cashierName,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.invoiceSavedPrintFailed),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 760),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.invoiceNumber}: ${invoice.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.date}: ${DateFormatter.formatDateTime(invoice.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoCard(
                  label: l10n.customer,
                  value: customerName,
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.invoicePayment,
                  value: _localizedPaymentMethod(l10n),
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.cashier,
                  value: cashierName ?? '-',
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.currency,
                  value: invoice.currencyCode,
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.exchangeRate,
                  value: invoice.exchangeRate.toStringAsFixed(2),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.items,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noData,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final product = productsById[item.productId];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product?.nameAr ?? l10n.unknown,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    if ((product?.barcode?.isNotEmpty ?? false))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          product!.barcode!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${l10n.quantity}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatAmount(item.unitPrice),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.discount > 0
                                      ? _formatAmount(item.discount)
                                      : '-',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatAmount(item.total),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 280,
                child: Column(
                  children: [
                    _SummaryRow(
                      label: l10n.subtotal,
                      value: _formatAmount(_grossSubtotal),
                      isDark: isDark,
                    ),
                    if (_itemDiscountTotal > 0)
                      _SummaryRow(
                        label: l10n.itemDiscountsLabel,
                        value: '- ${_formatAmount(_itemDiscountTotal)}',
                        isDark: isDark,
                        color: AppColors.error,
                      ),
                    if (invoice.discountAmount > 0)
                      _SummaryRow(
                        label: l10n.invoiceDiscountLabel,
                        value: '- ${_formatAmount(invoice.discountAmount)}',
                        isDark: isDark,
                        color: AppColors.error,
                      ),
                    const Divider(height: 22),
                    _SummaryRow(
                      label: l10n.total,
                      value: _formatAmount(invoice.total),
                      isDark: isDark,
                      color: AppColors.primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _printInvoice(context),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(l10n.print),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
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
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: FontWeight.w700,
                color:
                    color ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
