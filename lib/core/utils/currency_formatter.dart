import 'package:intl/intl.dart';

import '../database/database.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String formatIQD(double amount) {
    final formatter = NumberFormat('#,###', 'ar');
    return '${formatter.format(amount.round())} د.ع';
  }

  static String formatUSD(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en');
    return '\$${formatter.format(amount)}';
  }

  static String format(double amount, String currencyCode, {String? symbol}) {
    return switch (currencyCode) {
      'IQD' => formatIQD(amount),
      'USD' => formatUSD(amount),
      _ =>
        symbol != null && symbol.isNotEmpty
            ? '${NumberFormat('#,##0.00').format(amount)} $symbol'
            : '${NumberFormat('#,##0.00').format(amount)} $currencyCode',
    };
  }

  static String formatCurrency(double amount, Currency currency) {
    return format(amount, currency.code, symbol: currency.symbol);
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
