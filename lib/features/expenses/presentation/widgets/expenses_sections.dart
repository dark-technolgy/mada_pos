import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';

class ExpensesFiltersSection extends StatelessWidget {
  const ExpensesFiltersSection({
    super.key,
    required this.l10n,
    required this.searchHint,
    required this.onSearchChanged,
    required this.periodLabel,
    required this.onSelectDateRange,
  });

  final AppLocalizations l10n;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String periodLabel;
  final Future<void> Function() onSelectDateRange;

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
        child: Row(
          children: [
            Expanded(
              child: SearchField(
                hintText: searchHint,
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              onPressed: onSelectDateRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(periodLabel, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpensesTableSection extends StatelessWidget {
  const ExpensesTableSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.expenses,
    required this.formatExpenseAmount,
    required this.onDeleteExpense,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<Expense> expenses;
  final String Function(Expense expense) formatExpenseAmount;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return EmptyState(
        icon: Icons.money_off_outlined,
        title: l10n.noExpenses,
        subtitle: l10n.expensesWillAppearHere,
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
          boxShadow: AppColors.cardShadow(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
              ),
              columns: [
                DataColumn(label: Text(l10n.expenseDescription)),
                DataColumn(label: Text(l10n.category)),
                DataColumn(label: Text(l10n.date)),
                DataColumn(label: Text(l10n.amount), numeric: true),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: expenses.map((expense) {
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
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          expense.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormatter.formatDate(expense.createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        formatExpenseAmount(expense),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onDeleteExpense(expense),
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
    );
  }
}

String formatExpensesPeriodLabel(
  AppLocalizations l10n, {
  required DateTime? startDate,
  required DateTime? endDate,
}) {
  if (startDate == null || endDate == null) {
    return l10n.selectPeriod;
  }

  return '${DateFormatter.formatDate(startDate)} - ${DateFormatter.formatDate(endDate)}';
}
