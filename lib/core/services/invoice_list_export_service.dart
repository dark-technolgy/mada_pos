import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceListExportRow {
  const InvoiceListExportRow({
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.paymentMethod,
    required this.currencyCode,
  });

  final String invoiceNumber;
  final String customerName;
  final String date;
  final String amount;
  final String paid;
  final String remaining;
  final String status;
  final String paymentMethod;
  final String currencyCode;
}

class InvoiceListExportPayload {
  const InvoiceListExportPayload({
    required this.title,
    required this.generatedAt,
    required this.generatedAtLabel,
    required this.filtersLabel,
    required this.totalInvoicesLabel,
    required this.invoiceNumberLabel,
    required this.customerLabel,
    required this.dateLabel,
    required this.amountLabel,
    required this.paidLabel,
    required this.remainingLabel,
    required this.statusLabel,
    required this.paymentMethodLabel,
    required this.currencyLabel,
    required this.summaryItems,
    required this.rows,
    required this.activeFilters,
  });

  final String title;
  final DateTime generatedAt;
  final String generatedAtLabel;
  final String filtersLabel;
  final String totalInvoicesLabel;
  final String invoiceNumberLabel;
  final String customerLabel;
  final String dateLabel;
  final String amountLabel;
  final String paidLabel;
  final String remainingLabel;
  final String statusLabel;
  final String paymentMethodLabel;
  final String currencyLabel;
  final List<MapEntry<String, String>> summaryItems;
  final List<InvoiceListExportRow> rows;
  final List<String> activeFilters;
}

class InvoiceListExportService {
  static Future<void> exportPdf(InvoiceListExportPayload payload) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            payload.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${payload.generatedAtLabel}: ${_formatDateTime(payload.generatedAt)}',
          ),
          pw.Text('${payload.totalInvoicesLabel}: ${payload.rows.length}'),
          if (payload.activeFilters.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                '${payload.filtersLabel}: ${payload.activeFilters.join(' | ')}',
              ),
            ),
          if (payload.summaryItems.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 16,
              runSpacing: 8,
              children: payload.summaryItems
                  .map(
                    (item) => pw.Container(
                      width: 180,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.key,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            item.value,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            headers: [
              payload.invoiceNumberLabel,
              payload.customerLabel,
              payload.dateLabel,
              payload.amountLabel,
              payload.paidLabel,
              payload.remainingLabel,
              payload.statusLabel,
              payload.paymentMethodLabel,
              payload.currencyLabel,
            ],
            data: payload.rows
                .map(
                  (row) => [
                    row.invoiceNumber,
                    row.customerName,
                    row.date,
                    row.amount,
                    row.paid,
                    row.remaining,
                    row.status,
                    row.paymentMethod,
                    row.currencyCode,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => document.save());
  }

  static String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}
