import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../application/supplier_form_service.dart';
import 'widgets/supplier_form_sections.dart';

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
  final SupplierFormService _supplierFormService = const SupplierFormService();

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
    final supplier = await _supplierFormService.loadSupplier(
      db,
      widget.supplierId!,
    );
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
      await _supplierFormService.saveSupplier(
        db,
        supplierId: widget.supplierId,
        payload: SupplierFormPayload(
          name: _nameCtrl.text.trim(),
          companyName: _companyCtrl.text.trim().isEmpty
              ? null
              : _companyCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isActive: _isActive,
        ),
      );

      if (mounted) {
        AppFeedback.success(
          context,
          _isEditing
              ? l10n.supplierUpdatedSuccessfully
              : l10n.supplierAddedSuccessfully,
        );
        context.go('/suppliers');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.error}: $e');
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
          SupplierFormHeader(
            isDark: isDark,
            title: _isEditing ? l10n.editSupplier : l10n.newSupplier,
            cancelLabel: l10n.cancel,
            saveLabel: l10n.save,
            savingLabel: l10n.saving,
            isSaving: _isSaving,
            onCancel: () => context.go('/suppliers'),
            onSave: _save,
          ),
          Expanded(
            child: SupplierFormContent(
              formKey: _formKey,
              isDark: isDark,
              sectionTitle: l10n.supplierInfo,
              nameLabel: '${l10n.supplierNameRequired} *',
              companyNameLabel: l10n.companyName,
              phoneLabel: l10n.phone,
              emailLabel: l10n.email,
              addressLabel: l10n.address,
              notesLabel: l10n.notes,
              activeLabel: l10n.active,
              requiredLabel: l10n.fieldRequired,
              nameController: _nameCtrl,
              companyController: _companyCtrl,
              phoneController: _phoneCtrl,
              emailController: _emailCtrl,
              addressController: _addressCtrl,
              notesController: _notesCtrl,
              isActive: _isActive,
              onActiveChanged: (value) => setState(() => _isActive = value),
            ),
          ),
        ],
      ),
    );
  }
}
