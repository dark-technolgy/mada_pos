import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/stat_card.dart';

class InvoicesTabsSection extends StatelessWidget {
  const InvoicesTabsSection({
    super.key,
    required this.controller,
    required this.isDark,
    required this.l10n,
  });

  final TabController controller;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.lightTextMuted)
                .withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primary.withValues(alpha: 0.14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 8,
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: l10n.saleInvoicesTab),
          Tab(text: l10n.purchaseInvoicesTab),
          Tab(text: l10n.returnsTab),
        ],
      ),
    );
  }
}

class InvoicesSummarySection extends StatelessWidget {
  const InvoicesSummarySection({
    super.key,
    required this.l10n,
    required this.filteredCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.displayCurrencyCode,
  });

  final AppLocalizations l10n;
  final int filteredCount;
  final String totalAmount;
  final String paidAmount;
  final String remainingAmount;
  final String displayCurrencyCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: l10n.invoices,
              value: filteredCount.toString(),
              icon: Icons.receipt_long_outlined,
              gradient: AppColors.primaryGradient,
              subtitle: l10n.currentCurrencyLabel(displayCurrencyCode),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: l10n.amount,
              value: totalAmount,
              icon: Icons.payments_outlined,
              gradient: AppColors.accentGradient,
              subtitle: l10n.currentCurrencyLabel(displayCurrencyCode),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: l10n.paid,
              value: paidAmount,
              icon: Icons.check_circle_outline,
              gradient: AppColors.successGradient,
              subtitle: l10n.currentCurrencyLabel(displayCurrencyCode),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: l10n.remaining,
              value: remainingAmount,
              icon: Icons.pending_outlined,
              gradient: AppColors.warningGradient,
              subtitle: l10n.currentCurrencyLabel(displayCurrencyCode),
            ),
          ),
        ],
      ),
    );
  }
}

class InvoicesQuickFiltersSection extends StatelessWidget {
  const InvoicesQuickFiltersSection({
    super.key,
    required this.l10n,
    required this.dateFilter,
    required this.statusFilter,
    required this.onToday,
    required this.onThisWeek,
    required this.onUnpaid,
    required this.onPartial,
  });

  final AppLocalizations l10n;
  final String dateFilter;
  final String statusFilter;
  final VoidCallback onToday;
  final VoidCallback onThisWeek;
  final VoidCallback onUnpaid;
  final VoidCallback onPartial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: Text(l10n.today),
            selected: dateFilter == 'today',
            onSelected: (_) => onToday(),
          ),
          FilterChip(
            label: Text(l10n.thisWeek),
            selected: dateFilter == 'thisWeek',
            onSelected: (_) => onThisWeek(),
          ),
          FilterChip(
            label: Text(l10n.unpaid),
            selected: statusFilter == 'unpaid',
            onSelected: (_) => onUnpaid(),
          ),
          FilterChip(
            label: Text(l10n.partial),
            selected: statusFilter == 'partial',
            onSelected: (_) => onPartial(),
          ),
        ],
      ),
    );
  }
}

class InvoicesFiltersSection extends StatelessWidget {
  const InvoicesFiltersSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.dateFilter,
    required this.onDateFilterChanged,
    required this.customFromDateLabel,
    required this.customToDateLabel,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.paymentFilter,
    required this.onPaymentFilterChanged,
    required this.currencyFilter,
    required this.availableCurrencies,
    required this.onCurrencyFilterChanged,
    required this.sortField,
    required this.onSortFieldChanged,
    required this.sortAscending,
    required this.onSortDirectionChanged,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.discountOnly,
    required this.onDiscountOnlyChanged,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final String dateFilter;
  final ValueChanged<String> onDateFilterChanged;
  final String customFromDateLabel;
  final String customToDateLabel;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final String paymentFilter;
  final ValueChanged<String> onPaymentFilterChanged;
  final String currencyFilter;
  final List<String> availableCurrencies;
  final ValueChanged<String> onCurrencyFilterChanged;
  final String sortField;
  final ValueChanged<String> onSortFieldChanged;
  final bool sortAscending;
  final ValueChanged<bool> onSortDirectionChanged;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final bool discountOnly;
  final ValueChanged<bool> onDiscountOnlyChanged;

