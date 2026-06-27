import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../application/stock_transfer_service.dart';

Future<bool> showStockTransferDialog({
  required BuildContext context,
  required Product product,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => StockTransferDialog(product: product),
  );
  return result == true;
}

class StockTransferDialog extends ConsumerStatefulWidget {
  const StockTransferDialog({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockTransferDialog> createState() =>
      _StockTransferDialogState();
}

class _StockTransferDialogState extends ConsumerState<StockTransferDialog> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _service = const StockTransferService();
  List<Warehouse> _warehouses = [];
  int? _fromId;
  int? _toId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final warehouses = await (db.select(db.warehouses)
          ..where((w) => w.isActive.equals(true)))
        .get();
    if (!mounted) return;
    setState(() {
      _warehouses = warehouses;
      _fromId = warehouses.where((w) => w.isDefault).firstOrNull?.id ??
          warehouses.firstOrNull?.id;
      _toId = warehouses.length > 1 ? warehouses[1].id : warehouses.firstOrNull?.id;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    final from = _fromId;
    final to = _toId;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (user == null || from == null || to == null || qty <= 0) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      await _service.transfer(
        db,
        user: user,
        productId: widget.product.id,
        fromWarehouseId: from,
        toWarehouseId: to,
        quantity: qty,
      );
      if (mounted) Navigator.pop(context, true);
    } on StockTransferException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: ${e.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.stockTransfer),
      content: _loading
          ? const SizedBox(
              width: 280,
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.product.nameAr),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _fromId,
                    decoration: InputDecoration(
                      labelText: l10n.from,
                      border: const OutlineInputBorder(),
                    ),
                    items: _warehouses
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _fromId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _toId,
                    decoration: InputDecoration(
                      labelText: l10n.to,
                      border: const OutlineInputBorder(),
                    ),
                    items: _warehouses
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _toId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.quantity,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving || _loading ? null : _submit,
          child: Text(_saving ? l10n.saving : l10n.save),
        ),
      ],
    );
  }
}
