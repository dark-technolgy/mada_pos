import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/company_profile_service.dart';
import '../../../core/services/invoice_print_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
import '../application/pos_sale_service.dart';
import '../application/pos_screen_service.dart';
import '../application/pos_smart_service.dart';
import '../application/pos_sale_guard_service.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_payment_split.dart';
import '../domain/pos_sale_draft.dart';
import 'widgets/split_payment_dialog.dart';
import '../../../core/utils/tax_settings.dart';
import '../domain/pos_pricing.dart';
import '../../cash_register/application/cash_register_service.dart';
import 'widgets/barcode_scanner_scope.dart';
import 'widgets/pos_dialogs.dart';
import 'widgets/pos_keyboard_help.dart';
import 'widgets/pos_sections.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class _CompleteSaleIntent extends Intent {
  const _CompleteSaleIntent();
}

class _OpenSplitPaymentIntent extends Intent {
  const _OpenSplitPaymentIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _FocusBarcodeIntent extends Intent {
  const _FocusBarcodeIntent();
}

class _ClearCartIntent extends Intent {
  const _ClearCartIntent();
}

class _HoldInvoiceIntent extends Intent {
  const _HoldInvoiceIntent();
}

class _RecallInvoiceIntent extends Intent {
  const _RecallInvoiceIntent();
}

class _ShowKeyboardHelpIntent extends Intent {
  const _ShowKeyboardHelpIntent();
}

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _discountController = TextEditingController();
  final _searchFocus = FocusNode();
  final _barcodeFocus = FocusNode();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  List<Currency> _currencies = [];
  int? _selectedCategoryId;
  PosSaleDraft _draft = const PosSaleDraft();
  final PosScreenService _screenService = const PosScreenService();
  final PosSmartService _smartService = const PosSmartService();
  final PosSaleGuardService _saleGuardService = const PosSaleGuardService();
  Map<int, List<int>> _pairsByProduct = {};
  List<Product> _smartSuggestions = [];
  List<Product> _topSellers = [];
  Map<int, double> _stockByProductId = {};

