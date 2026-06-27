import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';

class ExpensesLoadResult {
  const ExpensesLoadResult({
    required this.expenses,
    required this.currencyMap,
    required this.displayCurrencyCode,
    required this.displayExchangeRate,
  });

  final List<Expense> expenses;
  final Map<String, Currency> currencyMap;
  final String displayCurrencyCode;
  final double displayExchangeRate;
}

class ExpenseFormPayload {
  const ExpenseFormPayload({
    required this.category,
    required this.amount,
    required this.currencyCode,
    this.description,
    this.userId,
    this.branchId,
  });

  final String category;
  final double amount;
  final String currencyCode;
  final String? description;
  final int? userId;
  final int? branchId;
}

class ExpensesService {
  const ExpensesService();

  Future<ExpensesLoadResult> loadScreenData(
    AppDatabase db, {
    int? branchId,
  }) async {
    final query = db.select(db.expenses)
      ..orderBy([(expense) => OrderingTerm.desc(expense.createdAt)]);
    if (branchId != null) {
      query.where((expense) => expense.branchId.equals(branchId));
    }
    final expenses = await query.get();
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    return ExpensesLoadResult(
      expenses: expenses,
      currencyMap: currencyMap,
      displayCurrencyCode:
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
      displayExchangeRate: CurrencyConversion.normalizeRate(
        defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode,
        defaultCurrency?.exchangeRate,
      ),
    );
  }

  List<Expense> filterExpenses({
    required List<Expense> expenses,
    required String searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return expenses
        .where((expense) {
          if (startDate != null && expense.createdAt.isBefore(startDate)) {
            return false;
          }
          if (endDate != null &&
              expense.createdAt.isAfter(endDate.add(const Duration(days: 1)))) {
            return false;
          }
          if (searchQuery.isNotEmpty) {
            return (expense.description ?? '').contains(searchQuery) ||
                expense.category.contains(searchQuery);
          }
          return true;
        })
        .toList(growable: false);
  }

  double totalExpensesBase(
    List<Expense> expenses,
    Map<String, Currency> currencyMap,
  ) {
    return expenses.fold<double>(
      0.0,
      (sum, expense) =>
          sum +
          CurrencyConversion.toBase(
            expense.amount,
            currencyCode: expense.currencyCode,
            currencies: currencyMap,
          ),
    );
  }

  Future<void> createExpense(
    AppDatabase db, {
    required ExpenseFormPayload payload,
  }) {
    return db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            category: payload.category,
            amount: payload.amount,
            currencyCode: Value(payload.currencyCode),
            description: Value(payload.description),
            userId: Value(payload.userId),
            branchId: Value(payload.branchId),
          ),
        );
  }

  Future<void> deleteExpense(AppDatabase db, int expenseId) {
    return (db.delete(
      db.expenses,
    )..where((expense) => expense.id.equals(expenseId))).go();
  }
}
