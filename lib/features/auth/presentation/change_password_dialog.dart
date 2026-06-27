import 'package:flutter/material.dart';
import '../../../core/localization/l10n_ext.dart';
import 'change_password_copy.dart';
import 'widgets/change_password_sections.dart';

class ChangePasswordDialogResult {
  const ChangePasswordDialogResult({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    super.key,
    required this.requireCurrentPassword,
    this.isMandatory = false,
  });

  final bool requireCurrentPassword;
  final bool isMandatory;

  static Future<ChangePasswordDialogResult?> show(
    BuildContext context, {
    required bool requireCurrentPassword,
    bool isMandatory = false,
  }) {
    return showDialog<ChangePasswordDialogResult>(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => ChangePasswordDialog(
        requireCurrentPassword: requireCurrentPassword,
        isMandatory: isMandatory,
      ),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final copy = changePasswordDialogCopyFor(context);

    return AlertDialog(
      title: Text(copy.title),
      content: ChangePasswordFormSection(
        formKey: _formKey,
        isDark: isDark,
        bodyText: widget.isMandatory ? copy.mandatoryBody : copy.optionalBody,
        passwordRules: copy.passwordRules,
        requireCurrentPassword: widget.requireCurrentPassword,
        currentPasswordController: _currentPasswordController,
        newPasswordController: _newPasswordController,
        confirmPasswordController: _confirmPasswordController,
        currentPasswordLabel: copy.currentPasswordLabel,
        newPasswordLabel: copy.newPasswordLabel,
        confirmPasswordLabel: copy.confirmPasswordLabel,
        enterPasswordLabel: l10n.enterPassword,
        passwordMismatchLabel: copy.passwordMismatch,
        obscureCurrent: _obscureCurrent,
        obscureNew: _obscureNew,
        obscureConfirm: _obscureConfirm,
        onToggleCurrent: () {
          setState(() => _obscureCurrent = !_obscureCurrent);
        },
        onToggleNew: () {
          setState(() => _obscureNew = !_obscureNew);
        },
        onToggleConfirm: () {
          setState(() => _obscureConfirm = !_obscureConfirm);
        },
      ),
      actions: [
        if (!widget.isMandatory)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              ChangePasswordDialogResult(
                currentPassword: _currentPasswordController.text,
                newPassword: _newPasswordController.text,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
