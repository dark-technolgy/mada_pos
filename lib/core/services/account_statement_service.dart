import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database.dart';
import '../utils/currency_conversion.dart';
import 'company_profile_service.dart';

class AccountStatementLine {
  const AccountStatementLine({
    required this.date,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime date;
  final String reference;
  final String description;
  final double debit;
  final double credit;
  final double balance;
}

class AccountStatementData {
  const AccountStatementData({
    required this.partyName,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.lines,
    required this.currencyCode,
  });

  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final double closingBalance;
  final List<AccountStatementLine> lines;
  final String currencyCode;
}

class AccountStatementLabels {
  const AccountStatementLabels({
    required this.title,
    required this.periodLabel,
    required this.dateLabel,
    required this.referenceLabel,
    required this.descriptionLabel,
    required this.debitLabel,
    required this.creditLabel,
    required this.balanceLabel,
    required this.openingBalanceLabel,
    required this.closingBalanceLabel,
  });

  final String title;
  final String periodLabel;
  final String dateLabel;
  final String referenceLabel;
  final String descriptionLabel;
  final String debitLabel;
  final String creditLabel;
  final String balanceLabel;
  final String openingBalanceLabel;
  final String closingBalanceLabel;
}

class AccountStatementService {
  const AccountStatementService();

  Future<AccountStatementData> buildCustomerStatement(
    AppDatabase db, {
    required int customerId,
    required DateTime startDate,
    required DateTime endDate,
    int? branchId,
  }) async {
    final customer = await (db.select(db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingle();

    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final events = <_StatementEvent>[];

    final invoiceQuery = db.select(db.invoices)
      ..where((i) => i.customerId.equals(customerId))
      ..where((i) => i.type.equals('sale'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(rangeStart))
      ..where((i) => i.createdAt.isSmallerOrEqualValue(rangeEnd));
    if (branchId != null) {
      invoiceQuery.where((i) => i.branchId.equals(branchId));
    }
    final invoices = await invoiceQuery.get();
    for (final invoice in invoices) {
      final amount = invoice.remaining > 0 ? invoice.remaining : invoice.total;
      if (amount <= 0) continue;
      events.add(
        _StatementEvent(
          date: invoice.createdAt,
          reference: invoice.invoiceNumber,
          description: 'sale',
          debit: amount,
          credit: 0,
        ),
      );
    }

    final payments = await (db.select(db.payments)
          ..where((p) => p.customerId.equals(customerId))
          ..where((p) => p.createdAt.isBiggerOrEqualValue(rangeStart))
          ..where((p) => p.createdAt.isSmallerOrEqualValue(rangeEnd)))
        .get();
    for (final payment in payments) {
      events.add(
        _StatementEvent(
          date: payment.createdAt,
          reference: payment.reference ?? 'PAY-${payment.id}',
          description: payment.paymentMethod,
          debit: 0,
          credit: payment.amount,
        ),
      );
    }

    final debtsQuery = db.select(db.debts)
      ..where((d) => d.customerId.equals(customerId));
    if (branchId != null) {
      debtsQuery.where((d) => d.branchId.equals(branchId));
    }
    final debts = await debtsQuery.get();
    final debtIds = debts.map((d) => d.id).toList();
    if (debtIds.isNotEmpty) {
      final debtPayments = await (db.select(db.debtPayments)
            ..where((dp) => dp.debtId.isIn(debtIds))
            ..where((dp) => dp.createdAt.isBiggerOrEqualValue(rangeStart))
            ..where((dp) => dp.createdAt.isSmallerOrEqualValue(rangeEnd)))
          .get();
      for (final dp in debtPayments) {
        events.add(
          _StatementEvent(
            date: dp.createdAt,
            reference: 'DEBT-PAY-${dp.id}',
            description: dp.paymentMethod,
            debit: 0,
            credit: dp.amount,
          ),
        );
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    double periodDebit = 0;
    double periodCredit = 0;
    for (final e in events) {
      periodDebit += e.debit;
      periodCredit += e.credit;
    }
    final openingBalance = customer.balance - periodDebit + periodCredit;
    var running = openingBalance;
    final lines = <AccountStatementLine>[];
    for (final e in events) {
      running += e.debit - e.credit;
      lines.add(
        AccountStatementLine(
          date: e.date,
          reference: e.reference,
          description: e.description,
          debit: e.debit,
          credit: e.credit,
          balance: running,
        ),
      );
    }

    return AccountStatementData(
      partyName: customer.name,
      startDate: rangeStart,
      endDate: rangeEnd,
      openingBalance: openingBalance,
      closingBalance: customer.balance,
      lines: lines,
      currencyCode: CurrencyConversion.baseCurrencyCode,
    );
  }

  Future<AccountStatementData> buildSupplierStatement(
    AppDatabase db, {
    required int supplierId,
    required DateTime startDate,
    required DateTime endDate,
    int? branchId,
  }) async {
    final supplier = await (db.select(db.suppliers)
          ..where((s) => s.id.equals(supplierId)))
        .getSingle();

    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final events = <_StatementEvent>[];

    final invoiceQuery = db.select(db.invoices)
      ..where((i) => i.supplierId.equals(supplierId))
      ..where((i) => i.type.equals('purchase'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(rangeStart))
      ..where((i) => i.createdAt.isSmallerOrEqualValue(rangeEnd));
    if (branchId != null) {
      invoiceQuery.where((i) => i.branchId.equals(branchId));
    }
    final invoices = await invoiceQuery.get();
    for (final invoice in invoices) {
      final amount = invoice.remaining > 0 ? invoice.remaining : invoice.total;
      if (amount <= 0) continue;
      events.add(
        _StatementEvent(
          date: invoice.createdAt,
          reference: invoice.invoiceNumber,
          description: 'purchase',
          debit: 0,
          credit: amount,
        ),
      );
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    double periodCredit = 0;
    for (final e in events) {
      periodCredit += e.credit;
    }
    final openingBalance = supplier.balance + periodCredit;
    var running = openingBalance;
    final lines = <AccountStatementLine>[];
    for (final e in events) {
      running -= e.credit;
      lines.add(
        AccountStatementLine(
          date: e.date,
          reference: e.reference,
          description: e.description,
          debit: e.debit,
          credit: e.credit,
          balance: running,
        ),
      );
    }

    return AccountStatementData(
      partyName: supplier.name,
      startDate: rangeStart,
      endDate: rangeEnd,
      openingBalance: openingBalance,
      closingBalance: supplier.balance,
      lines: lines,
      currencyCode: CurrencyConversion.baseCurrencyCode,
    );
  }

  Future<void> printStatement({
    required AccountStatementData data,
    required AccountStatementLabels labels,
    String? companyName,
    String? companyPhone,
    String? companyAddress,
  }) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            labels.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(data.partyName),
          pw.Text(
            '${labels.periodLabel}: ${dateFmt.format(data.startDate)} — ${dateFmt.format(data.endDate)}',
          ),
          if (companyName != null) pw.Text(companyName),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${labels.openingBalanceLabel}: ${data.openingBalance.toStringAsFixed(2)}',
              ),
              pw.Text(
                '${labels.closingBalanceLabel}: ${data.closingBalance.toStringAsFixed(2)}',
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              labels.dateLabel,
              labels.referenceLabel,
              labels.descriptionLabel,
              labels.debitLabel,
              labels.creditLabel,
              labels.balanceLabel,
            ],
            data: data.lines
                .map(
                  (line) => [
                    dateFmt.format(line.date),
                    line.reference,
                    line.description,
                    line.debit > 0 ? line.debit.toStringAsFixed(2) : '',
                    line.credit > 0 ? line.credit.toStringAsFixed(2) : '',
                    line.balance.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  Future<void> printCustomerStatement(
    AppDatabase db, {
    required int customerId,
    required DateTime startDate,
    required DateTime endDate,
    required AccountStatementLabels labels,
    int? branchId,
  }) async {
    final data = await buildCustomerStatement(
      db,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      branchId: branchId,
    );
    final company = await const CompanyProfileService().load(db);
    await printStatement(
      data: data,
      labels: labels,
      companyName: company.name,
      companyPhone: company.phone,
      companyAddress: company.address,
    );
  }

  Future<void> printSupplierStatement(
    AppDatabase db, {
    required int supplierId,
    required DateTime startDate,
    required DateTime endDate,
    required AccountStatementLabels labels,
    int? branchId,
  }) async {
    final data = await buildSupplierStatement(
      db,
      supplierId: supplierId,
      startDate: startDate,
      endDate: endDate,
      branchId: branchId,
    );
    final company = await const CompanyProfileService().load(db);
    await printStatement(
      data: data,
      labels: labels,
      companyName: company.name,
      companyPhone: company.phone,
      companyAddress: company.address,
    );
  }
}

class _StatementEvent {
  const _StatementEvent({
    required this.date,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
  });

  final DateTime date;
  final String reference;
  final String description;
  final double debit;
  final double credit;
}
