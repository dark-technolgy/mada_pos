import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/invoice_print_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
import '../domain/pos_pricing.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

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

  // Cart
  final List<Map<String, dynamic>> _cart = [];
  Customer? _selectedCustomer;
  double _invoiceDiscount = 0;
  String _discountType = 'fixed'; // fixed or percentage
  String _paymentMethod = 'cash';
  String _currencyCode = CurrencyConversion.baseCurrencyCode;
  double _exchangeRate = 1.0;

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
    final products =
        await (db.select(db.products)
              ..where((p) => p.isActive.equals(true))
              ..orderBy([(p) => OrderingTerm.asc(p.nameAr)]))
            .get();
    final categories = await (db.select(
      db.categories,
    )..where((c) => c.isActive.equals(true))).get();
    final currencies =
        await (db.select(db.currencies)..orderBy([
              (c) => OrderingTerm.desc(c.isDefault),
              (c) => OrderingTerm.asc(c.code),
            ]))
            .get();
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    setState(() {
      _products = products;
      _filteredProducts = products;
      _categories = categories;
      _currencies = currencies;
      _currencyCode =
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode;
      _exchangeRate = CurrencyConversion.normalizeRate(
        _currencyCode,
        defaultCurrency?.exchangeRate,
      );
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

    final previousCurrencyCode = _currencyCode;
    final previousExchangeRate = _exchangeRate;
    final nextExchangeRate = CurrencyConversion.normalizeRate(
      currency.code,
      currency.exchangeRate,
    );

    setState(() {
      if (_discountType == 'fixed' && _invoiceDiscount > 0) {
        final discountBase = CurrencyConversion.toBase(
          _invoiceDiscount,
          currencyCode: previousCurrencyCode,
          exchangeRate: previousExchangeRate,
        );
        _invoiceDiscount = CurrencyConversion.fromBase(
          discountBase,
          currencyCode: currency.code,
          exchangeRate: nextExchangeRate,
        );
        _discountController.text = _formatEditableNumber(_invoiceDiscount);
      }

      _currencyCode = currency.code;
      _exchangeRate = nextExchangeRate;

      for (final item in _cart) {
        final baseUnitPrice =
            item['baseUnitPrice'] as double? ??
            CurrencyConversion.toBase(
              item['unitPrice'] as double,
              currencyCode: previousCurrencyCode,
              exchangeRate: previousExchangeRate,
            );
        final baseDiscount = CurrencyConversion.toBase(
          item['discount'] as double,
          currencyCode: previousCurrencyCode,
          exchangeRate: previousExchangeRate,
        );
        final unitPrice = CurrencyConversion.fromBase(
          baseUnitPrice,
          currencyCode: currency.code,
          exchangeRate: nextExchangeRate,
        );
        final discount = CurrencyConversion.fromBase(
          baseDiscount,
          currencyCode: currency.code,
          exchangeRate: nextExchangeRate,
        );
        item['baseUnitPrice'] = baseUnitPrice;
        item['unitPrice'] = unitPrice;
        item['discount'] = discount;
        item['total'] = (item['quantity'] as double) * unitPrice - discount;
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products.where((p) {
        final matchesSearch =
            query.isEmpty ||
            p.nameAr.contains(query) ||
            (p.nameEn?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (p.barcode?.contains(query) ?? false) ||
            (p.sku?.contains(query) ?? false);
        final matchesCategory =
            _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      final existing = _cart.indexWhere(
        (item) => item['product'].id == product.id,
      );
      if (existing >= 0) {
        _cart[existing]['quantity'] += 1.0;
        _cart[existing]['total'] =
            _cart[existing]['quantity'] * _cart[existing]['unitPrice'] -
            _cart[existing]['discount'];
      } else {
        final unitPrice = _fromBaseAmount(product.sellingPrice);
        _cart.add({
          'product': product,
          'quantity': 1.0,
          'baseUnitPrice': product.sellingPrice,
          'unitPrice': unitPrice,
          'discount': 0.0,
          'total': unitPrice,
        });
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, double qty) {
    if (qty <= 0) return;
    setState(() {
      final pricing = PosPricing.normalizeLine(
        quantity: qty,
        unitPrice: _cart[index]['unitPrice'] as double,
        discount: _cart[index]['discount'] as double,
      );
      _cart[index]['quantity'] = qty;
      _cart[index]['discount'] = pricing.clampedDiscount;
      _cart[index]['total'] = pricing.netTotal;
    });
  }

  void _updateCartItemDiscount(int index, double discountAmount) {
    final pricing = PosPricing.normalizeLine(
      quantity: _cart[index]['quantity'] as double,
      unitPrice: _cart[index]['unitPrice'] as double,
      discount: discountAmount,
    );

    setState(() {
      _cart[index]['discount'] = pricing.clampedDiscount;
      _cart[index]['total'] = pricing.netTotal;
    });
  }

  Future<void> _editCartItemDiscount(int index) async {
    final l10n = context.l10n;
    final item = _cart[index];
    final product = item['product'] as Product;
    final quantity = item['quantity'] as double;
    final unitPrice = item['unitPrice'] as double;
    final grossTotal = quantity * unitPrice;
    final currentDiscount = item['discount'] as double;
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.invalidAmount),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          final discountAmount = selectedType == 'percentage'
                              ? grossTotal * (rawValue.clamp(0, 100) / 100)
                              : rawValue;
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

  PosPricingSummary get _pricingSummary => PosPricing.summarize(
    lines: _cart.map(
      (item) => PosLinePricing(
        quantity: item['quantity'] as double,
        unitPrice: item['unitPrice'] as double,
        discount: item['discount'] as double,
      ),
    ),
    invoiceDiscount: _invoiceDiscount,
    discountType: _discountType,
  );

  double get _grossSubtotal => _pricingSummary.grossSubtotal;

  double get _lineDiscountTotal => _pricingSummary.lineDiscountTotal;

  double get _subtotal => _pricingSummary.subtotal;

  double get _discountAmount => _pricingSummary.invoiceDiscountAmount;

  double get _total => _pricingSummary.total;

  Future<void> _holdCurrentInvoice() async {
    if (_cart.isEmpty) return;

    final l10n = context.l10n;
    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final invoiceNumber = await db.getNextInvoiceNumber('sale');
    final heldInvoiceId = await db
        .into(db.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: invoiceNumber,
            type: 'sale',
            customerId: Value(_selectedCustomer?.id),
            userId: user.id,
            subtotal: Value(_subtotal),
            discountAmount: Value(_discountAmount),
            discountType: Value(_discountType),
            total: Value(_total),
            paidAmount: const Value(0),
            remaining: Value(_total),
            currencyCode: Value(_currencyCode),
            exchangeRate: Value(_exchangeRate),
            paymentMethod: Value(_paymentMethod),
            status: const Value('draft'),
            isHeld: const Value(true),
          ),
        );

    for (final item in _cart) {
      final product = item['product'] as Product;
      await db
          .into(db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: heldInvoiceId,
              productId: product.id,
              quantity: item['quantity'],
              unitPrice: item['unitPrice'],
              discount: Value(item['discount']),
              total: item['total'],
            ),
          );
    }

    if (!mounted) return;

    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _invoiceDiscount = 0;
      _discountType = 'fixed';
      _paymentMethod = 'cash';
      _discountController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.invoiceHeldSuccessfully),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _recallHeldInvoice() async {
    final l10n = context.l10n;
    final db = ref.read(databaseProvider);
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

    final heldInvoices =
        await (db.select(db.invoices)
              ..where((i) => i.userId.equals(user.id))
              ..where((i) => i.isHeld.equals(true))
              ..where((i) => i.status.equals('draft'))
              ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
            .get();

    if (heldInvoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noHeldInvoices),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;

    final selectedInvoice = await showDialog<Invoice>(
      context: context,
      builder: (context) => _HeldInvoicesDialog(invoices: heldInvoices),
    );

    if (selectedInvoice == null) return;

    final heldItems = await (db.select(
      db.invoiceItems,
    )..where((i) => i.invoiceId.equals(selectedInvoice.id))).get();

    final productIds = heldItems.map((item) => item.productId).toSet().toList();
    final products = productIds.isEmpty
        ? <Product>[]
        : await (db.select(
            db.products,
          )..where((p) => p.id.isIn(productIds))).get();
    final productsById = {for (final product in products) product.id: product};

    Customer? selectedCustomer;
    if (selectedInvoice.customerId != null) {
      selectedCustomer =
          await (db.select(db.customers)
                ..where((c) => c.id.equals(selectedInvoice.customerId!)))
              .getSingleOrNull();
    }

    final restoredCart = heldItems
        .map((item) {
          final product = productsById[item.productId];
          if (product == null) return null;
          return {
            'product': product,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
            'discount': item.discount,
            'total': item.total,
            'baseUnitPrice': CurrencyConversion.toBase(
              item.unitPrice,
              currencyCode: selectedInvoice.currencyCode,
              exchangeRate: selectedInvoice.exchangeRate,
            ),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    await (db.delete(
      db.invoiceItems,
    )..where((i) => i.invoiceId.equals(selectedInvoice.id))).go();
    await (db.delete(
      db.invoices,
    )..where((i) => i.id.equals(selectedInvoice.id))).go();

    setState(() {
      _cart
        ..clear()
        ..addAll(restoredCart);
      _selectedCustomer = selectedCustomer;
      _invoiceDiscount = selectedInvoice.discountAmount;
      _discountType = selectedInvoice.discountType;
      _paymentMethod = selectedInvoice.paymentMethod;
      _currencyCode = selectedInvoice.currencyCode;
      _exchangeRate = CurrencyConversion.normalizeRate(
        selectedInvoice.currencyCode,
        selectedInvoice.exchangeRate,
      );
      _discountController.text = selectedInvoice.discountAmount == 0
          ? ''
          : selectedInvoice.discountAmount.toStringAsFixed(
              selectedInvoice.discountAmount ==
                      selectedInvoice.discountAmount.roundToDouble()
                  ? 0
                  : 2,
            );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.heldInvoiceRestored),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    final l10n = context.l10n;
    final scannedBarcode = barcode.trim();
    if (scannedBarcode.isEmpty || _products.isEmpty) return;

    Product? product;
    for (final item in _products) {
      if (item.barcode == scannedBarcode) {
        product = item;
        break;
      }
    }

    if (product != null) {
      _addToCart(product);
      _barcodeController.clear();
      _barcodeFocus.requestFocus();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.barcodeAddedToCart(product.nameAr)),
          backgroundColor: AppColors.success,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } else {
      _barcodeFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.barcodeNotFound}: $scannedBarcode'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;

    final l10n = context.l10n;
    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final invoiceNumber = await db.getNextInvoiceNumber('sale');
      final invoiceSubtotal = _subtotal;
      final grossSubtotal = _grossSubtotal;
      final lineDiscountTotal = _lineDiscountTotal;
      final invoiceDiscountAmount = _discountAmount;
      final invoiceTotal = _total;
      final selectedCustomerName = _selectedCustomer?.name;
      final invoiceItems = _cart
          .map(
            (item) => InvoicePrintItem(
              name: (item['product'] as Product).nameAr,
              quantity: item['quantity'] as double,
              unitPrice: item['unitPrice'] as double,
              discount: item['discount'] as double,
              total: item['total'] as double,
              barcode: (item['product'] as Product).barcode,
            ),
          )
          .toList(growable: false);

      // Create invoice
      final invoiceId = await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: invoiceNumber,
              type: 'sale',
              customerId: Value(_selectedCustomer?.id),
              userId: user.id,
              subtotal: Value(invoiceSubtotal),
              discountAmount: Value(invoiceDiscountAmount),
              discountType: Value(_discountType),
              total: Value(invoiceTotal),
              paidAmount: Value(invoiceTotal),
              remaining: const Value(0),
              currencyCode: Value(_currencyCode),
              exchangeRate: Value(_exchangeRate),
              paymentMethod: Value(_paymentMethod),
              status: const Value('paid'),
            ),
          );

      // Create invoice items and update stock
      for (final item in _cart) {
        final product = item['product'] as Product;
        await db
            .into(db.invoiceItems)
            .insert(
              InvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: product.id,
                quantity: item['quantity'],
                unitPrice: item['unitPrice'],
                discount: Value(item['discount']),
                total: item['total'],
              ),
            );

        // Update stock (decrease)
        final existingStock = await (db.select(
          db.stock,
        )..where((s) => s.productId.equals(product.id))).getSingleOrNull();

        if (existingStock != null) {
          await (db.update(
            db.stock,
          )..where((s) => s.id.equals(existingStock.id))).write(
            StockCompanion(
              quantity: Value(existingStock.quantity - item['quantity']),
              lastUpdated: Value(DateTime.now()),
            ),
          );
        }

        // Stock movement
        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                productId: product.id,
                quantity: item['quantity'],
                type: 'out',
                referenceType: const Value('invoice'),
                referenceId: Value(invoiceId),
                userId: Value(user.id),
              ),
            );
      }

      // Create payment record
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              invoiceId: Value(invoiceId),
              customerId: Value(_selectedCustomer?.id),
              amount: invoiceTotal,
              currencyCode: Value(_currencyCode),
              paymentMethod: Value(_paymentMethod),
              userId: Value(user.id),
            ),
          );

      // Clear cart
      setState(() {
        _cart.clear();
        _selectedCustomer = null;
        _invoiceDiscount = 0;
        _discountController.clear();
      });

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
            invoiceNumber: invoiceNumber,
            createdAt: DateTime.now(),
            paymentMethod: switch (_paymentMethod) {
              'cash' => l10n.cash,
              'card' => l10n.card,
              'transfer' => l10n.transfer,
              _ => _paymentMethod,
            },
            currencyCode: _currencyCode,
            subtotal: grossSubtotal,
            itemDiscountAmount: lineDiscountTotal,
            discountAmount: invoiceDiscountAmount,
            total: invoiceTotal,
            items: invoiceItems,
            customerName: selectedCustomerName,
            cashierName: user.fullName,
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.invoiceSavedPrintFailed),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.saleCompletedSuccessfully} - $invoiceNumber',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.errorOccurred}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.f2) {
              _completeSale();
            }
            if (event.logicalKey == LogicalKeyboardKey.f3) {
              _searchFocus.requestFocus();
            }
          }
        },
        child: Row(
          children: [
            // ─── LEFT: PRODUCTS ───
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  // Search & Barcode
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Barcode scanner input
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _barcodeController,
                            focusNode: _barcodeFocus,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: l10n.scanBarcode,
                              prefixIcon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onSubmitted: _handleBarcodeScan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Product search
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: l10n.searchProductShortcut,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onChanged: _filterProducts,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Categories
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip(null, l10n.all, isDark),
                        ..._categories.map(
                          (c) => _buildCategoryChip(c.id, c.nameAr, isDark),
                        ),
                      ],
                    ),
                  ),
                  // Product Grid
                  Expanded(
                    child: _filteredProducts.isEmpty
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
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(
                                _filteredProducts[index],
                                isDark,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            // ─── RIGHT: CART ───
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  left: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cart,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_cart.length} ${l10n.items}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        if (_cart.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _cart.clear()),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_sweep_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Customer Selection
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: _selectCustomer,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: _selectedCustomer != null
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCustomer?.name ??
                                    l10n.selectCustomerOptional,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _selectedCustomer != null
                                      ? (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary)
                                      : (isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted),
                                ),
                              ),
                            ),
                            if (_selectedCustomer != null)
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedCustomer = null),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Cart Items
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.emptyCart,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.tapProductToAdd,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              return _buildCartItem(index, isDark);
                            },
                          ),
                  ),
                  // ─── TOTALS ───
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightBg,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildTotalRow(
                          l10n.subtotal,
                          _formatCurrency(_grossSubtotal),
                          isDark,
                        ),
                        if (_lineDiscountTotal > 0)
                          _buildTotalRow(
                            l10n.itemDiscountsLabel,
                            '- ${_formatCurrency(_lineDiscountTotal)}',
                            isDark,
                            color: AppColors.error,
                          ),
                        if (_discountAmount > 0)
                          _buildTotalRow(
                            l10n.invoiceDiscountLabel,
                            '- ${_formatCurrency(_discountAmount)}',
                            isDark,
                            color: AppColors.error,
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.total,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              _formatCurrency(_total),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  if (_currencies.isNotEmpty) ...[
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue:
                                            _currencies.any(
                                              (currency) =>
                                                  currency.code ==
                                                  _currencyCode,
                                            )
                                            ? _currencyCode
                                            : null,
                                        decoration: InputDecoration(
                                          labelText: l10n.currency,
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        items: _currencies
                                            .map(
                                              (
                                                currency,
                                              ) => DropdownMenuItem<String>(
                                                value: currency.code,
                                                child: Text(
                                                  '${currency.code} - ${currency.symbol}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        selectedItemBuilder: (context) {
                                          return _currencies
                                              .map(
                                                (currency) => Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    currency.code,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList();
                                        },
                                        onChanged: (value) {
                                          if (value == null) return;
                                          _applyCurrencySelection(value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: TextField(
                                      controller: _discountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: l10n.invoiceDiscountLabel,
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _invoiceDiscount =
                                              double.tryParse(value.trim()) ??
                                              0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: l10n.clearDiscount,
                                    onPressed: () {
                                      setState(() {
                                        _invoiceDiscount = 0;
                                        _discountController.clear();
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.layers_clear_rounded,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDiscountTypeOption(
                                      'fixed',
                                      l10n.fixedAmount,
                                      isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildDiscountTypeOption(
                                      'percentage',
                                      l10n.percentage,
                                      isDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  l10n.currentCurrencyLabel(_currencyCode),
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
                        const SizedBox(height: 12),
                        // Payment method
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _cart.isEmpty
                                    ? null
                                    : _holdCurrentInvoice,
                                icon: const Icon(
                                  Icons.pause_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: Text(l10n.holdInvoice),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _recallHeldInvoice,
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                ),
                                label: Text(l10n.recallInvoice),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildPaymentOption(
                              'cash',
                              l10n.cash,
                              Icons.payments_rounded,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildPaymentOption(
                              'card',
                              l10n.card,
                              Icons.credit_card_rounded,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildPaymentOption(
                              'transfer',
                              l10n.transfer,
                              Icons.swap_horiz_rounded,
                              isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Complete Sale Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _cart.isEmpty ? null : _completeSale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${l10n.completeSale} (F2)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDiscountTypeOption(String type, String label, bool isDark) {
    final isSelected = _discountType == type;
    return InkWell(
      onTap: () => setState(() => _discountType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String name, bool isDark) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategoryId = id);
          _filterProducts(_searchController.text);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    return InkWell(
      onTap: () => _addToCart(product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.nameAr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(_fromBaseAmount(product.sellingPrice)),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, bool isDark) {
    final item = _cart[index];
    final product = item['product'] as Product;
    final discount = item['discount'] as double;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nameAr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(item['unitPrice'] as double),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.discount}: ${_formatCurrency(discount)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (item['quantity'] > 1) {
                          _updateCartItemQuantity(index, item['quantity'] - 1);
                        } else {
                          _removeFromCart(index);
                        }
                      },
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(7),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item['quantity'].toInt()}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          _updateCartItemQuantity(index, item['quantity'] + 1),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(7),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _editCartItemDiscount(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.discount_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Text(
                      _formatCurrency(item['total'] as double),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value,
    bool isDark, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  color ??
                  (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(
    String method,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Column(
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
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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

  Future<void> _selectCustomer() async {
    final db = ref.read(databaseProvider);
    final customers = await (db.select(
      db.customers,
    )..where((c) => c.isActive.equals(true))).get();

    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerSelectDialog(customers: customers),
    );

    if (selected != null) {
      setState(() => _selectedCustomer = selected);
    }
  }
}

class _CustomerSelectDialog extends StatefulWidget {
  final List<Customer> customers;
  const _CustomerSelectDialog({required this.customers});

  @override
  State<_CustomerSelectDialog> createState() => _CustomerSelectDialogState();
}

class _CustomerSelectDialogState extends State<_CustomerSelectDialog> {
  late List<Customer> _filtered;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              l10n.selectCustomer,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: l10n.searchCustomers,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _filtered = widget.customers
                      .where(
                        (c) =>
                            c.name.contains(v) ||
                            (c.phone?.contains(v) ?? false),
                      )
                      .toList();
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        c.name.substring(0, 1),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(c.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      c.phone ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeldInvoicesDialog extends StatelessWidget {
  const _HeldInvoicesDialog({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.heldInvoicesTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: invoices.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.receipt_long_rounded, size: 18),
                    ),
                    title: Text(invoice.invoiceNumber),
                    subtitle: Text(
                      '${CurrencyFormatter.format(invoice.total, invoice.currencyCode)} • '
                      '${invoice.createdAt.year}-${invoice.createdAt.month.toString().padLeft(2, '0')}-${invoice.createdAt.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () => Navigator.pop(context, invoice),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
