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

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  String _searchQuery = '';
  int? _filterCategoryId;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final products = await (db.select(
      db.products,
    )..orderBy([(p) => OrderingTerm.asc(p.nameAr)])).get();
    final categories = await db.select(db.categories).get();

    setState(() {
      _products = products;
      _categories = categories;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredProducts = _products.where((p) {
      if (!_showInactive && !p.isActive) {
        return false;
      }
      if (_filterCategoryId != null && p.categoryId != _filterCategoryId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return p.nameAr.contains(_searchQuery) ||
            (p.nameEn?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (p.barcode?.contains(_searchQuery) ?? false) ||
            (p.sku?.contains(_searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  Future<void> _deleteProduct(Product product) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.deleteProductTitle,
      message: l10n.deleteProductMessage(product.nameAr),
      confirmText: l10n.delete,
    );

    if (confirmed) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.products,
      )..where((p) => p.id.equals(product.id))).go();
      _loadData();
    }
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return '-';
    final cat = _categories.where((c) => c.id == categoryId);
    return cat.isNotEmpty ? cat.first.nameAr : '-';
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
            title: l10n.products,
            subtitle: '${_filteredProducts.length} ${l10n.products}',
            actions: [
              ElevatedButton.icon(
                onPressed: () => context.go('/products/add'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addProduct),
              ),
            ],
          ),
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    hintText: l10n.searchByNameBarcodeCode,
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Category filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _filterCategoryId,
                      hint: Text(
                        l10n.allCategories,
                        style: const TextStyle(fontSize: 13),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            l10n.allCategories,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.nameAr,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _filterCategoryId = v;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(
                    l10n.inactive,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _showInactive,
                  onSelected: (v) {
                    setState(() {
                      _showInactive = v;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Products Table
          Expanded(
            child: _filteredProducts.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.noProducts,
                    subtitle: l10n.startByAddingNewProducts,
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
                              DataColumn(label: Text(l10n.productLabel)),
                              DataColumn(label: Text(l10n.category)),
                              DataColumn(label: Text(l10n.barcode)),
                              DataColumn(label: Text(l10n.purchasePrice)),
                              DataColumn(label: Text(l10n.sellingPrice)),
                              DataColumn(label: Text(l10n.status)),
                              DataColumn(label: Text(l10n.actions)),
                            ],
                            rows: _filteredProducts.map((product) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                                      : AppColors
                                                            .lightTextMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _getCategoryName(product.categoryId) ==
                                              '-'
                                          ? l10n.withoutCategory
                                          : _getCategoryName(
                                              product.categoryId,
                                            ),
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
                                      CurrencyFormatter.formatIQD(
                                        product.purchasePrice,
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      CurrencyFormatter.formatIQD(
                                        product.sellingPrice,
                                      ),
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
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (product.isActive
                                                    ? AppColors.success
                                                    : AppColors.error)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        product.isActive
                                            ? l10n.active
                                            : l10n.inactive,
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
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () => context.go(
                                            '/products/edit/${product.id}',
                                          ),
                                          color: AppColors.primary,
                                          tooltip: l10n.edit,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _deleteProduct(product),
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
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
