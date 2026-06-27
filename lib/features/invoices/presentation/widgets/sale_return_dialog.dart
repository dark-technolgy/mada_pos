import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../application/sale_return_service.dart';

class SaleReturnDialog extends ConsumerStatefulWidget {
  const SaleReturnDialog({
    super.key,
    required this.invoice,
    required this.items,
    required this.productsById,
  });

  final Invoice invoice;
  final List<InvoiceItem> items;
  final Map<int, Product> productsById;

  @override
  ConsumerState<SaleReturnDialog> createState() => _SaleReturnDialogState();
}

class _SaleReturnDialogState extends ConsumerState<SaleReturnDialog> {
  final _service = const SaleReturnService();
  late final Map<int, TextEditingController> _qtyByLineId;
  Map<int, double> _remainingByLine = {};
  bool _loadingRemain = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _qtyByLineId = {
      for (final item in widget.items) item.id: TextEditingController(text: '0'),
    };
    _loadRemaining();
  }

  Future<void> _loadRemaining() async {
    final db = ref.read(databaseProvider);
    final map = await _service.remainingReturnableQuantities(
      db,
      originalInvoiceId: widget.invoice.id,
      originalItems: widget.items,
    );
    if (!mounted) return;
    setState(() {
      _remainingByLine = map;
      _loadingRemain = false;
    });
  }

  @override
  void dispose() {
    for (final c in _qtyByLineId.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final lines = <SaleReturnLine>[];
    for (final item in widget.items) {
      final raw = _qtyByLineId[item.id]?.text ?? '0';
      final q = double.tryParse(raw) ?? 0;
      if (q <= 0) continue;
      final maxQ = _remainingByLine[item.id] ?? 0;
      if (q > maxQ) {
        AppFeedback.error(context, l10n.fillRequiredFields);
        return;
      }
      lines.add(SaleReturnLine(invoiceItemId: item.id, quantity: q));
    }

    if (lines.isEmpty) {
      AppFeedback.error(context, l10n.fillRequiredFields);
      return;
    }

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await _service.recordSaleReturn(
        db,
        user: user,
        original: widget.invoice,
        lines: lines,
      );
      if (!mounted) return;
      AppFeedback.success(context, l10n.returnRecorded);
      Navigator.of(context).pop(true);
    } on SaleReturnException catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, '$e');
    } catch (e, st) {
      await AppLogger.record('Sale return', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.error(context, l10n.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(l10n.saleReturnTitle),
      content: SizedBox(
        width: 520,
        child: _loadingRemain
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l10n.originalSale}: ${widget.invoice.invoiceNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final item in widget.items) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.productsById[item.productId]?.nameAr ??
                                      l10n.unknown,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${l10n.quantity}: ${item.quantity.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                Text(
                                  l10n.remainingReturnable(
                                    (_remainingByLine[item.id] ?? 0)
                                        .toStringAsFixed(0),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_remainingByLine[item.id] ?? 0) <= 0
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _qtyByLineId[item.id],
                              enabled: (_remainingByLine[item.id] ?? 0) > 0,
                              decoration: InputDecoration(
                                labelText: l10n.returnQtyHint,
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy || _loadingRemain
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy || _loadingRemain ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.returnSubmit),
        ),
      ],
    );
  }
}
