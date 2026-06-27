import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../application/customers_service.dart';
import 'widgets/account_statement_dialog.dart';
import 'widgets/customers_sections.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  String _searchQuery = '';
  final CustomersService _customersService = const CustomersService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final customers = await _customersService.loadCustomers(db);
    setState(() {
      _customers = customers;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _customersService.filterCustomers(
      customers: _customers,
      searchQuery: _searchQuery,
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.deleteCustomerTitle,
      message: l10n.deleteCustomerMessage(customer.name),
      confirmText: l10n.delete,
    );
    if (confirmed) {
      final db = ref.read(databaseProvider);
      await _customersService.deleteCustomer(db, customer.id);
      await _loadData();
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
            title: l10n.customers,
            subtitle: '${_filtered.length} ${l10n.customers}',
            actions: [
              ElevatedButton.icon(
                onPressed: () => context.go('/customers/add'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addCustomer),
              ),
            ],
          ),
          CustomersSearchSection(
            searchHint: l10n.searchByNamePhoneEmail,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilter();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomersGridSection(
              customers: _filtered,
              isDark: isDark,
              noCustomersLabel: l10n.noCustomers,
              emptySubtitle: l10n.startByAddingNewCustomers,
              customerBalanceLabel: l10n.customerBalanceLabel,
              editLabel: l10n.edit,
              deleteLabel: l10n.delete,
              onEditCustomer: (customer) {
                context.go('/customers/edit/${customer.id}');
              },
              onStatementCustomer: (customer) =>
                  AccountStatementDialog.showForCustomer(
                context,
                customerId: customer.id,
                customerName: customer.name,
              ),
              statementLabel: l10n.accountStatement,
              onDeleteCustomer: _deleteCustomer,
            ),
          ),
        ],
      ),
    );
  }
}
