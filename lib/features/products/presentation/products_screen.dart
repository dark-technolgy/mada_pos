import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../application/products_service.dart';
import 'widgets/products_sections.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  Map<int, String> _categoryNamesById = const {};
  String _searchQuery = '';
  int? _filterCategoryId;
  bool _showInactive = false;
  final ProductsService _productsService = const ProductsService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final result = await _productsService.loadScreenData(db);

    setState(() {
      _products = result.products;
      _categories = result.categories;
      _categoryNamesById = result.categoryNamesById;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredProducts = _productsService.filterProducts(
      products: _products,
      searchQuery: _searchQuery,
      categoryId: _filterCategoryId,
      showInactive: _showInactive,
    );
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
      await _productsService.deleteProduct(db, product.id);
      await _loadData();
    }
  }

  String _getCategoryName(int? categoryId) {
    return _productsService.categoryNameFor(categoryId, _categoryNamesById);
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
          ProductsFiltersSection(
            isDark: isDark,
            searchHint: l10n.searchByNameBarcodeCode,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            allCategoriesLabel: l10n.allCategories,
            categories: _categories,
            selectedCategoryId: _filterCategoryId,
            onCategoryChanged: (value) {
              setState(() {
                _filterCategoryId = value;
                _applyFilters();
              });
            },
            inactiveLabel: l10n.inactive,
            showInactive: _showInactive,
            onShowInactiveChanged: (value) {
              setState(() {
                _showInactive = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ProductsContentSection(
              isDark: isDark,
              products: _filteredProducts,
              noProductsLabel: l10n.noProducts,
              emptySubtitle: l10n.startByAddingNewProducts,
              productLabel: l10n.productLabel,
              categoryLabel: l10n.category,
              barcodeLabel: l10n.barcode,
              purchasePriceLabel: l10n.purchasePrice,
              sellingPriceLabel: l10n.sellingPrice,
              statusLabel: l10n.status,
              actionsLabel: l10n.actions,
              withoutCategoryLabel: l10n.withoutCategory,
              activeLabel: l10n.active,
              inactiveLabel: l10n.inactive,
              editLabel: l10n.edit,
              deleteLabel: l10n.delete,
              categoryNameFor: (product) =>
                  _getCategoryName(product.categoryId),
              onEditProduct: (product) =>
                  context.go('/products/edit/${product.id}'),
              onDeleteProduct: _deleteProduct,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
