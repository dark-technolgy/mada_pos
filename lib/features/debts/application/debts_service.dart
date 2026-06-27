import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';

class DebtsLoadResult {
  const DebtsLoadResult({
    required this.debts,
    required this.customers,
    required this.suppliers,
    required this.currencyMap,
    required this.displayCurrencyCode,
    required this.displayExchangeRate,
  });

  final List<Debt> debts;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final Map<String, Currency> currencyMap;
  final String displayCurrencyCode;
  final double displayExchangeRate;
}

class DebtsService {
  const DebtsService();

  Future<DebtsLoadResult> loadScreenData(
    AppDatabase db, {
    int? branchId,
  }) async {
    final query = db.select(db.debts)
      ..orderBy([(debt) => OrderingTerm.desc(debt.createdAt)]);
    if (branchId != null) {
      query.where((debt) => debt.branchId.equals(branchId));
    }
    final debts = await query.get();
    final customers = await db.select(db.customers).get();
    final suppliers = await db.select(db.suppliers).get();
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    return DebtsLoadResult(
      debts: debts,
      customers: customers,
      suppliers: suppliers,
      currencyMap: currencyMap,
      displayCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      displayExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
    );
  }

  List<Debt> filterDebts({
    required List<Debt> debts,
    required int tabIndex,
    required String searchQuery,
    required String Function(Debt debt) personNameResolver,
  }) {
    final type = tabIndex == 0 ? 'receivable' : 'payable';

    return debts.where((debt) {
      if (debt.type != type) return false;
      if (searchQuery.isEmpty) return true;
      return personNameResolver(debt).contains(searchQuery);
    }).toList();
  }

  double totalReceivable(List<Debt> debts, Map<String, Currency> currencyMap) {
    return debts
        .where((debt) => debt.type == 'receivable')
        .fold<double>(
          0.0,
          (sum, debt) =>
              sum +
              CurrencyConversion.toBase(
                debt.remainingAmount,
                currencyCode: debt.currencyCode,
                currencies: currencyMap,
              ),
        );
  }

  double totalPayable(List<Debt> debts, Map<String, Currency> currencyMap) {
    return debts
        .where((debt) => debt.type == 'payable')
        .fold<double>(
          0.0,
          (sum, debt) =>
              sum +
              CurrencyConversion.toBase(
                debt.remainingAmount,
                currencyCode: debt.currencyCode,
                currencies: currencyMap,
              ),
        );
  }
}
