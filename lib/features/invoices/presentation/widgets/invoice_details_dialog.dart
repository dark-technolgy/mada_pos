import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/services/invoice_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';

class InvoiceDetailsDialog extends StatelessWidget {
  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.counterpartyLabel,
    required this.counterpartyName,
    required this.items,
    required this.productsById,
    required this.cashierName,
    required this.statusText,
    required this.statusColor,
    required this.printInvoiceTitle,
    this.showSaleReturn = false,
    this.onSaleReturn,
    this.showPurchaseReturn = false,
    this.onPurchaseReturn,
    this.showVoid = false,
    this.onVoid,
    this.companyName,
    this.companyPhone,
    this.companyAddress,
    this.companyLogoPath,
  });

  final Invoice invoice;
  final String counterpartyLabel;
  final String counterpartyName;
  final List<InvoiceItem> items;
  final Map<int, Product> productsById;
  final String? cashierName;
  final String statusText;
  final Color statusColor;
  /// Title line on PDF (sale vs purchase).
  final String printInvoiceTitle;
  final bool showSaleReturn;
  final Future<void> Function()? onSaleReturn;
  final bool showPurchaseReturn;
  final Future<void> Function()? onPurchaseReturn;
  final bool showVoid;
  final Future<void> Function()? onVoid;
  final String? companyName;
  final String? companyPhone;
  final String? companyAddress;
  final String? companyLogoPath;

  double get _grossSubtotal =>
      items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  double get _itemDiscountTotal =>
      items.fold(0.0, (sum, item) => sum + item.discount);

  String _formatAmount(double amount) {
    return CurrencyFormatter.format(amount, invoice.currencyCode);
  }

  String _localizedPaymentMethod(AppLocalizations l10n) {
    return switch (invoice.paymentMethod) {
      'cash' => l10n.cash,
      'card' => l10n.card,
      'transfer' => l10n.transfer,
      _ => invoice.paymentMethod,
    };
  }

  Future<void> _printInvoice(BuildContext context) async {
    final l10n = context.l10n;

    try {
      await InvoicePrintService.printInvoice(
        InvoicePrintPayload(
          labels: InvoicePrintLabels(
            saleInvoiceTitle: printInvoiceTitle,
            invoiceNumberLabel: l10n.invoiceNumber,
            dateLabel: l10n.date,
            customerLabel: counterpartyLabel,
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
          invoiceNumber: invoice.invoiceNumber,
          createdAt: invoice.createdAt,
          paymentMethod: _localizedPaymentMethod(l10n),
          currencyCode: invoice.currencyCode,
          subtotal: _grossSubtotal,
          itemDiscountAmount: _itemDiscountTotal,
          discountAmount: invoice.discountAmount,
          taxAmount: invoice.taxAmount,
          total: invoice.total,
          items: items
              .map(
                (item) => InvoicePrintItem(
                  name: productsById[item.productId]?.nameAr ?? l10n.unknown,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  discount: item.discount,
                  total: item.total,
                  barcode: productsById[item.productId]?.barcode,
                ),
              )
              .toList(),
          customerName: counterpartyName,
          cashierName: cashierName,
          companyName: companyName,
          companyPhone: companyPhone,
          companyAddress: companyAddress,
          companyLogoPath: companyLogoPath,
        ),
      );
    } catch (e, st) {
      await AppLogger.record('Invoice details print', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.invoiceSavedPrintFailed),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 760),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.invoiceNumber}: ${invoice.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.date}: ${DateFormatter.formatDateTime(invoice.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoCard(
                  label: counterpartyLabel,
                  value: counterpartyName,
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.invoicePayment,
                  value: _localizedPaymentMethod(l10n),
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.cashier,
                  value: cashierName ?? '-',
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.currency,
                  value: invoice.currencyCode,
                  isDark: isDark,
                ),
                _InfoCard(
                  label: l10n.exchangeRate,
                  value: invoice.exchangeRate.toStringAsFixed(2),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.items,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
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
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final product = productsById[item.productId];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product?.nameAr ?? l10n.unknown,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    if ((product?.barcode?.isNotEmpty ?? false))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          product!.barcode!,
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
                              Expanded(
                                child: Text(
                                  '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${l10n.quantity}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatAmount(item.unitPrice),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.discount > 0
                                      ? _formatAmount(item.discount)
                                      : '-',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _formatAmount(item.total),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 280,
                child: Column(
                  children: [
                    _SummaryRow(
                      label: l10n.subtotal,
                      value: _formatAmount(_grossSubtotal),
                      isDark: isDark,
                    ),
                    if (_itemDiscountTotal > 0)
                      _SummaryRow(
                        label: l10n.itemDiscountsLabel,
                        value: '- ${_formatAmount(_itemDiscountTotal)}',
                        isDark: isDark,
                        color: AppColors.error,
                      ),
                    if (invoice.discountAmount > 0)
                      _SummaryRow(
                        label: l10n.invoiceDiscountLabel,
                        value: '- ${_formatAmount(invoice.discountAmount)}',
                        isDark: isDark,
                        color: AppColors.error,
                      ),
                    if (invoice.taxAmount > 0)
                      _SummaryRow(
                        label: l10n.tax,
                        value: _formatAmount(invoice.taxAmount),
                        isDark: isDark,
                      ),
                    const Divider(height: 22),
                    _SummaryRow(
                      label: l10n.total,
                      value: _formatAmount(invoice.total),
                      isDark: isDark,
                      color: AppColors.primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (showSaleReturn && onSaleReturn != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onSaleReturn!();
                      },
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: Text(l10n.saleReturnTitle),
                    ),
                  if (showPurchaseReturn && onPurchaseReturn != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onPurchaseReturn!();
                      },
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: Text(l10n.purchaseReturnTitle),
                    ),
                  if (showVoid && onVoid != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onVoid!();
                      },
                      icon: const Icon(Icons.block_rounded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      label: Text(l10n.voidInvoice),
                    ),
                  FilledButton.icon(
                    onPressed: () => _printInvoice(context),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(l10n.print),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: FontWeight.w700,
                color:
                    color ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
