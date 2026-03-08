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

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final suppliers = await (db.select(
      db.suppliers,
    )..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
    setState(() {
      _suppliers = suppliers;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _suppliers.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.contains(_searchQuery) ||
          (s.phone?.contains(_searchQuery) ?? false) ||
          (s.companyName?.contains(_searchQuery) ?? false);
    }).toList();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.deleteSupplierTitle,
      message: l10n.deleteSupplierMessage(supplier.name),
      confirmText: l10n.delete,
    );
    if (confirmed) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.suppliers,
      )..where((s) => s.id.equals(supplier.id))).go();
      _loadData();
    }
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
            title: l10n.suppliers,
            subtitle: '${_filtered.length} ${l10n.suppliers}',
            actions: [
              ElevatedButton.icon(
                onPressed: () => context.go('/suppliers/add'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addSupplier),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchField(
              hintText: l10n.searchByNamePhoneCompany,
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilter();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filtered.isEmpty
                ? EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: l10n.noSuppliers,
                    subtitle: l10n.startByAddingNewSuppliers,
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
                              DataColumn(label: Text(l10n.supplierLabel)),
                              DataColumn(label: Text(l10n.companyName)),
                              DataColumn(label: Text(l10n.phone)),
                              DataColumn(label: Text(l10n.balance)),
                              DataColumn(label: Text(l10n.actions)),
                            ],
                            rows: _filtered.map((supplier) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.accent
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            supplier.name.isNotEmpty
                                                ? supplier.name[0]
                                                : '?',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w700,
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
                                      CurrencyFormatter.formatIQD(
                                        supplier.balance,
                                      ),
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
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () => context.go(
                                            '/suppliers/edit/${supplier.id}',
                                          ),
                                          color: AppColors.primary,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _deleteSupplier(supplier),
                                          color: AppColors.error,
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
