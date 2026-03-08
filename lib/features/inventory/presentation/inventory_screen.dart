import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/empty_state.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String _searchQuery = '';
  String _filter = 'all'; // all, low, out

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    final db = ref.read(databaseProvider);
    final products = await db.select(db.products).get();
    final stocks = await db.select(db.stock).get();

    final items = <Map<String, dynamic>>[];
    for (final product in products) {
      if (!product.isActive) continue;
      final stockEntry = stocks.where((s) => s.productId == product.id);
      final qty = stockEntry.isNotEmpty ? stockEntry.first.quantity : 0.0;
      items.add({
        'product': product,
        'quantity': qty,
        'status': qty <= 0
            ? 'out'
            : qty <= product.minStockLevel
            ? 'low'
            : 'ok',
      });
    }

    setState(() {
      _stockItems = items;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredItems = _stockItems.where((item) {
      final product = item['product'] as Product;
      if (_filter == 'low' && item['status'] != 'low') return false;
      if (_filter == 'out' && item['status'] != 'out') return false;
      if (_searchQuery.isNotEmpty) {
        return product.nameAr.contains(_searchQuery) ||
            (product.barcode?.contains(_searchQuery) ?? false);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lowCount = _stockItems.where((i) => i['status'] == 'low').length;
    final outCount = _stockItems.where((i) => i['status'] == 'out').length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.inventory,
            subtitle: '${_stockItems.length} ${l10n.products}',
          ),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildStatCard(
                  l10n.totalProducts,
                  '${_stockItems.length}',
                  Icons.inventory_2_outlined,
                  AppColors.primary,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  l10n.lowStock,
                  '$lowCount',
                  Icons.warning_rounded,
                  AppColors.warning,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  l10n.outOfStock,
                  '$outCount',
                  Icons.error_outline_rounded,
                  AppColors.error,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    hintText: l10n.searchInventory,
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(l10n.all, 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(l10n.lowStock, 'low', isDark),
                const SizedBox(width: 8),
                _buildFilterChip(l10n.outOfStock, 'out', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stock Table
          Expanded(
            child: _filteredItems.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_outlined,
                    title: l10n.noSearchResults,
                    subtitle: l10n.noProductsMatchSearch,
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
                              DataColumn(label: Text(l10n.products)),
                              DataColumn(label: Text(l10n.barcode)),
                              DataColumn(
                                label: Text(l10n.quantity),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(l10n.minStock),
                                numeric: true,
                              ),
                              DataColumn(label: Text(l10n.status)),
                            ],
                            rows: _filteredItems.map((item) {
                              final product = item['product'] as Product;
                              final qty = item['quantity'] as double;
                              final status = item['status'] as String;

                              Color statusColor;
                              String statusText;
                              switch (status) {
                                case 'low':
                                  statusColor = AppColors.warning;
                                  statusText = l10n.lowStock;
                                  break;
                                case 'out':
                                  statusColor = AppColors.error;
                                  statusText = l10n.outOfStock;
                                  break;
                                default:
                                  statusColor = AppColors.success;
                                  statusText = l10n.inStock;
                              }

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      product.nameAr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
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
                                      qty.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      product.minStockLevel.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (v) {
        setState(() {
          _filter = v ? value : 'all';
          _applyFilters();
        });
      },
    );
  }
}
