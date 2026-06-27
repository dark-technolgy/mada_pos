import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database.dart';

class AddExpenseDialogResult {
  const AddExpenseDialogResult({
    required this.description,
    required this.amount,
    required this.category,
    required this.currencyCode,
  });

  final String description;
  final double? amount;
  final String category;
  final String currencyCode;
}

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({
    super.key,
    required this.currencies,
    required this.initialCurrencyCode,
  });

  final Map<String, Currency> currencies;
  final String initialCurrencyCode;

  static Future<AddExpenseDialogResult?> show(
    BuildContext context, {
    required Map<String, Currency> currencies,
    required String initialCurrencyCode,
  }) {
    return showDialog<AddExpenseDialogResult>(
      context: context,
      builder: (context) => AddExpenseDialog(
        currencies: currencies,
        initialCurrencyCode: initialCurrencyCode,
      ),
    );
  }

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late String _selectedCurrencyCode;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _categoryController = TextEditingController();
    _selectedCurrencyCode =
        widget.currencies.containsKey(widget.initialCurrencyCode)
        ? widget.initialCurrencyCode
        : widget.currencies.keys.firstOrNull ?? widget.initialCurrencyCode;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addExpenseTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '${l10n.expenseDescription} *',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: '${l10n.amount} *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        widget.currencies.containsKey(_selectedCurrencyCode)
                        ? _selectedCurrencyCode
                        : null,
                    decoration: InputDecoration(labelText: l10n.currency),
                    items: widget.currencies.values
                        .map(
                          (currency) => DropdownMenuItem<String>(
                            value: currency.code,
                            child: Text(
                              '${currency.code} - ${currency.symbol}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCurrencyCode = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: l10n.category,
                hintText: l10n.categoryHintExample,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      AddExpenseDialogResult(
                        description: _descriptionController.text.trim(),
                        amount: double.tryParse(_amountController.text),
                        category: _categoryController.text.trim(),
                        currencyCode: _selectedCurrencyCode,
                      ),
                    );
                  },
                  child: Text(l10n.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
