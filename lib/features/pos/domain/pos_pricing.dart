class PosLinePricing {
  const PosLinePricing({
    required this.quantity,
    required this.unitPrice,
    required this.discount,
  });

  final double quantity;
  final double unitPrice;
  final double discount;

  double get grossTotal => quantity * unitPrice;

  double get clampedDiscount =>
      PosPricing.clampDiscountAmount(discount, grossTotal);

  double get netTotal => grossTotal - clampedDiscount;
}

class PosPricingSummary {
  const PosPricingSummary({
    required this.grossSubtotal,
    required this.lineDiscountTotal,
    required this.subtotal,
    required this.invoiceDiscountAmount,
    required this.total,
  });

  final double grossSubtotal;
  final double lineDiscountTotal;
  final double subtotal;
  final double invoiceDiscountAmount;
  final double total;
}

class PosPricing {
  PosPricing._();

  static double clampDiscountAmount(double discountAmount, double grossTotal) {
    if (discountAmount < 0) return 0.0;
    if (discountAmount > grossTotal) return grossTotal;
    return discountAmount;
  }

  static PosLinePricing normalizeLine({
    required double quantity,
    required double unitPrice,
    required double discount,
  }) {
    return PosLinePricing(
      quantity: quantity,
      unitPrice: unitPrice,
      discount: clampDiscountAmount(discount, quantity * unitPrice),
    );
  }

  static PosPricingSummary summarize({
    required Iterable<PosLinePricing> lines,
    required double invoiceDiscount,
    required String discountType,
  }) {
    final normalizedLines = lines
        .map(
          (line) => normalizeLine(
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            discount: line.discount,
          ),
        )
        .toList(growable: false);

    final grossSubtotal = normalizedLines.fold<double>(
      0,
      (sum, line) => sum + line.grossTotal,
    );
    final lineDiscountTotal = normalizedLines.fold<double>(
      0,
      (sum, line) => sum + line.clampedDiscount,
    );
    final subtotal = grossSubtotal - lineDiscountTotal;

    final invoiceDiscountAmount = switch (discountType) {
      'percentage' => clampDiscountAmount(
        subtotal * (invoiceDiscount / 100),
        subtotal,
      ),
      _ => clampDiscountAmount(invoiceDiscount, subtotal),
    };

    return PosPricingSummary(
      grossSubtotal: grossSubtotal,
      lineDiscountTotal: lineDiscountTotal,
      subtotal: subtotal,
      invoiceDiscountAmount: invoiceDiscountAmount,
      total: subtotal - invoiceDiscountAmount,
    );
  }
}
