import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';

class DebtsSummarySection extends StatelessWidget {
  const DebtsSummarySection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.totalReceivable,
    required this.totalPayable,
    required this.netDebts,
    required this.formatDisplayBaseAmount,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final double totalReceivable;
  final double totalPayable;
  final double netDebts;
  final String Function(double amount) formatDisplayBaseAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _DebtSummaryCard(
            label: l10n.receivablesDue,
            value: formatDisplayBaseAmount(totalReceivable.abs()),
            icon: Icons.arrow_downward_rounded,
            color: AppColors.success,
            isDark: isDark,
          ),
          const SizedBox(width: 18),
          _DebtSummaryCard(
            label: l10n.payablesDue,
            value: formatDisplayBaseAmount(totalPayable.abs()),
            icon: Icons.arrow_upward_rounded,
            color: AppColors.error,
            isDark: isDark,
          ),
          const SizedBox(width: 18),
          _DebtSummaryCard(
            label: l10n.netDebts,
            value: formatDisplayBaseAmount(netDebts.abs()),
            icon: Icons.balance_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class DebtsTabsSection extends StatelessWidget {
  const DebtsTabsSection({
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
        boxShadow: AppColors.cardShadow(isDark),
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
          Tab(text: l10n.receivablesDue),
          Tab(text: l10n.payablesDue),
        ],
      ),
    );
  }
}

class DebtsSearchSection extends StatelessWidget {
  const DebtsSearchSection({
    super.key,
    required this.l10n,
    required this.onChanged,
  });

  final AppLocalizations l10n;
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
        child: SearchField(hintText: l10n.search, onChanged: onChanged),
      ),
    );
  }
}

class DebtsTableSection extends StatelessWidget {
  const DebtsTableSection({
    super.key,
    required this.l10n,
    required this.isDark,
    required this.debts,
    required this.personNameFor,
    required this.formatDebtAmount,
    required this.onAddPayment,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final List<Debt> debts;
  final String Function(Debt debt) personNameFor;
  final String Function(double amount, String currencyCode) formatDebtAmount;
  final ValueChanged<Debt> onAddPayment;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.noDebts,
        subtitle: l10n.debtsWillAppearHere,
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
                DataColumn(label: Text(l10n.person)),
                DataColumn(label: Text(l10n.date)),
                DataColumn(label: Text(l10n.amount)),
                DataColumn(label: Text(l10n.paid)),
                DataColumn(label: Text(l10n.remaining)),
                DataColumn(label: Text(l10n.status)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: debts.map((debt) {
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
                        personNameFor(debt),
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
                        formatDebtAmount(
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
                        formatDebtAmount(
                          debt.originalAmount - debt.remainingAmount,
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
                        formatDebtAmount(
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
                              onPressed: () => onAddPayment(debt),
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: Text(
                                l10n.paymentShort,
                                style: const TextStyle(fontSize: 12),
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
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: AppColors.cardShadow(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
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
