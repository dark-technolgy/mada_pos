import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final customers = await (db.select(
      db.customers,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
    setState(() {
      _customers = customers;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _customers.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.contains(_searchQuery) ||
          (c.phone?.contains(_searchQuery) ?? false) ||
          (c.email?.contains(_searchQuery) ?? false);
    }).toList();
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
      await (db.delete(
        db.customers,
      )..where((c) => c.id.equals(customer.id))).go();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchField(
              hintText: l10n.searchByNamePhoneEmail,
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilter();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: l10n.noCustomers,
                    subtitle: l10n.startByAddingNewCustomers,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 350,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final customer = _filtered[index];
                        return _buildCustomerCard(customer, isDark);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, bool isDark) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (customer.phone != null)
                      Text(
                        customer.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      l10n.delete,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                onSelected: (action) {
                  if (action == 'edit') {
                    context.go('/customers/edit/${customer.id}');
                  }
                  if (action == 'delete') {
                    _deleteCustomer(customer);
                  }
                },
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (customer.email != null) ...[
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customer.email!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.customerBalanceLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                CurrencyFormatter.formatIQD(customer.balance),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: customer.balance > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
