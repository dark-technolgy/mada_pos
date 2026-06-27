import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../application/customer_form_service.dart';
import 'widgets/customer_form_sections.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final int? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEditing = false;
  final CustomerFormService _customerFormService = const CustomerFormService();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.customerId != null;
    if (_isEditing) _loadCustomer();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    final db = ref.read(databaseProvider);
    final customer = await _customerFormService.loadCustomer(
      db,
      widget.customerId!,
    );
    if (customer != null) {
      _nameCtrl.text = customer.name;
      _phoneCtrl.text = customer.phone ?? '';
      _emailCtrl.text = customer.email ?? '';
      _addressCtrl.text = customer.address ?? '';
      _notesCtrl.text = customer.notes ?? '';
      setState(() => _isActive = customer.isActive);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      await _customerFormService.saveCustomer(
        db,
        customerId: widget.customerId,
        payload: CustomerFormPayload(
          name: _nameCtrl.text.trim(),
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
              ? l10n.customerUpdatedSuccessfully
              : l10n.customerAddedSuccessfully,
        );
        context.go('/customers');
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
          CustomerFormHeader(
            isDark: isDark,
            title: _isEditing ? l10n.editCustomer : l10n.newCustomer,
            cancelLabel: l10n.cancel,
            saveLabel: l10n.save,
            savingLabel: l10n.saving,
            isSaving: _isSaving,
            onCancel: () => context.go('/customers'),
            onSave: _save,
          ),
          Expanded(
            child: CustomerFormContent(
              formKey: _formKey,
              isDark: isDark,
              sectionTitle: l10n.basicInformation,
              nameLabel: '${l10n.customerNameRequired} *',
              phoneLabel: l10n.phone,
              emailLabel: l10n.email,
              addressLabel: l10n.address,
              notesLabel: l10n.notes,
              activeLabel: l10n.active,
              requiredLabel: l10n.fieldRequired,
              nameController: _nameCtrl,
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
