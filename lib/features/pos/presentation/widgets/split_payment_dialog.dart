import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_payment_split.dart';

class SplitPaymentDialog extends StatefulWidget {
  const SplitPaymentDialog({
    super.key,
    required this.invoiceTotal,
    required this.currencyLabel,
  });

  final double invoiceTotal;
  final String currencyLabel;

  static Future<List<PosPaymentSplit>?> show(
    BuildContext context, {
    required double invoiceTotal,
    required String currencyLabel,
  }) {
    return showDialog<List<PosPaymentSplit>>(
      context: context,
      builder: (ctx) => SplitPaymentDialog(
        invoiceTotal: invoiceTotal,
        currencyLabel: currencyLabel,
      ),
    );
  }

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  final _cashCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _transferCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    _transferCtrl.dispose();
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.trim()) ?? 0;

  double get _enteredTotal =>
      _parse(_cashCtrl.text) + _parse(_cardCtrl.text) + _parse(_transferCtrl.text);

  void _fillRemaining(TextEditingController target) {
    final others = _enteredTotal - _parse(target.text);
    final remaining = (widget.invoiceTotal - others).clamp(0.0, double.infinity);
    target.text = remaining == remaining.roundToDouble()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(2);
    setState(() => _error = null);
  }

  void _submit() {
    final l10n = context.l10n;
    final splits = <PosPaymentSplit>[];
    final cash = _parse(_cashCtrl.text);
    final card = _parse(_cardCtrl.text);
    final transfer = _parse(_transferCtrl.text);
    if (cash > 0) splits.add(PosPaymentSplit(method: 'cash', amount: cash));
    if (card > 0) splits.add(PosPaymentSplit(method: 'card', amount: card));
    if (transfer > 0) {
      splits.add(PosPaymentSplit(method: 'transfer', amount: transfer));
    }
    if (splits.isEmpty) {
      setState(() => _error = l10n.splitPaymentEmpty);
      return;
    }
    if ((_enteredTotal - widget.invoiceTotal).abs() > 0.01) {
      setState(() => _error = l10n.splitPaymentMismatch);
      return;
    }
    Navigator.pop(context, splits);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.splitPayment,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.total}: ${widget.invoiceTotal.toStringAsFixed(2)} ${widget.currencyLabel}',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _amountField(l10n.cash, _cashCtrl, isDark),
              const SizedBox(height: 10),
              _amountField(l10n.card, _cardCtrl, isDark),
              const SizedBox(height: 10),
              _amountField(l10n.transfer, _transferCtrl, isDark),
              const SizedBox(height: 8),
              Text(
                '${l10n.splitPaymentEntered}: ${_enteredTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => _fillRemaining(_cashCtrl),
                    child: Text(l10n.splitFillCash),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountField(String label, TextEditingController ctrl, bool isDark) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (_) => setState(() => _error = null),
    );
  }
}
