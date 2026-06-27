import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
import '../application/debts_service.dart';
import 'widgets/debt_payment_dialog.dart';
import 'widgets/debts_sections.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DebtsService _debtsService = const DebtsService();
  List<Debt> _debts = [];
  List<Debt> _filtered = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  Map<String, Currency> _currencyMap = const {};
  String _displayCurrencyCode = CurrencyConversion.baseCurrencyCode;
  double _displayExchangeRate = 1.0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _applyFilter();
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final result = await _debtsService.loadScreenData(
      db,
      branchId: ref.read(activeBranchIdProvider),
    );

    setState(() {
      _debts = result.debts;
      _customers = result.customers;
      _suppliers = result.suppliers;
      _currencyMap = result.currencyMap;
      _displayCurrencyCode = result.displayCurrencyCode;
      _displayExchangeRate = result.displayExchangeRate;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _debtsService.filterDebts(
      debts: _debts,
      tabIndex: _tabController.index,
      searchQuery: _searchQuery,
      personNameResolver: _getPersonName,
    );
  }

  String _getPersonName(Debt debt) {
    final l10n = context.l10n;
    if (debt.customerId != null) {
      final c = _customers.where((c) => c.id == debt.customerId);
      return c.isNotEmpty ? c.first.name : l10n.unknown;
    }
    if (debt.supplierId != null) {
      final s = _suppliers.where((s) => s.id == debt.supplierId);
      return s.isNotEmpty ? s.first.name : l10n.unknown;
    }
    return l10n.unspecified;
  }

  double get _totalReceivable => _debts.isEmpty
      ? 0.0
      : _debtsService.totalReceivable(_debts, _currencyMap);

  double get _totalPayable =>
      _debts.isEmpty ? 0.0 : _debtsService.totalPayable(_debts, _currencyMap);

  String _formatDisplayBaseAmount(double baseAmount) {
    final displayAmount = CurrencyConversion.fromBase(
      baseAmount,
      currencyCode: _displayCurrencyCode,
      exchangeRate: _displayExchangeRate,
    );
    return CurrencyFormatter.format(displayAmount, _displayCurrencyCode);
  }

  String _formatDebtAmount(double amount, String currencyCode) {
    return CurrencyFormatter.format(
      amount,
      currencyCode,
      symbol: _currencyMap[currencyCode]?.symbol,
    );
  }

  Future<void> _addPayment(Debt debt) async {
    final l10n = context.l10n;
    final result = await showDebtPaymentDialog(
      context: context,
      l10n: l10n,
      remainingAmountLabel: l10n.remainingAmountLabel(
        _formatDebtAmount(debt.remainingAmount, debt.currencyCode),
      ),
    );

    if (result != null) {
      if (result.amount > debt.remainingAmount) {
        if (mounted) {
          AppFeedback.error(context, l10n.invalidAmount);
        }
        return;
      }

      final db = ref.read(databaseProvider);
      final user = ref.read(currentUserProvider);

      await db
          .into(db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              debtId: debt.id,
              amount: result.amount,
              notes: Value(result.notes),
              userId: Value(user?.id),
            ),
          );

      final paidSoFar = debt.originalAmount - debt.remainingAmount;
      final newPaid = paidSoFar + result.amount;
      final newRemaining = debt.originalAmount - newPaid;
      await (db.update(db.debts)..where((d) => d.id.equals(debt.id))).write(
        DebtsCompanion(
          remainingAmount: Value(newRemaining),
          status: Value(newRemaining <= 0 ? 'paid' : 'partial'),
        ),
      );

      _loadData();
      if (mounted) {
        AppFeedback.success(context, l10n.paymentRecordedSuccessfully);
      }
    }
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
            title: l10n.manageDebts,
            subtitle: '${_filtered.length} ${l10n.debts}',
          ),
          DebtsSummarySection(
            l10n: l10n,
            isDark: isDark,
            totalReceivable: _totalReceivable,
            totalPayable: _totalPayable,
            netDebts: _totalReceivable - _totalPayable,
            formatDisplayBaseAmount: _formatDisplayBaseAmount,
          ),
          const SizedBox(height: 16),
          DebtsTabsSection(
            controller: _tabController,
            isDark: isDark,
            l10n: l10n,
          ),
          const SizedBox(height: 12),
          DebtsSearchSection(
            l10n: l10n,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilter();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DebtsTableSection(
              l10n: l10n,
              isDark: isDark,
              debts: _filtered,
              personNameFor: _getPersonName,
              formatDebtAmount: _formatDebtAmount,
              onAddPayment: _addPayment,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
