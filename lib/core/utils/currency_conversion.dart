import '../database/database.dart';

class CurrencyConversion {
  CurrencyConversion._();

  static const String baseCurrencyCode = 'IQD';

  static Currency? findDefaultCurrency(List<Currency> currencies) {
    if (currencies.isEmpty) return null;
    return currencies.where((currency) => currency.isDefault).firstOrNull ??
        currencies
            .where((currency) => currency.code == baseCurrencyCode)
            .firstOrNull ??
        currencies.first;
  }

  static Currency? findByCode(List<Currency> currencies, String code) {
    return currencies.where((currency) => currency.code == code).firstOrNull;
  }

  static double normalizeRate(String currencyCode, double? exchangeRate) {
    if (currencyCode == baseCurrencyCode) return 1.0;
    if (exchangeRate == null || exchangeRate <= 0) return 1.0;
    return exchangeRate;
  }

  static double toBase(
    double amount, {
    required String currencyCode,
    double? exchangeRate,
    Map<String, Currency>? currencies,
  }) {
    final rate = exchangeRate ?? currencies?[currencyCode]?.exchangeRate;
    return amount * normalizeRate(currencyCode, rate);
  }

  static double fromBase(
    double amount, {
    required String currencyCode,
    double? exchangeRate,
    Map<String, Currency>? currencies,
  }) {
    final rate = normalizeRate(
      currencyCode,
      exchangeRate ?? currencies?[currencyCode]?.exchangeRate,
    );
    if (rate == 0) return amount;
    return amount / rate;
  }
}
