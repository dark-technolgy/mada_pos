import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';

class ProductsFiltersSection extends StatelessWidget {
  const ProductsFiltersSection({
    super.key,
    required this.isDark,
    required this.searchHint,
    required this.onSearchChanged,
    required this.allCategoriesLabel,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.inactiveLabel,
    required this.showInactive,
    required this.onShowInactiveChanged,
  });

  final bool isDark;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String allCategoriesLabel;
  final List<Category> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategoryChanged;
  final String inactiveLabel;
  final bool showInactive;
  final ValueChanged<bool> onShowInactiveChanged;

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedCategoryId,
                  hint: Text(
                    allCategoriesLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        allCategoriesLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.nameAr,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => onCategoryChanged(value),
                ),
              ),
            ),
            const SizedBox(width: 14),
            FilterChip(
              label: Text(inactiveLabel, style: const TextStyle(fontSize: 12)),
              selected: showInactive,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                color: showInactive ? Colors.white : null,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              side: BorderSide(color: border),
              onSelected: onShowInactiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class ProductsContentSection extends StatelessWidget {
  const ProductsContentSection({
    super.key,
    required this.isDark,
    required this.products,
    required this.noProductsLabel,
    required this.emptySubtitle,
    required this.productLabel,
    required this.categoryLabel,
    required this.barcodeLabel,
    required this.purchasePriceLabel,
    required this.sellingPriceLabel,
    required this.statusLabel,
    required this.actionsLabel,
    required this.withoutCategoryLabel,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.categoryNameFor,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  final bool isDark;
  final List<Product> products;
  final String noProductsLabel;
  final String emptySubtitle;
  final String productLabel;
  final String categoryLabel;
  final String barcodeLabel;
  final String purchasePriceLabel;
  final String sellingPriceLabel;
  final String statusLabel;
  final String actionsLabel;
  final String withoutCategoryLabel;
  final String activeLabel;
  final String inactiveLabel;
  final String editLabel;
  final String deleteLabel;
  final String Function(Product product) categoryNameFor;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: noProductsLabel,
        subtitle: emptySubtitle,
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
                DataColumn(label: Text(productLabel)),
                DataColumn(label: Text(categoryLabel)),
                DataColumn(label: Text(barcodeLabel)),
                DataColumn(label: Text(purchasePriceLabel)),
                DataColumn(label: Text(sellingPriceLabel)),
                DataColumn(label: Text(statusLabel)),
                DataColumn(label: Text(actionsLabel)),
              ],
              rows: products.map((product) {
                final categoryName = categoryNameFor(product);
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.nameAr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (product.sku != null)
                                Text(
                                  product.sku!,
                                  style: TextStyle(
                                    fontSize: 11,
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
                    DataCell(
                      Text(
                        categoryName == '-'
                            ? withoutCategoryLabel
                            : categoryName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        product.barcode ?? '-',
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatIQD(product.purchasePrice),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatIQD(product.sellingPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
                          color:
                              (product.isActive
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                (product.isActive
                                        ? AppColors.success
                                        : AppColors.error)
                                    .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          product.isActive ? activeLabel : inactiveLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.isActive
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEditProduct(product),
                            color: AppColors.primary,
                            tooltip: editLabel,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => onDeleteProduct(product),
                            color: AppColors.error,
                            tooltip: deleteLabel,
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
