import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/purchase_invoice_service.dart';

class _LineEditors {
  _LineEditors({this.product})
      : quantity = TextEditingController(text: '1'),
        unitCost = TextEditingController(
          text: product == null ? '' : product.purchasePrice.toString(),
        );

  Product? product;
  final TextEditingController quantity;
  final TextEditingController unitCost;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }

  void applyProduct(Product? next) {
    product = next;
    if (next != null && unitCost.text.trim().isEmpty) {
      unitCost.text = next.purchasePrice.toString();
    }
  }
}

class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() =>
      _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen> {
  final _service = const PurchaseInvoiceService();
  final _discountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1');

  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<Currency> _currencies = [];
  final List<_LineEditors> _lines = [];

  int? _supplierId;
  int? _warehouseId;
  String _currencyCode = 'IQD';
  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lines.add(_LineEditors());
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _discountCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final data = await _service.loadFormData(db);
    if (!mounted) return;
    setState(() {
      _suppliers = data.suppliers;
      _products = data.products;
      _warehouses = data.warehouses;
      _currencies = data.currencies;
      _warehouseId = data.defaultWarehouseId;
      _currencyCode = data.defaultCurrencyCode;
      _rateCtrl.text = CurrencyConversion.normalizeRate(
        data.defaultCurrencyCode,
        data.currencies
            .where((c) => c.code == data.defaultCurrencyCode)
            .firstOrNull
            ?.exchangeRate,
      ).toString();
      _loading = false;
    });
  }

  void _onCurrencyChanged(String? code) {
    if (code == null) return;
    final currency = _currencies.where((c) => c.code == code).firstOrNull;
    setState(() {
      _currencyCode = code;
      _rateCtrl.text = CurrencyConversion.normalizeRate(
        code,
        currency?.exchangeRate,
      ).toString();
    });
  }

  void _addLine() {
    setState(() {
      _lines.add(_LineEditors());
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final warehouseId = _warehouseId;
    if (warehouseId == null) {
      AppFeedback.error(context, l10n.fillRequiredFields);
      return;
    }

    final lines = <PurchaseInvoiceLine>[];
    for (final row in _lines) {
      final p = row.product;
      if (p == null) continue;
      final qty = double.tryParse(row.quantity.text) ?? 0;
      final cost = double.tryParse(row.unitCost.text) ?? 0;
      if (qty <= 0 || cost < 0) continue;
      lines.add(
        PurchaseInvoiceLine(
          productId: p.id,
          quantity: qty,
          unitCost: cost,
        ),
      );
    }

    if (lines.isEmpty) {
      AppFeedback.error(context, l10n.fillRequiredFields);
      return;
    }

    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final rate = double.tryParse(_rateCtrl.text);
    if (rate == null || rate <= 0) {
      AppFeedback.error(context, l10n.fillRequiredFields);
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      await _service.recordPurchase(
        db,
        user: user,
        lines: lines,
        supplierId: _supplierId,
        branchId: ref.read(activeBranchIdProvider),
        warehouseId: warehouseId,
        paymentMethod: _paymentMethod,
        currencyCode: _currencyCode,
        exchangeRate: rate,
        invoiceDiscount: discount,
        discountType: 'fixed',
      );
      if (!mounted) return;
      AppFeedback.success(context, l10n.purchaseRecorded);
      context.pop(true);
    } on PurchaseInvoiceException catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.message);
    } catch (e, st) {
      await AppLogger.record('Purchase invoice save', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.error(context, l10n.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: l10n.newPurchaseInvoice,
            subtitle: l10n.purchaseInvoice,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int?>(
                            initialValue: _supplierId,
                            decoration: InputDecoration(
                              labelText: l10n.supplier,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(l10n.supplierNotSpecified),
                              ),
                              ..._suppliers.map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _supplierId = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _warehouseId,
                            decoration: InputDecoration(
                              labelText: '${l10n.warehouse} *',
                              border: const OutlineInputBorder(),
                            ),
                            items: _warehouses
                                .map(
                                  (w) => DropdownMenuItem<int>(
                                    value: w.id,
                                    child: Text(w.name),
                                  ),
                                )
                                .toList(),
                            onChanged: _warehouses.isEmpty
                                ? null
                                : (v) =>
                                    setState(() => _warehouseId = v),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _currencies.any(
                                    (c) => c.code == _currencyCode,
                                  )
                                      ? _currencyCode
                                      : _currencies.firstOrNull?.code,
                                  decoration: InputDecoration(
                                    labelText: l10n.currency,
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: _currencies
                                      .map(
                                        (c) => DropdownMenuItem<String>(
                                          value: c.code,
                                          child: Text(
                                            '${c.code} (${c.symbol})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _onCurrencyChanged,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _rateCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.exchangeRate,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _paymentMethod,
                            decoration: InputDecoration(
                              labelText: l10n.paymentMethod,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text(l10n.cash),
                              ),
                              DropdownMenuItem(
                                value: 'card',
                                child: Text(l10n.card),
                              ),
                              DropdownMenuItem(
                                value: 'transfer',
                                child: Text(l10n.transfer),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _paymentMethod = v);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _discountCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.invoiceDiscountOptional,
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        l10n.products,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addLine),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_lines.length, (index) {
                    final row = _lines[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<Product>(
                                initialValue: row.product,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.products,
                                  border: const OutlineInputBorder(),
                                ),
                                items: _products
                                    .map(
                                      (p) => DropdownMenuItem<Product>(
                                        value: p,
                                        child: Text(
                                          p.nameAr,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (p) {
                                  setState(() => row.applyProduct(p));
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: row.quantity,
                                decoration: InputDecoration(
                                  labelText: l10n.quantity,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: row.unitCost,
                                decoration: InputDecoration(
                                  labelText: l10n.unitPrice,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _lines.length > 1
                                  ? () => _removeLine(index)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.removeLine,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.recordPurchase),
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
