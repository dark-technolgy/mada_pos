import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/services/account_statement_service.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_feedback.dart';

enum AccountStatementParty { customer, supplier }

class AccountStatementDialog extends ConsumerStatefulWidget {
  const AccountStatementDialog({
    super.key,
    required this.party,
    required this.partyId,
    required this.partyName,
  });

  final AccountStatementParty party;
  final int partyId;
  final String partyName;

  static Future<void> showForCustomer(
    BuildContext context, {
    required int customerId,
    required String customerName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AccountStatementDialog(
        party: AccountStatementParty.customer,
        partyId: customerId,
        partyName: customerName,
      ),
    );
  }

  static Future<void> showForSupplier(
    BuildContext context, {
    required int supplierId,
    required String supplierName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AccountStatementDialog(
        party: AccountStatementParty.supplier,
        partyId: supplierId,
        partyName: supplierName,
      ),
    );
  }

  @override
  ConsumerState<AccountStatementDialog> createState() =>
      _AccountStatementDialogState();
}

class _AccountStatementDialogState extends ConsumerState<AccountStatementDialog> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _printing = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    final l10n = context.l10n;
    final db = ref.read(databaseProvider);
    final branchId = ref.read(activeBranchIdProvider);
    final labels = AccountStatementLabels(
      title: l10n.accountStatement,
      periodLabel: l10n.period,
      dateLabel: l10n.date,
      referenceLabel: l10n.invoiceNumber,
      descriptionLabel: l10n.description,
      debitLabel: l10n.debit,
      creditLabel: l10n.credit,
      balanceLabel: l10n.balance,
      openingBalanceLabel: l10n.openingBalance,
      closingBalanceLabel: l10n.closingBalance,
    );
    try {
      final service = const AccountStatementService();
      if (widget.party == AccountStatementParty.customer) {
        await service.printCustomerStatement(
          db,
          customerId: widget.partyId,
          startDate: _range.start,
          endDate: _range.end,
          labels: labels,
          branchId: branchId,
        );
      } else {
        await service.printSupplierStatement(
          db,
          supplierId: widget.partyId,
          startDate: _range.start,
          endDate: _range.end,
          labels: labels,
          branchId: branchId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.errorOccurred}: $e');
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text('${l10n.accountStatement} — ${widget.partyName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${_range.start.toString().split(' ').first} → ${_range.end.toString().split(' ').first}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _printing ? null : _print,
          icon: _printing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.printStatement),
        ),
      ],
    );
  }
}
