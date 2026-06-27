import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../application/inventory_service.dart';

class InventoryStatsSection extends StatelessWidget {
  const InventoryStatsSection({
    super.key,
    required this.isDark,
    required this.totalProductsLabel,
    required this.totalProductsValue,
    required this.lowStockLabel,
    required this.lowStockValue,
    required this.outOfStockLabel,
    required this.outOfStockValue,
  });

  final bool isDark;
  final String totalProductsLabel;
  final String totalProductsValue;
  final String lowStockLabel;
  final String lowStockValue;
  final String outOfStockLabel;
  final String outOfStockValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          InventoryStatCard(
            label: totalProductsLabel,
            value: totalProductsValue,
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          InventoryStatCard(
            label: lowStockLabel,
            value: lowStockValue,
            icon: Icons.warning_rounded,
            color: AppColors.warning,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          InventoryStatCard(
            label: outOfStockLabel,
            value: outOfStockValue,
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class InventoryFiltersSection extends StatelessWidget {
  const InventoryFiltersSection({
    super.key,
    required this.isDark,
    required this.searchHint,
    required this.onSearchChanged,
    required this.allLabel,
    required this.lowStockLabel,
    required this.outOfStockLabel,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final bool isDark;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String allLabel;
  final String lowStockLabel;
  final String outOfStockLabel;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

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
            InventoryFilterChip(
              label: allLabel,
              value: 'all',
              selectedFilter: selectedFilter,
              onFilterChanged: onFilterChanged,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            InventoryFilterChip(
              label: lowStockLabel,
              value: 'low',
              selectedFilter: selectedFilter,
              onFilterChanged: onFilterChanged,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            InventoryFilterChip(
              label: outOfStockLabel,
              value: 'out',
              selectedFilter: selectedFilter,
              onFilterChanged: onFilterChanged,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryTableSection extends StatelessWidget {
  const InventoryTableSection({
    super.key,
    required this.isDark,
    required this.items,
    required this.productsLabel,
    required this.barcodeLabel,
    required this.quantityLabel,
    required this.minStockLabel,
    required this.statusLabel,
    required this.noResultsLabel,
    required this.noResultsSubtitle,
    required this.lowStockLabel,
    required this.outOfStockLabel,
    required this.inStockLabel,
    this.reorderSuggestionLabel,
    this.onItemSelected,
    this.onTransfer,
    this.actionsLabel,
  });

  final bool isDark;
  final List<InventoryStockItem> items;
  final String productsLabel;
  final String barcodeLabel;
  final String quantityLabel;
  final String minStockLabel;
  final String statusLabel;
  final String noResultsLabel;
  final String noResultsSubtitle;
  final String lowStockLabel;
  final String outOfStockLabel;
  final String inStockLabel;
  final String? reorderSuggestionLabel;
  final ValueChanged<InventoryStockItem>? onItemSelected;
  final ValueChanged<InventoryStockItem>? onTransfer;
  final String? actionsLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_outlined,
        title: noResultsLabel,
        subtitle: noResultsSubtitle,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppColors.darkSurface : AppColors.lightBg,
              ),
              columns: [
                DataColumn(label: Text(productsLabel)),
                DataColumn(label: Text(barcodeLabel)),
                DataColumn(label: Text(quantityLabel), numeric: true),
                DataColumn(label: Text(minStockLabel), numeric: true),
                if (reorderSuggestionLabel != null)
                  DataColumn(
                    label: Text(reorderSuggestionLabel!),
                    numeric: true,
                  ),
                DataColumn(label: Text(statusLabel)),
                if (onItemSelected != null || onTransfer != null)
                  DataColumn(label: Text(actionsLabel ?? '')),
              ],
              rows: items.map((item) {
                final statusMeta = _statusMeta(item.status);

                return DataRow(
                  onSelectChanged:
                      onItemSelected != null && onTransfer == null
                      ? (_) => onItemSelected!(item)
                      : null,
                  cells: [
                    DataCell(
                      Text(
                        item.product.nameAr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.product.barcode ?? '-',
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.quantity.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusMeta.color,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.product.minStockLevel.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (reorderSuggestionLabel != null)
                      DataCell(
                        Text(
                          item.suggestedReorderQty == null
                              ? '—'
                              : item.suggestedReorderQty!.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.suggestedReorderQty == null
                                ? (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted)
                                : AppColors.primary,
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
                          color: statusMeta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusMeta.color.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          switch (item.status) {
                            'low' => lowStockLabel,
                            'out' => outOfStockLabel,
                            _ => inStockLabel,
                          },
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusMeta.color,
                          ),
                        ),
                      ),
                    ),
                    if (onItemSelected != null || onTransfer != null)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onItemSelected != null)
                              IconButton(
                                tooltip: actionsLabel,
                                icon: const Icon(Icons.tune_rounded, size: 20),
                                onPressed: () => onItemSelected!(item),
                              ),
                            if (onTransfer != null)
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                onPressed: () => onTransfer!(item),
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

  _InventoryStatusMeta _statusMeta(String status) {
    return switch (status) {
      'low' => const _InventoryStatusMeta(AppColors.warning),
      'out' => const _InventoryStatusMeta(AppColors.error),
      _ => const _InventoryStatusMeta(AppColors.success),
    };
  }
}

class InventoryStatCard extends StatelessWidget {
  const InventoryStatCard({
    super.key,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryFilterChip extends StatelessWidget {
  const InventoryFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.isDark,
  });

  final String label;
  final String value;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedFilter == value;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: border),
      onSelected: (selected) => onFilterChanged(selected ? value : 'all'),
    );
  }
}

class _InventoryStatusMeta {
  const _InventoryStatusMeta(this.color);

  final Color color;
}
