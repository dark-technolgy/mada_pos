import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../core/database/database.dart';

class SuppliersSearchSection extends StatelessWidget {
  const SuppliersSearchSection({super.key, required this.onChanged});

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
        child: SearchField(
          hintText: context.l10n.searchByNamePhoneCompany,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class SuppliersTableSection extends StatelessWidget {
  const SuppliersTableSection({
    super.key,
    required this.suppliers,
    required this.isDark,
    required this.onEdit,
    required this.onStatement,
    required this.statementLabel,
    required this.onDelete,
  });

  final List<Supplier> suppliers;
  final bool isDark;
  final ValueChanged<Supplier> onEdit;
  final ValueChanged<Supplier> onStatement;
  final String statementLabel;
  final ValueChanged<Supplier> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (suppliers.isEmpty) {
      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: l10n.noSuppliers,
        subtitle: l10n.startByAddingNewSuppliers,
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
                DataColumn(label: Text(l10n.supplierLabel)),
                DataColumn(label: Text(l10n.companyName)),
                DataColumn(label: Text(l10n.phone)),
                DataColumn(label: Text(l10n.balance)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: suppliers.map((supplier) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.accentGradient,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              supplier.name.isNotEmpty ? supplier.name[0] : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            supplier.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        supplier.companyName ?? l10n.unknown,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        supplier.phone ?? l10n.unknown,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatIQD(supplier.balance),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: supplier.balance > 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(supplier),
                            color: AppColors.primary,
                            tooltip: l10n.edit,
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long_outlined,
                                size: 18),
                            onPressed: () => onStatement(supplier),
                            color: AppColors.accent,
                            tooltip: statementLabel,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => onDelete(supplier),
                            color: AppColors.error,
                            tooltip: l10n.delete,
                          ),
                        ],
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
