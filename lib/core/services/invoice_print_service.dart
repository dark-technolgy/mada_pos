import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicePrintItem {
  const InvoicePrintItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.total,
    this.barcode,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final String? barcode;
}

class InvoicePrintPayload {
  const InvoicePrintPayload({
    required this.labels,
    required this.invoiceNumber,
    required this.createdAt,
    required this.paymentMethod,
    required this.currencyCode,
    required this.subtotal,
    required this.itemDiscountAmount,
    required this.discountAmount,
    required this.total,
    required this.items,
    this.customerName,
    this.cashierName,
  });

  final InvoicePrintLabels labels;
  final String invoiceNumber;
  final DateTime createdAt;
  final String paymentMethod;
  final String currencyCode;
  final double subtotal;
  final double itemDiscountAmount;
  final double discountAmount;
  final double total;
  final List<InvoicePrintItem> items;
  final String? customerName;
  final String? cashierName;
}

class InvoicePrintLabels {
  const InvoicePrintLabels({
    required this.saleInvoiceTitle,
    required this.invoiceNumberLabel,
    required this.dateLabel,
    required this.customerLabel,
    required this.cashierLabel,
    required this.paymentLabel,
    required this.currencyLabel,
    required this.nameLabel,
    required this.quantityLabel,
    required this.unitPriceLabel,
    required this.discountLabel,
    required this.subtotalLabel,
    required this.itemDiscountsLabel,
    required this.invoiceDiscountSummaryLabel,
    required this.totalLabel,
    required this.walkInCustomerLabel,
  });

  final String saleInvoiceTitle;
  final String invoiceNumberLabel;
  final String dateLabel;
  final String customerLabel;
  final String cashierLabel;
  final String paymentLabel;
  final String currencyLabel;
  final String nameLabel;
  final String quantityLabel;
  final String unitPriceLabel;
  final String discountLabel;
  final String subtotalLabel;
  final String itemDiscountsLabel;
  final String invoiceDiscountSummaryLabel;
  final String totalLabel;
  final String walkInCustomerLabel;
}

class InvoicePrintService {
  static Future<void> printInvoice(InvoicePrintPayload payload) async {
    final labels = payload.labels;
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'KeenX POS',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(labels.saleInvoiceTitle),
                  pw.Text(
                    '${labels.invoiceNumberLabel}: ${payload.invoiceNumber}',
                  ),
                  pw.Text(
                    '${labels.dateLabel}: ${_formatDateTime(payload.createdAt)}',
                  ),
                ],
              ),
              pw.SizedBox(
                width: 130,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: payload.invoiceNumber,
                  height: 48,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${labels.customerLabel}: '
                      '${payload.customerName ?? labels.walkInCustomerLabel}',
                    ),
                    pw.Text(
                      '${labels.cashierLabel}: ${payload.cashierName ?? '-'}',
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${labels.paymentLabel}: ${payload.paymentMethod}'),
                    pw.Text('${labels.currencyLabel}: ${payload.currencyCode}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: [
              labels.nameLabel,
              labels.quantityLabel,
              labels.unitPriceLabel,
              labels.discountLabel,
              labels.totalLabel,
            ],
            data: payload.items
                .map(
                  (item) => [
                    item.name,
                    _formatNumber(item.quantity),
                    _formatMoney(item.unitPrice),
                    _formatMoney(item.discount),
                    _formatMoney(item.total),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              child: pw.Column(
                children: [
                  _summaryRow(
                    labels.subtotalLabel,
                    _formatMoney(payload.subtotal),
                  ),
                  if (payload.itemDiscountAmount > 0)
                    _summaryRow(
                      labels.itemDiscountsLabel,
                      _formatMoney(payload.itemDiscountAmount),
                    ),
                  if (payload.discountAmount > 0)
                    _summaryRow(
                      labels.invoiceDiscountSummaryLabel,
                      _formatMoney(payload.discountAmount),
                    ),
                  pw.Divider(),
                  _summaryRow(
                    labels.totalLabel,
                    '${_formatMoney(payload.total)} ${payload.currencyCode}',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => document.save());
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    final textStyle = pw.TextStyle(
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: isBold ? 12 : 10,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: textStyle),
          pw.Text(value, style: textStyle),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  static String _formatMoney(double value) => value.toStringAsFixed(2);

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}
