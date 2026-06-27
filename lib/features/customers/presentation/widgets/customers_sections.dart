import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';

class CustomersSearchSection extends StatelessWidget {
  const CustomersSearchSection({
    super.key,
    required this.searchHint,
    required this.onChanged,
  });

  final String searchHint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: AppColors.cardShadow(isDark),
        ),
        child: SearchField(hintText: searchHint, onChanged: onChanged),
      ),
    );
  }
}

class CustomersGridSection extends StatelessWidget {
  const CustomersGridSection({
    super.key,
    required this.customers,
    required this.isDark,
    required this.noCustomersLabel,
    required this.emptySubtitle,
    required this.customerBalanceLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.onEditCustomer,
    required this.onStatementCustomer,
    required this.statementLabel,
    required this.onDeleteCustomer,
  });

  final List<Customer> customers;
  final bool isDark;
  final String noCustomersLabel;
  final String emptySubtitle;
  final String customerBalanceLabel;
  final String editLabel;
  final String deleteLabel;
  final ValueChanged<Customer> onEditCustomer;
  final ValueChanged<Customer> onStatementCustomer;
  final String statementLabel;
  final ValueChanged<Customer> onDeleteCustomer;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: noCustomersLabel,
        subtitle: emptySubtitle,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          childAspectRatio: 1.5,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
        ),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return CustomerCard(
            customer: customer,
            isDark: isDark,
            customerBalanceLabel: customerBalanceLabel,
            editLabel: editLabel,
            deleteLabel: deleteLabel,
            onEdit: () => onEditCustomer(customer),
            onStatement: () => onStatementCustomer(customer),
            statementLabel: statementLabel,
            onDelete: () => onDeleteCustomer(customer),
          );
        },
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.isDark,
    required this.customerBalanceLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.onEdit,
    this.onStatement,
    this.statementLabel,
    required this.onDelete,
  });

  final Customer customer;
  final bool isDark;
  final String customerBalanceLabel;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onEdit;
  final VoidCallback? onStatement;
  final String? statementLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w700,
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
                  PopupMenuItem(value: 'edit', child: Text(editLabel)),
                  if (onStatement != null && statementLabel != null)
                    PopupMenuItem(
                      value: 'statement',
                      child: Text(statementLabel!),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      deleteLabel,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'statement') onStatement?.call();
                  if (action == 'delete') onDelete();
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
                customerBalanceLabel,
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
