import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/inventory_service.dart';
import 'widgets/inventory_adjustment_dialog.dart';
import 'widgets/inventory_sections.dart';
import 'widgets/stock_transfer_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<InventoryStockItem> _stockItems = [];
  List<InventoryStockItem> _filteredItems = [];
  String _searchQuery = '';
  String _filter = 'all'; // all, low, out
  final InventoryService _inventoryService = const InventoryService();

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    final db = ref.read(databaseProvider);
    final result = await _inventoryService.loadStock(db);

    setState(() {
      _stockItems = result.items;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredItems = _inventoryService.filterItems(
      items: _stockItems,
      query: _searchQuery,
      filter: _filter,
    );
  }

  Future<void> _adjustStock(InventoryStockItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) =>
          InventoryAdjustmentDialog(product: item.product),
    );
    if (ok == true && mounted) await _loadStock();
  }

  Future<void> _transferStock(InventoryStockItem item) async {
    final ok = await showStockTransferDialog(
      context: context,
      product: item.product,
    );
    if (ok && mounted) await _loadStock();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAdjust =
        ref.watch(sessionManagerProvider).hasPermission('manage_inventory');

    final lowCount = _stockItems.where((item) => item.status == 'low').length;
    final outCount = _stockItems.where((item) => item.status == 'out').length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.inventory,
            subtitle: '${_stockItems.length} ${l10n.products}',
          ),
          InventoryStatsSection(
            isDark: isDark,
            totalProductsLabel: l10n.totalProducts,
            totalProductsValue: '${_stockItems.length}',
            lowStockLabel: l10n.lowStock,
            lowStockValue: '$lowCount',
            outOfStockLabel: l10n.outOfStock,
            outOfStockValue: '$outCount',
          ),
          const SizedBox(height: 16),
          InventoryFiltersSection(
            isDark: isDark,
            searchHint: l10n.searchInventory,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            allLabel: l10n.all,
            lowStockLabel: l10n.lowStock,
            outOfStockLabel: l10n.outOfStock,
            selectedFilter: _filter,
            onFilterChanged: (value) {
              setState(() {
                _filter = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: InventoryTableSection(
              isDark: isDark,
              items: _filteredItems,
              productsLabel: l10n.products,
              barcodeLabel: l10n.barcode,
              quantityLabel: l10n.quantity,
              minStockLabel: l10n.minStock,
              statusLabel: l10n.status,
              noResultsLabel: l10n.noSearchResults,
              noResultsSubtitle: l10n.noProductsMatchSearch,
              lowStockLabel: l10n.lowStock,
              outOfStockLabel: l10n.outOfStock,
              inStockLabel: l10n.inStock,
              reorderSuggestionLabel: l10n.reorderSuggestion,
              onItemSelected: canAdjust ? _adjustStock : null,
              onTransfer: canAdjust ? _transferStock : null,
              actionsLabel: l10n.actions,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
