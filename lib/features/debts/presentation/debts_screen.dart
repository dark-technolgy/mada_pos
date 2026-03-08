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
import '../../../shared/widgets/empty_state.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    final debts = await (db.select(
      db.debts,
    )..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).get();
    final customers = await db.select(db.customers).get();
    final suppliers = await db.select(db.suppliers).get();
    final currencies = await db.select(db.currencies).get();
    final currencyMap = {
      for (final currency in currencies) currency.code: currency,
    };
    final defaultCurrency = CurrencyConversion.findDefaultCurrency(currencies);

    setState(() {
      _debts = debts;
      _customers = customers;
      _suppliers = suppliers;
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
    final type = _tabController.index == 0 ? 'receivable' : 'payable';
    _filtered = _debts.where((d) {
      if (d.type != type) return false;
      if (_searchQuery.isNotEmpty) {
        final name = _getPersonName(d);
        return name.contains(_searchQuery);
      }
      return true;
    }).toList();
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

  double get _totalReceivable => _debts
      .where((d) => d.type == 'receivable')
      .fold(
        0.0,
        (sum, d) => sum + _debtBaseAmount(d.remainingAmount, d.currencyCode),
      );

  double get _totalPayable => _debts
      .where((d) => d.type == 'payable')
      .fold(
        0.0,
        (sum, d) => sum + _debtBaseAmount(d.remainingAmount, d.currencyCode),
      );

  double _debtBaseAmount(double amount, String currencyCode) {
    return CurrencyConversion.toBase(
      amount,
      currencyCode: currencyCode,
      currencies: _currencyMap,
    );
  }

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
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.recordPayment,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.remainingAmountLabel(
                    _formatDebtAmount(debt.remainingAmount, debt.currencyCode),
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(labelText: '${l10n.amount} *'),
                  keyboardType: TextInputType.number,
                  autofocus: true,
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
                      child: Text(l10n.record),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      final amount = double.tryParse(amountCtrl.text);
      if (amount == null || amount <= 0 || amount > debt.remainingAmount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidAmount),
              backgroundColor: AppColors.error,
            ),
          );
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
              amount: amount,
              notes: Value(
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              ),
              userId: Value(user?.id),
            ),
          );

      final paidSoFar = debt.originalAmount - debt.remainingAmount;
      final newPaid = paidSoFar + amount;
      final newRemaining = debt.originalAmount - newPaid;
      await (db.update(db.debts)..where((d) => d.id.equals(debt.id))).write(
        DebtsCompanion(
          remainingAmount: Value(newRemaining),
          status: Value(newRemaining <= 0 ? 'paid' : 'partial'),
        ),
      );

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paymentRecordedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    amountCtrl.dispose();
    notesCtrl.dispose();
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
            title: l10n.manageDebts,
            subtitle: '${_filtered.length} ${l10n.debts}',
          ),
          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSummaryCard(
                  l10n.receivablesDue,
                  _totalReceivable,
                  Icons.arrow_downward_rounded,
                  AppColors.success,
                  isDark,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  l10n.payablesDue,
                  _totalPayable,
                  Icons.arrow_upward_rounded,
                  AppColors.error,
                  isDark,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  l10n.netDebts,
                  _totalReceivable - _totalPayable,
                  Icons.balance_rounded,
                  AppColors.primary,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.receivablesDue),
                Tab(text: l10n.payablesDue),
              ],
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchField(
              hintText: l10n.search,
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilter();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.noDebts,
                    subtitle: l10n.debtsWillAppearHere,
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
                              DataColumn(label: Text(l10n.person)),
                              DataColumn(label: Text(l10n.date)),
                              DataColumn(label: Text(l10n.amount)),
                              DataColumn(label: Text(l10n.paid)),
                              DataColumn(label: Text(l10n.remaining)),
                              DataColumn(label: Text(l10n.status)),
                              DataColumn(label: Text(l10n.actions)),
                            ],
                            rows: _filtered.map((debt) {
                              final statusColor = debt.status == 'paid'
                                  ? AppColors.success
                                  : debt.status == 'partial'
                                  ? AppColors.warning
                                  : AppColors.error;
                              final statusText = debt.status == 'paid'
                                  ? l10n.settled
                                  : debt.status == 'partial'
                                  ? l10n.partial
                                  : l10n.unpaid;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      _getPersonName(debt),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatDate(debt.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatDebtAmount(
                                        debt.originalAmount,
                                        debt.currencyCode,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatDebtAmount(
                                        debt.originalAmount -
                                            debt.remainingAmount,
                                        debt.currencyCode,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatDebtAmount(
                                        debt.remainingAmount,
                                        debt.currencyCode,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: debt.remainingAmount > 0
                                            ? AppColors.error
                                            : AppColors.success,
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
                                        color: statusColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    debt.remainingAmount > 0
                                        ? TextButton.icon(
                                            onPressed: () => _addPayment(debt),
                                            icon: const Icon(
                                              Icons.payment_rounded,
                                              size: 16,
                                            ),
                                            label: Text(
                                              context.l10n.paymentShort,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle,
                                            color: AppColors.success,
                                            size: 18,
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

  Widget _buildSummaryCard(
    String label,
    double value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDisplayBaseAmount(value.abs()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
