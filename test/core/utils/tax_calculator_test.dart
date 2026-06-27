import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/utils/tax_settings.dart';

void main() {
  group('TaxCalculator', () {
    test('adds tax on top when not included', () {
      final breakdown = TaxCalculator.compute(
        taxableBase: 100,
        settings: const TaxSettings(ratePercent: 10, taxIncluded: false),
      );

      expect(breakdown.taxAmount, 10);
      expect(breakdown.total, 110);
    });

    test('extracts tax when included in price', () {
      final breakdown = TaxCalculator.compute(
        taxableBase: 110,
        settings: const TaxSettings(ratePercent: 10, taxIncluded: true),
      );

      expect(breakdown.total, 110);
      expect(breakdown.taxAmount, closeTo(10, 0.01));
    });
  });
}