  @override
  Widget build(BuildContext context) {
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
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.lightTextMuted)
                  .withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: searchController,
                    hintText: l10n.searchByInvoiceNumberCustomer,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InvoicesDropdownFilter(
                  isDark: isDark,
                  value: dateFilter,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('${l10n.date}: ${l10n.all}'),
                    ),
                    DropdownMenuItem(
                      value: 'today',
                      child: Text('${l10n.date}: ${l10n.today}'),
                    ),
                    DropdownMenuItem(
                      value: 'thisWeek',
                      child: Text('${l10n.date}: ${l10n.thisWeek}'),
                    ),
                    DropdownMenuItem(
                      value: 'thisMonth',
                      child: Text('${l10n.date}: ${l10n.thisMonth}'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('${l10n.date}: ${l10n.custom}'),
                    ),
                  ],
                  onChanged: onDateFilterChanged,
                ),
                if (dateFilter == 'custom') ...[
                  _InvoicesDateButton(
                    isDark: isDark,
                    label: customFromDateLabel,
                    onPressed: onPickFromDate,
                  ),
                  _InvoicesDateButton(
                    isDark: isDark,
                    label: customToDateLabel,
                    onPressed: onPickToDate,
                  ),
                ],
                _InvoicesStatusChip(
                  label: l10n.all,
                  isDark: isDark,
                  isSelected: statusFilter == 'all',
                  onSelected: (selected) {
                    onStatusFilterChanged(selected ? 'all' : 'all');
                  },
                ),
                _InvoicesStatusChip(
                  label: l10n.paid,
                  isDark: isDark,
                  isSelected: statusFilter == 'paid',
                  onSelected: (selected) {
                    onStatusFilterChanged(selected ? 'paid' : 'all');
                  },
                ),
                _InvoicesStatusChip(
                  label: l10n.partial,
                  isDark: isDark,
                  isSelected: statusFilter == 'partial',
                  onSelected: (selected) {
                    onStatusFilterChanged(selected ? 'partial' : 'all');
                  },
                ),
                _InvoicesStatusChip(
                  label: l10n.unpaid,
                  isDark: isDark,
                  isSelected: statusFilter == 'unpaid',
                  onSelected: (selected) {
                    onStatusFilterChanged(selected ? 'unpaid' : 'all');
                  },
                ),
                _InvoicesDropdownFilter(
                  isDark: isDark,
                  value: paymentFilter,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('${l10n.paymentMethod}: ${l10n.all}'),
                    ),
                    DropdownMenuItem(
                      value: 'cash',
                      child: Text('${l10n.paymentMethod}: ${l10n.cash}'),
                    ),
                    DropdownMenuItem(
                      value: 'card',
                      child: Text('${l10n.paymentMethod}: ${l10n.card}'),
                    ),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('${l10n.paymentMethod}: ${l10n.transfer}'),
                    ),
                  ],
                  onChanged: onPaymentFilterChanged,
                ),
                _InvoicesDropdownFilter(
                  isDark: isDark,
                  value: currencyFilter,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('${l10n.currency}: ${l10n.all}'),
                    ),
                    ...availableCurrencies.map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text('${l10n.currency}: $code'),
                      ),
                    ),
                  ],
                  onChanged: onCurrencyFilterChanged,
                ),
                _InvoicesDropdownFilter(
                  isDark: isDark,
                  value: sortField,
                  items: [
                    DropdownMenuItem(
                      value: 'date',
                      child: Text('${l10n.sortBy}: ${l10n.date}'),
                    ),
                    DropdownMenuItem(
                      value: 'amount',
                      child: Text('${l10n.sortBy}: ${l10n.amount}'),
                    ),
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text('${l10n.sortBy}: ${l10n.customer}'),
                    ),
                  ],
                  onChanged: onSortFieldChanged,
                ),
                FilterChip(
                  label: Text(sortAscending ? l10n.ascending : l10n.descending),
                  selected: sortAscending,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: sortAscending ? Colors.white : null,
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  onSelected: onSortDirectionChanged,
                ),
                if (hasActiveFilters)
                  OutlinedButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: Text(l10n.clearFilters),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                FilterChip(
                  label: Text(l10n.discount),
                  selected: discountOnly,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: discountOnly ? Colors.white : null,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: onDiscountOnlyChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InvoicesTableSection extends StatelessWidget {
  const InvoicesTableSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.invoices,
    required this.customerNameFor,
    required this.totalDiscountFor,
    required this.statusTextFor,
    required this.statusColorFor,
    required this.onInvoiceSelected,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<Invoice> invoices;
  final String Function(Invoice invoice) customerNameFor;
  final double Function(Invoice invoice) totalDiscountFor;
  final String Function(String status) statusTextFor;
  final Color Function(String status) statusColorFor;
  final ValueChanged<Invoice> onInvoiceSelected;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.noInvoices,
        subtitle: l10n.invoicesWillAppearAfterOperations,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.lightTextMuted)
                  .withValues(alpha: isDark ? 0.22 : 0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                columns: [
                  DataColumn(label: Text(l10n.invoiceNumber)),
                  DataColumn(label: Text(l10n.invoiceCounterparty)),
                  DataColumn(label: Text(l10n.date)),
                  DataColumn(label: Text(l10n.currency)),
                  DataColumn(label: Text(l10n.amount)),
                  DataColumn(label: Text(l10n.paid)),
                  DataColumn(label: Text(l10n.remaining)),
                  DataColumn(label: Text(l10n.discount)),
                  DataColumn(label: Text(l10n.status)),
                  DataColumn(label: Text(l10n.invoicePayment)),
                ],
                rows: invoices.map((invoice) {
                  final totalDiscount = totalDiscountFor(invoice);
                  final statusColor = statusColorFor(invoice.status);
                  return DataRow(
                    onSelectChanged: (_) => onInvoiceSelected(invoice),
                    cells: [
                      DataCell(
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          customerNameFor(invoice),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${invoice.createdAt.year}-${invoice.createdAt.month.toString().padLeft(2, '0')}-${invoice.createdAt.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          invoice.currencyCode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatInvoiceAmount(
                            invoice.total,
                            invoice.currencyCode,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatInvoiceAmount(
                            invoice.paidAmount,
                            invoice.currencyCode,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatInvoiceAmount(
                            invoice.remaining,
                            invoice.currencyCode,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: invoice.remaining > 0
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          totalDiscount > 0
                              ? _formatInvoiceAmount(
                                  totalDiscount,
                                  invoice.currencyCode,
                                )
                              : '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: totalDiscount > 0
                                ? AppColors.warning
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                            fontWeight: totalDiscount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            statusTextFor(invoice.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(switch (invoice.paymentMethod) {
                          'cash' => l10n.cash,
                          'card' => l10n.card,
                          'transfer' => l10n.transfer,
                          _ => invoice.paymentMethod,
                        }, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatInvoiceAmount(double amount, String currencyCode) {
    return CurrencyFormatter.format(amount, currencyCode);
  }
}

class _InvoicesDropdownFilter extends StatelessWidget {
  const _InvoicesDropdownFilter({
    required this.isDark,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final bool isDark;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          isDense: true,
          items: items,
          onChanged: (nextValue) {
            if (nextValue != null) {
              onChanged(nextValue);
            }
          },
        ),
      ),
    );
  }
}

class _InvoicesDateButton extends StatelessWidget {
  const _InvoicesDateButton({
    required this.isDark,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.date_range_outlined, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _InvoicesStatusChip extends StatelessWidget {
  const _InvoicesStatusChip({
    required this.label,
    required this.isDark,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isDark;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
      onSelected: onSelected,
    );
  }
}
