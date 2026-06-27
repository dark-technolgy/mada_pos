import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../application/expenses_service.dart';
import 'widgets/expense_dialogs.dart';
import 'widgets/expenses_sections.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final ExpensesService _expensesService = const ExpensesService();
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
    final result = await _expensesService.loadScreenData(
      db,
      branchId: ref.read(activeBranchIdProvider),
    );
    setState(() {
      _expenses = result.expenses;
      _currencyMap = result.currencyMap;
      _displayCurrencyCode = result.displayCurrencyCode;
      _displayExchangeRate = result.displayExchangeRate;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _expensesService.filterExpenses(
      expenses: _expenses,
      searchQuery: _searchQuery,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  double get _totalExpensesBase =>
      _expensesService.totalExpensesBase(_filtered, _currencyMap);

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
    final result = await AddExpenseDialog.show(
      context,
      currencies: _currencyMap,
      initialCurrencyCode: _displayCurrencyCode,
    );

    if (result == null) return;

    if (result.description.isEmpty ||
        result.amount == null ||
        result.amount! <= 0) {
      if (mounted) {
        AppFeedback.error(context, l10n.fillRequiredFields);
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final user = ref.read(currentUserProvider);

    await _expensesService.createExpense(
      db,
      payload: ExpenseFormPayload(
        category: result.category.isEmpty
            ? l10n.defaultExpenseCategory
            : result.category,
        amount: result.amount!,
        currencyCode: result.currencyCode,
        description: result.description,
        userId: user?.id,
        branchId: ref.read(activeBranchIdProvider),
      ),
    );

    _loadData();
    if (mounted) {
      AppFeedback.success(context, l10n.expenseAddedSuccessfully);
    }
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
      await _expensesService.deleteExpense(db, expense.id);
      _loadData();
    }
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range == null) return;

    setState(() {
      _startDate = range.start;
      _endDate = range.end;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    ref.listen<int?>(activeBranchIdProvider, (previous, next) {
      if (previous != next && mounted) {
        _loadData();
      }
    });

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
            padding: EdgeInsets.zero,
            child: ExpensesFiltersSection(
              l10n: l10n,
              searchHint: l10n.searchExpenses,
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilter();
                });
              },
              periodLabel: formatExpensesPeriodLabel(
                l10n,
                startDate: _startDate,
                endDate: _endDate,
              ),
              onSelectDateRange: _selectDateRange,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ExpensesTableSection(
              l10n: l10n,
              isDark: isDark,
              expenses: _filtered,
              formatExpenseAmount: _formatExpenseAmount,
              onDeleteExpense: _deleteExpense,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
