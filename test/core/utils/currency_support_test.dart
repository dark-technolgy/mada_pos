import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/utils/currency_conversion.dart';
import 'package:mada_pos/core/utils/currency_formatter.dart';

Currency _currency({
  required int id,
  required String code,
  required String symbol,
  required double exchangeRate,
  required bool isDefault,
}) {
  return Currency(
    id: id,
    code: code,
    nameAr: code,
    nameEn: code,
    symbol: symbol,
    exchangeRate: exchangeRate,
    isDefault: isDefault,
    updatedAt: DateTime(2026, 3, 8),
  );
}

void main() {
  group('Currency database seed', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('seeds IQD as default and USD with exchange rate', () async {
      final currencies = await database.select(database.currencies).get();

      expect(currencies, hasLength(2));

      final iqd = currencies.firstWhere((currency) => currency.code == 'IQD');
      final usd = currencies.firstWhere((currency) => currency.code == 'USD');

      expect(iqd.isDefault, isTrue);
      expect(iqd.exchangeRate, 1.0);
      expect(usd.isDefault, isFalse);
      expect(usd.exchangeRate, 1480.0);
    });
  });

  group('CurrencyConversion', () {
    final currencies = [
      _currency(
        id: 1,
        code: 'IQD',
        symbol: 'د.ع',
        exchangeRate: 1.0,
        isDefault: true,
      ),
      _currency(
        id: 2,
        code: 'USD',
        symbol: r'$',
        exchangeRate: 1480.0,
        isDefault: false,
      ),
    ];
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };

    test('findDefaultCurrency prefers explicit default', () {
      final defaultCurrency = CurrencyConversion.findDefaultCurrency(
        currencies,
      );

      expect(defaultCurrency?.code, 'IQD');
    });

    test('converts from USD to base and back without drifting materially', () {
      final baseAmount = CurrencyConversion.toBase(
        12.5,
        currencyCode: 'USD',
        currencies: currencyMap,
      );
      final convertedBack = CurrencyConversion.fromBase(
        baseAmount,
        currencyCode: 'USD',
        currencies: currencyMap,
      );

      expect(baseAmount, closeTo(18500.0, 0.0001));
      expect(convertedBack, closeTo(12.5, 0.0001));
    });

    test('normalizeRate keeps IQD at 1 and guards invalid foreign rates', () {
      expect(CurrencyConversion.normalizeRate('IQD', 999), 1.0);
      expect(CurrencyConversion.normalizeRate('USD', 0), 1.0);
      expect(CurrencyConversion.normalizeRate('USD', -5), 1.0);
      expect(CurrencyConversion.normalizeRate('USD', 1480), 1480.0);
    });
  });

  group('CurrencyFormatter', () {
    test('formats IQD without decimals', () {
      expect(CurrencyFormatter.format(15250.75, 'IQD'), '15,251 د.ع');
    });

    test('formats USD with decimals', () {
      expect(CurrencyFormatter.format(12.5, 'USD'), r'$12.50');
    });

    test('formats custom currency with provided symbol fallback', () {
      expect(CurrencyFormatter.format(42.5, 'EUR', symbol: '€'), '42.50 €');
    });
  });
}
