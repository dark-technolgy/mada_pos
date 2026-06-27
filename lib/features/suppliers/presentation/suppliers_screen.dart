import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../application/suppliers_service.dart';
import '../../customers/presentation/widgets/account_statement_dialog.dart';
import 'widgets/suppliers_sections.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final SuppliersService _suppliersService = const SuppliersService();
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
    final suppliers = await _suppliersService.loadSuppliers(db);
    setState(() {
      _suppliers = suppliers;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _suppliersService.filterSuppliers(_suppliers, _searchQuery);
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
      await _suppliersService.deleteSupplier(db, supplier.id);
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
            padding: EdgeInsets.zero,
            child: SuppliersSearchSection(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilter();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SuppliersTableSection(
              suppliers: _filtered,
              isDark: isDark,
              onEdit: (supplier) =>
                  context.go('/suppliers/edit/${supplier.id}'),
              onStatement: (supplier) => AccountStatementDialog.showForSupplier(
                context,
                supplierId: supplier.id,
                supplierName: supplier.name,
              ),
              statementLabel: l10n.accountStatement,
              onDelete: _deleteSupplier,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
