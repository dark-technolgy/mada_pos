import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class DebtPaymentDialogResult {
  const DebtPaymentDialogResult({required this.amount, this.notes});

  final double amount;
  final String? notes;
}

Future<DebtPaymentDialogResult?> showDebtPaymentDialog({
  required BuildContext context,
  required AppLocalizations l10n,
  required String remainingAmountLabel,
}) async {
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final result = await showDialog<DebtPaymentDialogResult>(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.recordPayment,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                remainingAmountLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: '${l10n.amount} *'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(labelText: l10n.notes),
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
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        return;
                      }

                      Navigator.pop(
                        context,
                        DebtPaymentDialogResult(
                          amount: amount,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        ),
                      );
                    },
                    child: Text(l10n.record),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  amountCtrl.dispose();
  notesCtrl.dispose();
  return result;
}
