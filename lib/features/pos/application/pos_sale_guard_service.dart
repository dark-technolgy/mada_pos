import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_pricing.dart';

enum PosSaleGuardIssueKind {
  belowCost,
  highDiscount,
  unusuallyHighTotal,
}

class PosSaleGuardIssue {
  const PosSaleGuardIssue({
    required this.kind,
    required this.productName,
    this.detail,
  });

  final PosSaleGuardIssueKind kind;
  final String productName;
  final String? detail;
}

class PosSaleGuardResult {
  const PosSaleGuardResult({required this.issues});

  final List<PosSaleGuardIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  bool get hasBlockingIssues =>
      issues.any((i) => i.kind == PosSaleGuardIssueKind.belowCost);
}

class PosSaleGuardService {
  const PosSaleGuardService({
    this.maxTotalDiscountPercent = 50,
    this.unusualSaleMultiplier = 3,
  });

  final double maxTotalDiscountPercent;
  final double unusualSaleMultiplier;

  Future<PosSaleGuardResult> evaluate({
    required AppDatabase db,
    required List<PosCartItem> cart,
    required PosPricingSummary summary,
    required String currencyCode,
    required double exchangeRate,
    int? customerId,
  }) async {
    final issues = <PosSaleGuardIssue>[];

    for (final item in cart) {
      final unitBase = CurrencyConversion.toBase(
        item.unitPrice,
        currencyCode: currencyCode,
        exchangeRate: exchangeRate,
      );
      if (unitBase < item.product.purchasePrice - 0.001) {
        issues.add(
          PosSaleGuardIssue(
            kind: PosSaleGuardIssueKind.belowCost,
            productName: item.product.nameAr,
            detail: null,
          ),
        );
      }
    }

    if (summary.grossSubtotal > 0) {
      final totalDiscount =
          summary.lineDiscountTotal + summary.invoiceDiscountAmount;
      final discountPercent = (totalDiscount / summary.grossSubtotal) * 100;
      if (discountPercent > maxTotalDiscountPercent) {
        issues.add(
          PosSaleGuardIssue(
            kind: PosSaleGuardIssueKind.highDiscount,
            productName: '',
            detail: discountPercent.toStringAsFixed(0),
          ),
        );
      }
    }

    final avgSale = await _averageSaleAmount(db, customerId: customerId);
    if (avgSale > 0 && summary.total > avgSale * unusualSaleMultiplier) {
      issues.add(
        PosSaleGuardIssue(
          kind: PosSaleGuardIssueKind.unusuallyHighTotal,
          productName: '',
          detail: avgSale.toStringAsFixed(0),
        ),
      );
    }

    return PosSaleGuardResult(issues: issues);
  }

  Future<double> _averageSaleAmount(
    AppDatabase db, {
    int? customerId,
  }) async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    var query = db.select(db.invoices)
      ..where((i) => i.type.equals('sale'))
      ..where((i) => i.status.isNotIn(['cancelled', 'draft', 'held']))
      ..where((i) => i.createdAt.isBiggerOrEqualValue(since));

    if (customerId != null) {
      query = query..where((i) => i.customerId.equals(customerId));
    }

    final sales = await query.get();
    if (sales.isEmpty) return 0;

    final total = sales.fold<double>(
      0,
      (sum, inv) =>
          sum +
          CurrencyConversion.toBase(
            inv.total,
            currencyCode: inv.currencyCode,
            exchangeRate: inv.exchangeRate,
          ),
    );
    return total / sales.length;
  }
}
