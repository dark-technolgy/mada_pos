import 'package:flutter/material.dart';

import 'users_management_dialogs.dart';

class UserManagementDialogForm extends StatelessWidget {
  const UserManagementDialogForm({
    super.key,
    required this.formKey,
    required this.mode,
    required this.fullNameController,
    required this.usernameController,
    required this.passwordController,
    required this.fullNameLabel,
    required this.usernameLabel,
    required this.roleLabel,
    required this.initialPasswordLabel,
    required this.activeLabel,
    required this.passwordRequiredLabel,
    required this.usernameRequiredLabel,
    required this.fullNameRequiredLabel,
    required this.selectedRole,
    required this.isActive,
    required this.obscurePassword,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final UserDialogMode mode;
  final TextEditingController fullNameController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String fullNameLabel;
  final String usernameLabel;
  final String roleLabel;
  final String initialPasswordLabel;
  final String activeLabel;
  final String passwordRequiredLabel;
  final String usernameRequiredLabel;
  final String fullNameRequiredLabel;
  final String selectedRole;
  final bool isActive;
  final bool obscurePassword;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: fullNameController,
              decoration: InputDecoration(labelText: fullNameLabel),
              validator: (value) => value == null || value.trim().isEmpty
                  ? fullNameRequiredLabel
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: usernameController,
              enabled: mode == UserDialogMode.create,
              decoration: InputDecoration(labelText: usernameLabel),
              validator: (value) {
                if (mode == UserDialogMode.edit) return null;
                if (value == null || value.trim().isEmpty) {
                  return usernameRequiredLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: InputDecoration(labelText: roleLabel),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              onChanged: (value) {
                if (value == null) return;
                onRoleChanged(value);
              },
            ),
            if (mode == UserDialogMode.create) ...[
              const SizedBox(height: 12),
              PasswordEntryField(
                controller: passwordController,
                label: initialPasswordLabel,
                obscureText: obscurePassword,
                requiredLabel: passwordRequiredLabel,
                onToggle: onTogglePassword,
              ),
            ],
            if (mode == UserDialogMode.edit) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                value: isActive,
                contentPadding: EdgeInsets.zero,
                title: Text(activeLabel),
                onChanged: onActiveChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResetPasswordDialogForm extends StatelessWidget {
  const ResetPasswordDialogForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.newPasswordLabel,
    required this.passwordRequiredLabel,
    required this.obscurePassword,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String newPasswordLabel;
  final String passwordRequiredLabel;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      child: Form(
        key: formKey,
        child: PasswordEntryField(
          controller: controller,
          label: newPasswordLabel,
          obscureText: obscurePassword,
          requiredLabel: passwordRequiredLabel,
          onToggle: onTogglePassword,
        ),
      ),
    );
  }
}

class PasswordEntryField extends StatelessWidget {
  const PasswordEntryField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.requiredLabel,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final String requiredLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
          ),
        ),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? requiredLabel : null,
    );
  }
}
