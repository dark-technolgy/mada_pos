import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../application/inventory_adjustment_service.dart';

class InventoryAdjustmentDialog extends ConsumerStatefulWidget {
  const InventoryAdjustmentDialog({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  ConsumerState<InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends ConsumerState<InventoryAdjustmentDialog> {
  final _service = const InventoryAdjustmentService();
  final _deltaCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<WarehouseStockRow> _rows = [];
  int? _warehouseId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final rows = await _service.loadWarehouseOptions(
      db,
      productId: widget.product.id,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _warehouseId =
          rows.where((r) => r.warehouse.isDefault).firstOrNull?.warehouse.id ??
          rows.firstOrNull?.warehouse.id;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    final wid = _warehouseId;
    if (user == null || wid == null) return;

    final delta = double.tryParse(_deltaCtrl.text.trim());
    if (delta == null || delta == 0) {
      AppFeedback.error(context, l10n.fillRequiredFields);
      return;
    }

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await _service.applyDelta(
        db,
        user: user,
        productId: widget.product.id,
        warehouseId: wid,
        delta: delta,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      AppFeedback.success(context, l10n.adjustmentSaved);
      Navigator.of(context).pop(true);
    } on InventoryAdjustmentException catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, '$e');
    } catch (e, st) {
      await AppLogger.record('Inventory adjustment', error: e, stackTrace: st);
      if (!mounted) return;
      AppFeedback.error(context, l10n.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          width: 280,
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Text('${l10n.stockAdjustment}: ${widget.product.nameAr}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              decoration: InputDecoration(
                labelText: l10n.adjustmentWarehouse,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final row in _rows)
                  DropdownMenuItem<int>(
                    value: row.warehouse.id,
                    child: Text(
                      '${row.warehouse.name} (${row.quantity.toStringAsFixed(0)})',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _warehouseId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deltaCtrl,
              decoration: InputDecoration(
                labelText: l10n.adjustmentDeltaHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.adjustmentNotesOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.applyAdjustment),
        ),
      ],
    );
  }
}
