import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/features/pos/domain/pos_pricing.dart';

void main() {
  group('PosPricing', () {
    test('clamps line discount between zero and gross total', () {
      expect(PosPricing.clampDiscountAmount(-5, 100), 0);
      expect(PosPricing.clampDiscountAmount(15, 100), 15);
      expect(PosPricing.clampDiscountAmount(150, 100), 100);
    });

    test('normalizes line totals after quantity change', () {
      final line = PosPricing.normalizeLine(
        quantity: 2,
        unitPrice: 25,
        discount: 80,
      );

      expect(line.grossTotal, 50);
      expect(line.clampedDiscount, 50);
      expect(line.netTotal, 0);
    });

    test('summarizes fixed invoice discount after item discounts', () {
      final summary = PosPricing.summarize(
        lines: const [
          PosLinePricing(quantity: 2, unitPrice: 10, discount: 3),
          PosLinePricing(quantity: 1, unitPrice: 5, discount: 0),
        ],
        invoiceDiscount: 4,
        discountType: 'fixed',
      );

      expect(summary.grossSubtotal, 25);
      expect(summary.lineDiscountTotal, 3);
      expect(summary.subtotal, 22);
      expect(summary.invoiceDiscountAmount, 4);
      expect(summary.taxableBase, 18);
      expect(summary.taxAmount, 0);
      expect(summary.total, 18);
    });

    test('summarizes percentage invoice discount after item discounts', () {
      final summary = PosPricing.summarize(
        lines: const [
          PosLinePricing(quantity: 1, unitPrice: 100, discount: 10),
        ],
        invoiceDiscount: 10,
        discountType: 'percentage',
      );

      expect(summary.grossSubtotal, 100);
      expect(summary.lineDiscountTotal, 10);
      expect(summary.subtotal, 90);
      expect(summary.invoiceDiscountAmount, 9);
      expect(summary.taxableBase, 81);
      expect(summary.taxAmount, 0);
      expect(summary.total, 81);
    });

    test('caps invoice discount to subtotal', () {
      final summary = PosPricing.summarize(
        lines: const [PosLinePricing(quantity: 1, unitPrice: 20, discount: 5)],
        invoiceDiscount: 50,
        discountType: 'fixed',
      );

      expect(summary.subtotal, 15);
      expect(summary.invoiceDiscountAmount, 15);
      expect(summary.total, 0);
    });
  });
}
