import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final int? supplierId;
  const SupplierFormScreen({super.key, this.supplierId});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.supplierId != null;
    if (_isEditing) _loadSupplier();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSupplier() async {
    final db = ref.read(databaseProvider);
    final supplier = await (db.select(
      db.suppliers,
    )..where((s) => s.id.equals(widget.supplierId!))).getSingleOrNull();
    if (supplier != null) {
      _nameCtrl.text = supplier.name;
      _companyCtrl.text = supplier.companyName ?? '';
      _phoneCtrl.text = supplier.phone ?? '';
      _emailCtrl.text = supplier.email ?? '';
      _addressCtrl.text = supplier.address ?? '';
      _notesCtrl.text = supplier.notes ?? '';
      setState(() => _isActive = supplier.isActive);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      if (_isEditing) {
        await (db.update(
          db.suppliers,
        )..where((s) => s.id.equals(widget.supplierId!))).write(
          SuppliersCompanion(
            name: Value(_nameCtrl.text.trim()),
            companyName: Value(
              _companyCtrl.text.trim().isEmpty
                  ? null
                  : _companyCtrl.text.trim(),
            ),
            phone: Value(
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            ),
            email: Value(
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            ),
            address: Value(
              _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
            ),
            notes: Value(
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            ),
            isActive: Value(_isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db
            .into(db.suppliers)
            .insert(
              SuppliersCompanion.insert(
                name: _nameCtrl.text.trim(),
                companyName: Value(
                  _companyCtrl.text.trim().isEmpty
                      ? null
                      : _companyCtrl.text.trim(),
                ),
                phone: Value(
                  _phoneCtrl.text.trim().isEmpty
                      ? null
                      : _phoneCtrl.text.trim(),
                ),
                email: Value(
                  _emailCtrl.text.trim().isEmpty
                      ? null
                      : _emailCtrl.text.trim(),
                ),
                address: Value(
                  _addressCtrl.text.trim().isEmpty
                      ? null
                      : _addressCtrl.text.trim(),
                ),
                notes: Value(
                  _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                ),
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? l10n.supplierUpdatedSuccessfully
                  : l10n.supplierAddedSuccessfully,
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/suppliers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
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
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/suppliers'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? l10n.editSupplier : l10n.newSupplier,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => context.go('/suppliers'),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? l10n.saving : l10n.save),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.supplierInfo,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l10n.supplierNameRequired} *',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? l10n.fieldRequired
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _companyCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.companyName,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.phone,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.email,
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: InputDecoration(labelText: l10n.address),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          decoration: InputDecoration(labelText: l10n.notes),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: Text(l10n.active),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