  PosSaleService get _saleService => PosSaleService(ref.read(databaseProvider));
  List<PosCartItem> get _cart => _draft.cart;
  Customer? get _selectedCustomer => _draft.selectedCustomer;
  double get _invoiceDiscount => _draft.invoiceDiscount;
  String get _discountType => _draft.discountType;
  String get _paymentMethod => _draft.paymentMethod;
  String get _currencyCode => _draft.currencyCode;
  double get _exchangeRate => _draft.exchangeRate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    _searchFocus.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await const CashRegisterService().ensureActiveShift(db, userId: user.id);
    }

    final result = await _screenService.loadScreenData(db);
    final taxSettings = await TaxSettingsLoader.load(db);
    final pairs = await _smartService.loadFrequentlyBoughtTogether(db);
    final stock = await _smartService.loadStockTotals(db);
    final topIds = await _smartService.loadTopSellerProductIds(db);

    if (!mounted) return;
    setState(() {
      _products = result.products;
      _filteredProducts = result.products;
      _categories = result.categories;
      _currencies = result.currencies;
      _pairsByProduct = pairs;
      _stockByProductId = stock;
      _topSellers = _smartService.productsFromIds(topIds, result.products);
      _draft = _draft.copyWith(
        currencyCode: result.defaultCurrencyCode,
        exchangeRate: result.defaultExchangeRate,
        taxSettings: taxSettings,
      );
    });
    _refreshSmartSuggestions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barcodeFocus.requestFocus();
    });
  }

  double _fromBaseAmount(
    double amount, {
    String? currencyCode,
    double? exchangeRate,
  }) {
    return CurrencyConversion.fromBase(
      amount,
      currencyCode: currencyCode ?? _currencyCode,
      exchangeRate: exchangeRate ?? _exchangeRate,
    );
  }

  String _formatCurrency(double amount, {String? currencyCode}) {
    final code = currencyCode ?? _currencyCode;
    final currency = _currencies.where((item) => item.code == code).firstOrNull;
    if (currency != null) {
      return CurrencyFormatter.formatCurrency(amount, currency);
    }
    return CurrencyFormatter.format(amount, code);
  }

  String _formatEditableNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  void _applyCurrencySelection(String currencyCode) {
    final currency = _currencies
        .where((item) => item.code == currencyCode)
        .firstOrNull;
    if (currency == null || currency.code == _currencyCode) return;

    final nextExchangeRate = CurrencyConversion.normalizeRate(
      currency.code,
      currency.exchangeRate,
    );

    setState(() {
      _draft = _draft.updateCurrency(
        currencyCode: currency.code,
        exchangeRate: nextExchangeRate,
      );
      if (_discountType == 'fixed' && _invoiceDiscount > 0) {
        _discountController.text = _formatEditableNumber(_invoiceDiscount);
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _screenService.filterProducts(
        products: _products,
        query: query,
        selectedCategoryId: _selectedCategoryId,
      );
    });
  }

  void _refreshSmartSuggestions() {
    final cartIds = _cart.map((item) => item.product.id).toList();
    _smartSuggestions = _smartService.suggestionsForCart(
      pairsByProduct: _pairsByProduct,
      cartProductIds: cartIds,
      allProducts: _products,
    );
  }

  double _cartQtyForProduct(int productId) {
    return _cart
        .where((item) => item.product.id == productId)
        .fold<double>(0, (sum, item) => sum + item.quantity);
  }

  double _availableStock(int productId) => _stockByProductId[productId] ?? 0;

  bool _checkStockForAdd(Product product, double requestedQty) {
    final l10n = context.l10n;
    final available = _availableStock(product.id);
    final inCart = _cartQtyForProduct(product.id);
    final totalNeeded = inCart + requestedQty;

    if (available <= 0) {
      AppFeedback.error(context, '${l10n.outOfStock}: ${product.nameAr}');
      return false;
    }

    if (totalNeeded > available) {
      final availStr = _formatEditableNumber(available);
      final reqStr = _formatEditableNumber(totalNeeded);
      AppFeedback.warning(
        context,
        l10n.insufficientStockMessage(product.nameAr, availStr, reqStr),
      );
      return false;
    }
    return true;
  }

  Future<void> _addToCart(Product product) async {
    if (!_checkStockForAdd(product, 1)) return;
    double base = product.sellingPrice;
    if (!mounted) return;
    setState(() {
      _draft = _draft.addProduct(product, baseUnitPrice: base);
      _refreshSmartSuggestions();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _draft = _draft.removeCartItemAt(index);
      _refreshSmartSuggestions();
    });
  }

  void _updateCartItemQuantity(int index, double qty) {
    if (qty <= 0) return;
    final item = _cart[index];
    final delta = qty - item.quantity;
    if (delta > 0 && !_checkStockForAdd(item.product, delta)) return;
    setState(() {
      _draft = _draft.updateCartItemQuantity(index, qty);
    });
  }

  void _updateCartItemDiscount(int index, double discountAmount) {
    setState(() {
      _draft = _draft.updateCartItemDiscount(index, discountAmount);
    });
  }

  Future<void> _editCartItemDiscount(int index) async {
    final l10n = context.l10n;
    final item = _cart[index];
    final product = item.product;
    final quantity = item.quantity;
    final unitPrice = item.unitPrice;
    final grossTotal = quantity * unitPrice;
    final currentDiscount = item.discount;
    final discountCtrl = TextEditingController(
      text: currentDiscount == 0 ? '' : _formatEditableNumber(currentDiscount),
    );
    var selectedType = 'fixed';

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameAr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.subtotal}: ${_formatCurrency(grossTotal)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.discount,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => selectedType = 'fixed'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType == 'fixed'
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedType == 'fixed'
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                              ),
                            ),
                            child: Text(
                              l10n.fixedAmount,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selectedType == 'fixed'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selectedType == 'fixed'
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => selectedType = 'percentage'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedType == 'percentage'
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedType == 'percentage'
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                              ),
                            ),
                            child: Text(
                              l10n.percentage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selectedType == 'percentage'
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selectedType == 'percentage'
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 0.0),
                        child: Text(l10n.clearDiscount),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final rawValue = double.tryParse(
                            discountCtrl.text.trim(),
                          );
                          if (rawValue == null || rawValue < 0) {
                            AppFeedback.error(context, l10n.invalidAmount);
                            return;
                          }

                          final discountAmount = _screenService
                              .discountAmountFor(
                                grossTotal: grossTotal,
                                rawValue: rawValue,
                                discountType: selectedType,
                              );
                          Navigator.pop(context, discountAmount);
                        },
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      _updateCartItemDiscount(index, result);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      discountCtrl.dispose();
    });
  }

  PosPricingSummary get _pricingSummary => _draft.pricingSummary;

  double get _grossSubtotal => _draft.grossSubtotal;

  double get _lineDiscountTotal => _draft.lineDiscountTotal;

  double get _discountAmount => _draft.discountAmount;

  double get _taxAmount => _draft.pricingSummary.taxAmount;

  double get _total => _draft.total;

  void _syncDiscountController() {
    if (_invoiceDiscount <= 0) {
      _discountController.clear();
      return;
    }
    _discountController.text = _formatEditableNumber(_invoiceDiscount);
  }

  Future<void> _holdCurrentInvoice() async {
    if (_cart.isEmpty) return;

    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final invoiceNumber = await _saleService.holdSale(
      user: user,
      cart: _cart,
      customer: _selectedCustomer,
      summary: _pricingSummary,
      invoiceDiscount: _invoiceDiscount,
      discountType: _discountType,
      paymentMethod: _paymentMethod,
      currencyCode: _currencyCode,
      exchangeRate: _exchangeRate,
    );

    if (!mounted) return;

    setState(() {
      _draft = _draft.resetAfterHold();
      _discountController.clear();
    });

    AppFeedback.warning(
      context,
      '${l10n.invoiceHeldSuccessfully} - $invoiceNumber',
    );
  }

  Future<void> _recallHeldInvoice() async {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_cart.isNotEmpty) {
      final shouldReplace = await ConfirmationDialog.show(
        context,
        title: l10n.replaceCurrentSaleTitle,
        message: l10n.replaceCurrentSaleMessage,
        confirmText: l10n.confirm,
      );
      if (!shouldReplace) return;
    }

    final heldInvoices = await _saleService.listHeldInvoicesForUser(user.id);

    if (heldInvoices.isEmpty) {
      if (!mounted) return;
      AppFeedback.warning(context, l10n.noHeldInvoices);
      return;
    }

    if (!mounted) return;

    final selectedInvoice = await showDialog<Invoice>(
      context: context,
      builder: (context) => HeldInvoicesDialog(invoices: heldInvoices),
    );

    if (selectedInvoice == null) return;

    final recalledSale = await _saleService.recallHeldSale(selectedInvoice.id);

    setState(() {
      _draft = _draft.copyWith(
        cart: recalledSale.cart,
        selectedCustomer: recalledSale.customer,
        invoiceDiscount: recalledSale.invoice.discountAmount,
        discountType: recalledSale.invoice.discountType,
        paymentMethod: recalledSale.invoice.paymentMethod,
        currencyCode: recalledSale.invoice.currencyCode,
        exchangeRate: CurrencyConversion.normalizeRate(
          recalledSale.invoice.currencyCode,
          recalledSale.invoice.exchangeRate,
        ),
      );
      _syncDiscountController();
    });

    if (!mounted) return;
    AppFeedback.success(context, l10n.heldInvoiceRestored);
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    final l10n = context.l10n;
    final scannedBarcode = barcode.trim();
    if (scannedBarcode.isEmpty || _products.isEmpty) return;

    final product = _screenService.findProductByBarcode(
      _products,
      scannedBarcode,
    );

    if (product != null) {
      _addToCart(product);
      _barcodeController.clear();
      _barcodeFocus.requestFocus();
      AppFeedback.success(
        context,
        l10n.barcodeAddedToCart(product.nameAr),
        duration: const Duration(milliseconds: 1200),
      );
    } else {
      _barcodeFocus.requestFocus();
      AppFeedback.error(context, '${l10n.barcodeNotFound}: $scannedBarcode');
    }
  }

  Future<bool> _confirmSaleGuard(PosSaleGuardResult guard) async {
    if (!guard.hasIssues) return true;

    final l10n = context.l10n;
    final messages = guard.issues.map((issue) {
      return switch (issue.kind) {
        PosSaleGuardIssueKind.belowCost =>
          l10n.saleGuardBelowCost(issue.productName),
        PosSaleGuardIssueKind.highDiscount => l10n.saleGuardHighDiscount(
            issue.detail ?? '0',
          ),
        PosSaleGuardIssueKind.unusuallyHighTotal => l10n.saleGuardUnusualTotal,
      };
    }).join('\n• ');

    return ConfirmationDialog.show(
      context,
      title: l10n.saleGuardTitle,
      message: '${l10n.saleGuardConfirm}\n\n• $messages',
      confirmText: l10n.proceedAnyway,
      confirmColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  Future<List<PosPaymentSplit>> _resolvePaymentSplits(
    PosPricingSummary summary,
  ) async {
    if (_draft.paymentSplits != null && _draft.paymentSplits!.isNotEmpty) {
      return _draft.paymentSplits!;
    }
    if (_paymentMethod != 'split') {
      return [
        PosPaymentSplit(method: _paymentMethod, amount: summary.total),
      ];
    }
    final splits = await SplitPaymentDialog.show(
      context,
      invoiceTotal: summary.total,
      currencyLabel: _currencyCode,
    );
    if (splits == null || !mounted) return const [];
    setState(() {
      _draft = _draft.copyWith(paymentMethod: 'split', paymentSplits: splits);
    });
    return splits;
  }

  String _paymentMethodLabel(String method, dynamic l10n) {
    return switch (method) {
      'cash' => l10n.cash,
      'card' => l10n.card,
      'transfer' => l10n.transfer,
      'split' => l10n.splitPayment,
      _ => method,
    };
  }

  Future<void> _openSplitPayment() async {
    if (_cart.isEmpty) return;
    final splits = await SplitPaymentDialog.show(
      context,
      invoiceTotal: _pricingSummary.total,
      currencyLabel: _currencyCode,
    );
    if (splits == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(paymentMethod: 'split', paymentSplits: splits);
    });
  }

  Future<void> _applyCustomerSelection(Customer customer) async {
    if (!mounted) return;
    setState(() {
      _draft = _draft.copyWith(selectedCustomer: customer);
      _refreshSmartSuggestions();
    });
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;

    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final summary = _pricingSummary;
      final paymentSplits = await _resolvePaymentSplits(summary);
      if (paymentSplits.isEmpty) return;
      final guard = await _saleGuardService.evaluate(
        db: ref.read(databaseProvider),
        cart: _cart,
        summary: summary,
        currencyCode: _currencyCode,
        exchangeRate: _exchangeRate,
        customerId: _selectedCustomer?.id,
      );
      if (!mounted) return;
      if (!await _confirmSaleGuard(guard)) return;
      final grossSubtotal = summary.grossSubtotal;
      final lineDiscountTotal = summary.lineDiscountTotal;
      final invoiceDiscountAmount = summary.invoiceDiscountAmount;
      final invoiceTotal = summary.total;
      final selectedCustomerName = _selectedCustomer?.name;
      final invoiceItems = _cart
          .map((item) => item.toPrintItem())
          .toList(growable: false);
      final saleResult = await _saleService.completeSale(
        user: user,
        cart: _cart,
        customer: _selectedCustomer,
        summary: summary,
        discountType: _discountType,
        paymentSplits: paymentSplits,
        currencyCode: _currencyCode,
        exchangeRate: _exchangeRate,
        branchId: ref.read(activeBranchIdProvider),
      );

      final db = ref.read(databaseProvider);
      final stock = await _smartService.loadStockTotals(db);
      final topIds = await _smartService.loadTopSellerProductIds(db);

      // Clear cart
      if (!mounted) return;
      setState(() {
        _draft = _draft.resetAfterComplete();
        _discountController.clear();
        _stockByProductId = stock;
        _topSellers = _smartService.productsFromIds(topIds, _products);
        _refreshSmartSuggestions();
      });

      try {
        final company = await const CompanyProfileService().load(
          ref.read(databaseProvider),
        );
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
              taxLabel: l10n.tax,
              totalLabel: l10n.total,
              walkInCustomerLabel: l10n.walkInCustomer,
            ),
            invoiceNumber: saleResult.invoiceNumber,
            createdAt: saleResult.createdAt,
            paymentMethod: paymentSplits.length == 1
                ? _paymentMethodLabel(paymentSplits.first.method, l10n)
                : l10n.splitPayment,
            currencyCode: _currencyCode,
            subtotal: grossSubtotal,
            itemDiscountAmount: lineDiscountTotal,
            discountAmount: invoiceDiscountAmount,
            taxAmount: summary.taxAmount,
            total: invoiceTotal,
            items: invoiceItems,
            customerName: selectedCustomerName,
            cashierName: user.fullName,
            companyName: company.name,
            companyPhone: company.phone,
            companyAddress: company.address,
            companyLogoPath: company.logoPath,
          ),
        );
      } catch (e, st) {
        await AppLogger.record('POS print invoice', error: e, stackTrace: st);
        if (mounted) {
          AppFeedback.warning(context, context.l10n.invoiceSavedPrintFailed);
        }
      }

      if (mounted) {
        AppFeedback.success(
          context,
          '${context.l10n.saleCompletedSuccessfully} - ${saleResult.invoiceNumber}',
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${context.l10n.errorOccurred}: $e');
      }
    }
  }

  Future<void> _clearCartWithConfirmation() async {
    if (_cart.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.clearCartTitle,
      message: l10n.clearCartMessage,
      confirmText: l10n.confirm,
    );
    if (confirmed == true && mounted) {
      setState(() {
        _draft = _draft.copyWith(cart: const []);
        _refreshSmartSuggestions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.f1):
            _ShowKeyboardHelpIntent(),
        const SingleActivator(LogicalKeyboardKey.f2): _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.f3): _FocusBarcodeIntent(),
        const SingleActivator(LogicalKeyboardKey.f4): _CompleteSaleIntent(),
        const SingleActivator(LogicalKeyboardKey.f5): _OpenSplitPaymentIntent(),
        const SingleActivator(LogicalKeyboardKey.f6): _HoldInvoiceIntent(),
        const SingleActivator(LogicalKeyboardKey.f7): _RecallInvoiceIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): _ClearCartIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CompleteSaleIntent: CallbackAction<_CompleteSaleIntent>(
            onInvoke: (_) {
              if (_cart.isNotEmpty) _completeSale();
              return null;
            },
          ),
          _OpenSplitPaymentIntent: CallbackAction<_OpenSplitPaymentIntent>(
            onInvoke: (_) {
              if (_cart.isNotEmpty) _openSplitPayment();
              return null;
            },
          ),
          _HoldInvoiceIntent: CallbackAction<_HoldInvoiceIntent>(
            onInvoke: (_) {
              if (_cart.isNotEmpty) _holdCurrentInvoice();
              return null;
            },
          ),
          _RecallInvoiceIntent: CallbackAction<_RecallInvoiceIntent>(
            onInvoke: (_) {
              _recallHeldInvoice();
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
          _FocusBarcodeIntent: CallbackAction<_FocusBarcodeIntent>(
            onInvoke: (_) {
              _barcodeFocus.requestFocus();
              return null;
            },
          ),
          _ClearCartIntent: CallbackAction<_ClearCartIntent>(
            onInvoke: (_) {
              unawaited(_clearCartWithConfirmation());
              return null;
            },
          ),
          _ShowKeyboardHelpIntent: CallbackAction<_ShowKeyboardHelpIntent>(
            onInvoke: (_) {
              PosKeyboardHelpDialog.show(context);
              return null;
            },
          ),
        },
        child: BarcodeScannerScope(
          onScan: _handleBarcodeScan,
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            body: Row(
              children: [
                PosProductsPanel(
              isDark: isDark,
              barcodeController: _barcodeController,
              barcodeFocus: _barcodeFocus,
              onBarcodeSubmitted: _handleBarcodeScan,
              searchController: _searchController,
              searchFocus: _searchFocus,
              onSearchChanged: _filterProducts,
              selectedCategoryId: _selectedCategoryId,
              categories: _categories,
              onCategorySelected: (categoryId) {
                setState(() => _selectedCategoryId = categoryId);
                _filterProducts(_searchController.text);
              },
              filteredProducts: _filteredProducts,
              formatProductPrice: (product) =>
                  _formatCurrency(_fromBaseAmount(product.sellingPrice)),
              onProductTap: _addToCart,
              topSellers: _topSellers,
              stockByProductId: _stockByProductId,
              lowStockLabel: l10n.lowStockBadge,
              outOfStockLabel: l10n.outOfStock,
            ),
            PosCartPanel(
              isDark: isDark,
              cart: _cart,
              onClearCart: () => setState(() {
                _draft = _draft.copyWith(cart: const []);
                _refreshSmartSuggestions();
              }),
              smartSuggestions: _smartSuggestions,
              onSmartSuggestionTap: _addToCart,
              selectedCustomerName: _selectedCustomer?.name,
              onSelectCustomer: _selectCustomer,
              onClearSelectedCustomer: () => setState(() {
                _draft = _draft.copyWith(selectedCustomer: null);
              }),
              onDecreaseItem: (index) {
                final item = _cart[index];
                if (item.quantity > 1) {
                  _updateCartItemQuantity(index, item.quantity - 1);
                } else {
                  _removeFromCart(index);
                }
              },
              onIncreaseItem: (index) =>
                  _updateCartItemQuantity(index, _cart[index].quantity + 1),
              onEditItemDiscount: _editCartItemDiscount,
              formatCurrency: _formatCurrency,
              grossSubtotal: _grossSubtotal,
              lineDiscountTotal: _lineDiscountTotal,
              discountAmount: _discountAmount,
              taxAmount: _taxAmount,
              total: _total,
              currencies: _currencies,
              currencyCode: _currencyCode,
              onCurrencyChanged: _applyCurrencySelection,
              discountController: _discountController,
              onInvoiceDiscountChanged: (value) => setState(() {
                _draft = _draft.copyWith(
                  invoiceDiscount: double.tryParse(value.trim()) ?? 0,
                );
              }),
              onClearInvoiceDiscount: () => setState(() {
                _draft = _draft.clearInvoiceDiscount();
                _discountController.clear();
              }),
              discountType: _discountType,
              onDiscountTypeChanged: (value) => setState(() {
                _draft = _draft.copyWith(discountType: value);
              }),
              onHoldInvoice: _cart.isEmpty ? null : _holdCurrentInvoice,
              onRecallInvoice: _recallHeldInvoice,
              paymentMethod: _paymentMethod,
              onPaymentMethodChanged: (value) => setState(() {
                _draft = _draft.copyWith(
                  paymentMethod: value,
                  paymentSplits: null,
                );
              }),
              onSplitPayment: _cart.isEmpty ? null : _openSplitPayment,
              onCompleteSale: _cart.isEmpty ? null : _completeSale,
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final db = ref.read(databaseProvider);
    final customers = await _screenService.loadActiveCustomers(db);

    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerSelectDialog(customers: customers),
    );

    if (selected != null) {
      if (_cart.isEmpty) {
        setState(() => _draft = _draft.copyWith(selectedCustomer: selected));
      } else {
        await _applyCustomerSelection(selected);
      }
    }
  }
}
