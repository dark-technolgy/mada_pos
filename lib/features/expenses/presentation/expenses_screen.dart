import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<Expense> _expenses = [];
  List<Expense> _filtered = [];
  Map<String, Currency> _currencyMap = const {};
  String _displayCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _displayExchangeRate = 1.0;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final expenses = await (db.select(
      db.expenses,
    )..orderBy([(e) => OrderingTerm.desc(e.createdAt)])).get();
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);
    setState(() {
      _expenses = expenses;
      _currencyMap = currencyMap;
      _displayCurrencyCode =
          defaultCurrency?.code ?? CurrencyConversion.baseCurrencyCode;
      _displayExchangeRate = CurrencyConversion.normalizeRate(
        _displayCurrencyCode,
        defaultCurrency?.exchangeRate,
      );
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _expenses.where((e) {
      if (_startDate != null && e.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null &&
          e.createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return (e.description ?? '').contains(_searchQuery) ||
            e.category.contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  double get _totalExpensesBase => _filtered.fold(
    0.0,
    (sum, e) =>
        sum +
        CurrencyConversion.toBase(
          e.amount,
          currencyCode: e.currencyCode,
          currencies: _currencyMap,
        ),
  );

  String _formatDisplayBaseAmount(double baseAmount) {
    final displayAmount = CurrencyConversion.fromBase(
      baseAmount,
      currencyCode: _displayCurrencyCode,
      exchangeRate: _displayExchangeRate,
    );
    return CurrencyFormatter.format(displayAmount, _displayCurrencyCode);
  }

  String _formatExpenseAmount(Expense expense) {
    return CurrencyFormatter.format(
      expense.amount,
      expense.currencyCode,
      symbol: _currencyMap[expense.currencyCode]?.symbol,
    );
  }

  Future<void> _addExpense() async {
    final l10n = context.l10n;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var selectedCurrencyCode = _displayCurrencyCode;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 450,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.addExpenseTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: '${l10n.expenseDescription} *',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          decoration: InputDecoration(
                            labelText: '${l10n.amount} *',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _currencyMap.containsKey(selectedCurrencyCode)
                              ? selectedCurrencyCode
                              : null,
                          decoration: InputDecoration(labelText: l10n.currency),
                          items: _currencyMap.values
                              .map(
                                (currency) => DropdownMenuItem<String>(
                                  value: currency.code,
                                  child: Text(
                                    '${currency.code} - ${currency.symbol}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedCurrencyCode = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.category,
                      hintText: l10n.categoryHintExample,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(labelText: l10n.notes),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      final amount = double.tryParse(amountCtrl.text);
      if (descCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fillRequiredFields),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final db = ref.read(databaseProvider);
      final user = ref.read(currentUserProvider);

      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              category: categoryCtrl.text.trim().isEmpty
                  ? l10n.defaultExpenseCategory
                  : categoryCtrl.text.trim(),
              amount: amount,
              currencyCode: Value(selectedCurrencyCode),
              description: Value(descCtrl.text.trim()),
              userId: Value(user?.id),
            ),
          );

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.expenseAddedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    descCtrl.dispose();
    amountCtrl.dispose();
    categoryCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.deleteExpenseTitle,
      message: l10n.deleteExpenseMessage,
      confirmText: l10n.delete,
    );
    if (confirmed) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.expenses,
      )..where((e) => e.id.equals(expense.id))).go();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.expenses,
            subtitle: _formatDisplayBaseAmount(_totalExpensesBase),
            actions: [
              ElevatedButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addExpenseButton),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    hintText: l10n.searchExpenses,
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _applyFilter();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Date range
                OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : null,
                    );
                    if (range != null) {
                      setState(() {
                        _startDate = range.start;
                        _endDate = range.end;
                        _applyFilter();
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _startDate != null
                        ? '${DateFormatter.formatDate(_startDate!)} - ${DateFormatter.formatDate(_endDate!)}'
                        : l10n.selectPeriod,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.money_off_outlined,
                    title: l10n.noExpenses,
                    subtitle: l10n.expensesWillAppearHere,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightBg,
                            ),
                            columns: [
                              DataColumn(label: Text(l10n.expenseDescription)),
                              DataColumn(label: Text(l10n.category)),
                              DataColumn(label: Text(l10n.date)),
                              DataColumn(
                                label: Text(l10n.amount),
                                numeric: true,
                              ),
                              DataColumn(label: Text(l10n.actions)),
                            ],
                            rows: _filtered.map((expense) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      expense.description ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        expense.category,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatDate(
                                        expense.createdAt,
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatExpenseAmount(expense),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      onPressed: () => _deleteExpense(expense),
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
