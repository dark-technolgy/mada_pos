import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/invoice_list_export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/database/database.dart';
import '../../../core/services/company_profile_service.dart';
import '../application/invoice_list_filter_state.dart';
import '../application/invoice_list_service.dart';
import '../application/invoice_void_service.dart';
import '../application/invoices_screen_service.dart';
import 'widgets/invoice_details_dialog.dart';
import 'widgets/invoices_sections.dart';
import 'widgets/purchase_return_dialog.dart';
import 'widgets/sale_return_dialog.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/page_header.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  static const _filtersSettingKey = 'invoices_last_filters';
  static const _filterPersistDelay = Duration(milliseconds: 150);
  static const _defaultFilterState = InvoiceListFilterState.defaults;

  late TabController _tabController;
  late final TextEditingController _searchController;
  final InvoiceListService _invoiceListService = const InvoiceListService();
  final InvoicesScreenService _screenService = const InvoicesScreenService();
  final InvoiceVoidService _voidService = const InvoiceVoidService();
  Timer? _persistFiltersTimer;
  Future<void> _persistFiltersTask = Future.value();
  List<Invoice> _invoices = [];
  List<Invoice> _filtered = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
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

  InvoiceStatusTextLabels get _statusLabels {
    final l10n = context.l10n;
    return InvoiceStatusTextLabels(
      paid: l10n.paid,
      partial: l10n.partial,
      unpaid: l10n.unpaid,
      cancelled: l10n.cancelled,
    );
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingGlobalSearch());
  }

  void _applyPendingGlobalSearch() {
    final pending = ref.read(pendingInvoiceSearchProvider);
    if (pending == null || pending.isEmpty) return;
    ref.read(pendingInvoiceSearchProvider.notifier).state = null;
    _searchController.text = pending;
    setState(() {
      _searchQuery = pending;
    });
    _applyFilter(persist: true);
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
    final result = await _invoiceListService.loadScreenData(
      db,
      filtersSettingKey: _filtersSettingKey,
    );
    final restoredFilterState = result.restoredFilterState;
    _searchController.text = restoredFilterState.searchQuery;

    setState(() {
      _invoices = result.invoices;
      _customers = result.customers;
      _suppliers = result.suppliers;
      _itemDiscountTotals = result.itemDiscountTotals;
      _currencyMap = result.currencyMap;
      _displayCurrencyCode = result.displayCurrencyCode;
      _displayExchangeRate = result.displayExchangeRate;
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

  InvoiceListFilterState get _currentFilterState {
    return InvoiceListFilterState(
      searchQuery: _searchQuery,
      statusFilter: _statusFilter,
      paymentFilter: _paymentFilter,
      currencyFilter: _currencyFilter,
      dateFilter: _dateFilter,
      customFromDate: _customFromDate,
      customToDate: _customToDate,
      discountOnly: _discountOnly,
      sortField: _sortField,
      sortAscending: _sortAscending,
    );
  }

  Future<void> _persistFilterState() async {
    if (!mounted) return;

    final db = ref.read(databaseProvider);
    await _invoiceListService.persistFilterState(
      db,
      filtersSettingKey: _filtersSettingKey,
      filterState: _currentFilterState,
    );
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
    return _currentFilterState.hasActiveFilters;
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

  InvoiceSummaryMetrics get _summaryMetrics =>
      _screenService.calculateSummary(_filtered);

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
    return _screenService.customerNameFor(
      customerId: customerId,
      customers: _customers,
      cashCustomerLabel: l10n.cashCustomer,
      unknownLabel: l10n.unknown,
    );
  }

  String _counterpartyName(Invoice invoice) {
    final l10n = context.l10n;
    switch (invoice.type) {
      case 'purchase':
      case 'purchase_return':
        if (invoice.supplierId == null) return l10n.supplierNotSpecified;
        final supplier = _suppliers
            .where((s) => s.id == invoice.supplierId)
            .firstOrNull;
        return supplier?.name ?? l10n.unknown;
      default:
        return _getCustomerName(invoice.customerId);
    }
  }

  double _totalDiscountFor(Invoice invoice) {
    return _screenService.totalDiscountFor(invoice, _itemDiscountTotals);
  }

  void _applyFilter({bool persist = true}) {
    _filtered = _invoiceListService.filterInvoices(
      invoices: _invoices,
      tabIndex: _tabController.index,
      filterState: _currentFilterState,
      itemDiscountTotals: _itemDiscountTotals,
      counterpartyNameResolver: _counterpartyName,
    );
    if (persist) {
      _storeFilters();
    }
  }

  List<String> get _availableCurrencies {
    return _invoiceListService.availableCurrencies(_invoices);
  }

  List<String> _activeFilterLabels(AppLocalizations l10n) {
    return _screenService.activeFilterLabels(
      filterState: _currentFilterState,
      labels: InvoiceActiveFilterLabels(
        date: l10n.date,
        today: l10n.today,
        thisWeek: l10n.thisWeek,
        thisMonth: l10n.thisMonth,
        custom: l10n.custom,
        all: l10n.all,
        from: l10n.from,
        to: l10n.to,
        status: l10n.status,
        paymentMethod: l10n.paymentMethod,
        cash: l10n.cash,
        card: l10n.card,
        transfer: l10n.transfer,
        currency: l10n.currency,
        discount: l10n.discount,
        sortBy: l10n.sortBy,
        amount: l10n.amount,
        customer: l10n.customer,
        ascending: l10n.ascending,
        descending: l10n.descending,
      ),
      statusLabels: _statusLabels,
    );
  }

  List<MapEntry<String, String>> _summaryItems(AppLocalizations l10n) {
    return [
      MapEntry(l10n.invoices, _summaryMetrics.count.toString()),
      MapEntry(
        l10n.amount,
        _formatDisplayBaseAmount(_summaryMetrics.totalBase),
      ),
      MapEntry(l10n.paid, _formatDisplayBaseAmount(_summaryMetrics.paidBase)),
      MapEntry(
        l10n.remaining,
        _formatDisplayBaseAmount(_summaryMetrics.remainingBase),
      ),
    ];
  }

  Future<void> _exportFilteredInvoicesExcel() async {
    final l10n = context.l10n;
    try {
      final path = await ExcelExportService.exportSheet(
        suggestedFileName: 'invoices_${DateTime.now().millisecondsSinceEpoch}',
        sheetData: ExcelSheetData(
          sheetName: l10n.invoices,
          headers: [
            l10n.invoiceNumber,
            l10n.customer,
            l10n.date,
            l10n.amount,
            l10n.paid,
            l10n.remaining,
            l10n.status,
            l10n.paymentMethod,
            l10n.currency,
            l10n.tax,
          ],
          rows: _filtered
              .map(
                (invoice) => [
                  invoice.invoiceNumber,
                  _counterpartyName(invoice),
                  DateFormatter.formatDate(invoice.createdAt),
                  invoice.total.toString(),
                  invoice.paidAmount.toString(),
                  invoice.remaining.toString(),
                  _getStatusText(invoice.status),
                  invoice.paymentMethod,
                  invoice.currencyCode,
                  invoice.taxAmount.toString(),
                ],
              )
              .toList(),
        ),
      );
      if (!mounted) return;
      if (path != null) {
        AppFeedback.success(context, l10n.exportedTo(path));
      }
    } catch (e, st) {
      await AppLogger.record('Invoice print', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.warning(context, l10n.invoiceSavedPrintFailed);
    }
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
                  customerName: _counterpartyName(invoice),
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
    } catch (e, st) {
      await AppLogger.record('Invoice print', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.warning(context, l10n.invoiceSavedPrintFailed);
    }
  }

  Future<void> _showInvoiceDetails(Invoice invoice) async {
    final db = ref.read(databaseProvider);
    final details = await _screenService.loadInvoiceDetails(db, invoice);

    if (!mounted) return;

    final l10n = context.l10n;
    final session = ref.read(sessionManagerProvider);
    final canSaleReturn = invoice.type == 'sale' &&
        !invoice.isHeld &&
        invoice.status != 'draft' &&
        invoice.status != 'cancelled' &&
        session.hasPermission('create_invoice');
    final canPurchaseReturn = invoice.type == 'purchase' &&
        invoice.status != 'draft' &&
        invoice.status != 'cancelled' &&
        session.hasPermission('create_invoice');
    final canVoid = (invoice.type == 'sale' || invoice.type == 'purchase') &&
        !invoice.isHeld &&
        invoice.status != 'draft' &&
        invoice.status != 'cancelled' &&
        session.hasPermission('void_invoice');

    final isPurchase = invoice.type == 'purchase';
    final user = ref.read(currentUserProvider);
    final company = await const CompanyProfileService().load(db);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => InvoiceDetailsDialog(
        invoice: invoice,
        counterpartyLabel: isPurchase ? l10n.supplier : l10n.customer,
        counterpartyName: _counterpartyName(invoice),
        items: details.items,
        productsById: details.productsById,
        cashierName: details.cashierName,
        statusText: _getStatusText(invoice.status),
        statusColor: _getStatusColor(invoice.status),
        printInvoiceTitle:
            isPurchase ? l10n.purchaseInvoice : l10n.saleInvoice,
        companyName: company.name,
        companyPhone: company.phone,
        companyAddress: company.address,
        companyLogoPath: company.logoPath,
        showSaleReturn: canSaleReturn,
        onSaleReturn: () async {
          final ok = await showDialog<bool>(
            context: dialogContext,
            builder: (ctx) => SaleReturnDialog(
              invoice: invoice,
              items: details.items,
              productsById: details.productsById,
            ),
          );
          if (ok == true && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
            await _loadData();
          }
        },
        showPurchaseReturn: canPurchaseReturn,
        onPurchaseReturn: () async {
          final ok = await showDialog<bool>(
            context: dialogContext,
            builder: (ctx) => PurchaseReturnDialog(
              invoice: invoice,
              items: details.items,
              productsById: details.productsById,
            ),
          );
          if (ok == true && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
            await _loadData();
          }
        },
        showVoid: canVoid,
        onVoid: user == null
            ? null
            : () async {
                final confirmed = await ConfirmationDialog.show(
                  dialogContext,
                  title: l10n.voidInvoiceTitle,
                  message: l10n.voidInvoiceMessage,
                  confirmText: l10n.voidInvoice,
                );
                if (!confirmed || !dialogContext.mounted) return;

                final db = ref.read(databaseProvider);
                try {
                  await _voidService.voidInvoice(
                    db,
                    invoice: invoice,
                    user: user,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  AppFeedback.success(dialogContext, l10n.voidInvoiceSuccess);
                  await _loadData();
                } on InvoiceVoidException catch (e) {
                  if (!dialogContext.mounted) return;
                  AppFeedback.error(
                    dialogContext,
                    _voidErrorMessage(l10n, e.message),
                  );
                }
              },
      ),
    );
  }

  String _voidErrorMessage(AppLocalizations l10n, String code) {
    return switch (code) {
      'already-cancelled' => l10n.cannotVoidInvoice,
      'draft-or-held' => l10n.cannotVoidInvoice,
      'return-invoice' => l10n.cannotVoidInvoice,
      'has-returns' => l10n.cannotVoidInvoice,
      'insufficient-stock' => l10n.cannotVoidInvoice,
      'no-warehouse' => l10n.cannotVoidInvoice,
      _ => l10n.cannotVoidInvoice,
    };
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
    return _screenService.statusText(status, _statusLabels);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final canRecordPurchase =
        ref.watch(sessionManagerProvider).hasPermission('create_invoice');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.invoices,
            subtitle: '${_filtered.length} ${l10n.invoices}',
            actions: [
              if (canRecordPurchase && _tabController.index == 1)
                OutlinedButton.icon(
                  onPressed: () async {
                    final saved =
                        await context.push<bool>('/invoices/purchase/new');
                    if (!mounted) return;
                    if (saved == true) await _loadData();
                  },
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(l10n.newPurchaseInvoice),
                ),
              OutlinedButton.icon(
                onPressed:
                    _filtered.isEmpty ? null : _exportFilteredInvoicesExcel,
                icon: const Icon(Icons.table_chart_outlined),
                label: Text('${l10n.export} ${l10n.excel}'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _filtered.isEmpty ? null : _exportFilteredInvoices,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('${l10n.export} ${l10n.pdf}'),
              ),
            ],
          ),
          InvoicesTabsSection(
            controller: _tabController,
            isDark: isDark,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          InvoicesSummarySection(
            l10n: l10n,
            filteredCount: _summaryMetrics.count,
            totalAmount: _formatDisplayBaseAmount(_summaryMetrics.totalBase),
            paidAmount: _formatDisplayBaseAmount(_summaryMetrics.paidBase),
            remainingAmount: _formatDisplayBaseAmount(
              _summaryMetrics.remainingBase,
            ),
            displayCurrencyCode: _displayCurrencyCode,
          ),
          const SizedBox(height: 8),
          InvoicesQuickFiltersSection(
            l10n: l10n,
            dateFilter: _dateFilter,
            statusFilter: _statusFilter,
            onToday: () {
              setState(() {
                _dateFilter = 'today';
                _applyFilter();
              });
            },
            onThisWeek: () {
              setState(() {
                _dateFilter = 'thisWeek';
                _applyFilter();
              });
            },
            onUnpaid: () {
              setState(() {
                _statusFilter = _statusFilter == 'unpaid' ? 'all' : 'unpaid';
                _applyFilter();
              });
            },
            onPartial: () {
              setState(() {
                _statusFilter = _statusFilter == 'partial' ? 'all' : 'partial';
                _applyFilter();
              });
            },
          ),
          InvoicesFiltersSection(
            l10n: l10n,
            isDark: isDark,
            searchController: _searchController,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilter();
              });
            },
            onSearchCleared: () {
              setState(() {
                _searchQuery = '';
                _applyFilter();
              });
            },
            dateFilter: _dateFilter,
            onDateFilterChanged: (value) {
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
            customFromDateLabel:
                '${l10n.from}: ${_customFromDate == null ? '-' : DateFormatter.formatDate(_customFromDate!)}',
            customToDateLabel:
                '${l10n.to}: ${_customToDate == null ? '-' : DateFormatter.formatDate(_customToDate!)}',
            onPickFromDate: () => _pickCustomDate(isFrom: true),
            onPickToDate: () => _pickCustomDate(isFrom: false),
            statusFilter: _statusFilter,
            onStatusFilterChanged: (value) {
              setState(() {
                _statusFilter = value;
                _applyFilter();
              });
            },
            paymentFilter: _paymentFilter,
            onPaymentFilterChanged: (value) {
              setState(() {
                _paymentFilter = value;
                _applyFilter();
              });
            },
            currencyFilter: _currencyFilter,
            availableCurrencies: _availableCurrencies,
            onCurrencyFilterChanged: (value) {
              setState(() {
                _currencyFilter = value;
                _applyFilter();
              });
            },
            sortField: _sortField,
            onSortFieldChanged: (value) {
              setState(() {
                _sortField = value;
                _applyFilter();
              });
            },
            sortAscending: _sortAscending,
            onSortDirectionChanged: (selected) {
              setState(() {
                _sortAscending = selected;
                _applyFilter();
              });
            },
            hasActiveFilters: _hasActiveFilters,
            onClearFilters: _clearFilters,
            discountOnly: _discountOnly,
            onDiscountOnlyChanged: (selected) {
              setState(() {
                _discountOnly = selected;
                _applyFilter();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: InvoicesTableSection(
              l10n: l10n,
              isDark: isDark,
              invoices: _filtered,
              customerNameFor: _counterpartyName,
              totalDiscountFor: _totalDiscountFor,
              statusTextFor: _getStatusText,
              statusColorFor: _getStatusColor,
              onInvoiceSelected: _showInvoiceDetails,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
