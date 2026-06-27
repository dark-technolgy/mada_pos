import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/date_formatter.dart';
import 'invoice_list_filter_state.dart';

class InvoiceStatusTextLabels {
  const InvoiceStatusTextLabels({
    required this.paid,
    required this.partial,
    required this.unpaid,
    required this.cancelled,
  });

  final String paid;
  final String partial;
  final String unpaid;
  final String cancelled;
}

class InvoiceActiveFilterLabels {
  const InvoiceActiveFilterLabels({
    required this.date,
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.custom,
    required this.all,
    required this.from,
    required this.to,
    required this.status,
    required this.paymentMethod,
    required this.cash,
    required this.card,
    required this.transfer,
    required this.currency,
    required this.discount,
    required this.sortBy,
    required this.amount,
    required this.customer,
    required this.ascending,
    required this.descending,
  });

  final String date;
  final String today;
  final String thisWeek;
  final String thisMonth;
  final String custom;
  final String all;
  final String from;
  final String to;
  final String status;
  final String paymentMethod;
  final String cash;
  final String card;
  final String transfer;
  final String currency;
  final String discount;
  final String sortBy;
  final String amount;
  final String customer;
  final String ascending;
  final String descending;
}

class InvoiceSummaryMetrics {
  const InvoiceSummaryMetrics({
    required this.count,
    required this.totalBase,
    required this.paidBase,
    required this.remainingBase,
  });

  final int count;
  final double totalBase;
  final double paidBase;
  final double remainingBase;
}

class InvoiceDetailsData {
  const InvoiceDetailsData({
    required this.items,
    required this.productsById,
    required this.cashierName,
  });

  final List<InvoiceItem> items;
  final Map<int, Product> productsById;
  final String? cashierName;
}

class InvoicesScreenService {
  const InvoicesScreenService();

  String customerNameFor({
    required int? customerId,
    required List<Customer> customers,
    required String cashCustomerLabel,
    required String unknownLabel,
  }) {
    if (customerId == null) return cashCustomerLabel;
    final customer = customers
        .where((item) => item.id == customerId)
        .firstOrNull;
    return customer?.name ?? unknownLabel;
  }

  double totalDiscountFor(
    Invoice invoice,
    Map<int, double> itemDiscountTotals,
  ) {
    return invoice.discountAmount + (itemDiscountTotals[invoice.id] ?? 0);
  }

  InvoiceSummaryMetrics calculateSummary(List<Invoice> invoices) {
    return InvoiceSummaryMetrics(
      count: invoices.length,
      totalBase: invoices.fold(
        0.0,
        (sum, invoice) =>
            sum +
            CurrencyConversion.toBase(
              invoice.total,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            ),
      ),
      paidBase: invoices.fold(
        0.0,
        (sum, invoice) =>
            sum +
            CurrencyConversion.toBase(
              invoice.paidAmount,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            ),
      ),
      remainingBase: invoices.fold(
        0.0,
        (sum, invoice) =>
            sum +
            CurrencyConversion.toBase(
              invoice.remaining,
              currencyCode: invoice.currencyCode,
              exchangeRate: invoice.exchangeRate,
            ),
      ),
    );
  }

  String statusText(String status, InvoiceStatusTextLabels labels) {
    switch (status) {
      case 'paid':
        return labels.paid;
      case 'partial':
        return labels.partial;
      case 'unpaid':
        return labels.unpaid;
      case 'cancelled':
        return labels.cancelled;
      default:
        return status;
    }
  }

  List<String> activeFilterLabels({
    required InvoiceListFilterState filterState,
    required InvoiceActiveFilterLabels labels,
    required InvoiceStatusTextLabels statusLabels,
  }) {
    final items = <String>[];
    if (filterState.dateFilter != 'all') {
      items.add(
        '${labels.date}: ${switch (filterState.dateFilter) {
          'today' => labels.today,
          'thisWeek' => labels.thisWeek,
          'thisMonth' => labels.thisMonth,
          'custom' => labels.custom,
          _ => labels.all,
        }}',
      );
    }
    if (filterState.dateFilter == 'custom' &&
        filterState.customFromDate != null &&
        filterState.customToDate != null) {
      items.add(
        '${labels.from}: ${DateFormatter.formatDate(filterState.customFromDate!)} ${labels.to}: ${DateFormatter.formatDate(filterState.customToDate!)}',
      );
    }
    if (filterState.statusFilter != 'all') {
      items.add(
        '${labels.status}: ${statusText(filterState.statusFilter, statusLabels)}',
      );
    }
    if (filterState.paymentFilter != 'all') {
      items.add(
        '${labels.paymentMethod}: ${switch (filterState.paymentFilter) {
          'cash' => labels.cash,
          'card' => labels.card,
          'transfer' => labels.transfer,
          _ => filterState.paymentFilter,
        }}',
      );
    }
    if (filterState.currencyFilter != 'all') {
      items.add('${labels.currency}: ${filterState.currencyFilter}');
    }
    if (filterState.discountOnly) {
      items.add(labels.discount);
    }
    items.add(
      '${labels.sortBy}: ${switch (filterState.sortField) {
        'amount' => labels.amount,
        'customer' => labels.customer,
        _ => labels.date,
      }} ${filterState.sortAscending ? labels.ascending : labels.descending}',
    );
    return items;
  }

  Future<InvoiceDetailsData> loadInvoiceDetails(
    AppDatabase db,
    Invoice invoice,
  ) async {
    final invoiceItems = await (db.select(
      db.invoiceItems,
    )..where((item) => item.invoiceId.equals(invoice.id))).get();
    final productIds = invoiceItems
        .map((item) => item.productId)
        .toSet()
        .toList();
    final products = productIds.isEmpty
        ? <Product>[]
        : await (db.select(
            db.products,
          )..where((product) => product.id.isIn(productIds))).get();
    final cashier = await (db.select(
      db.users,
    )..where((user) => user.id.equals(invoice.userId))).getSingleOrNull();

    return InvoiceDetailsData(
      items: invoiceItems,
      productsById: {for (final product in products) product.id: product},
      cashierName: cashier?.fullName,
    );
  }
}
