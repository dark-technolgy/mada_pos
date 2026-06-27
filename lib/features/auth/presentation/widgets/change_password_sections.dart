import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ChangePasswordFormSection extends StatelessWidget {
  const ChangePasswordFormSection({
    super.key,
    required this.formKey,
    required this.isDark,
    required this.bodyText,
    required this.passwordRules,
    required this.requireCurrentPassword,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.currentPasswordLabel,
    required this.newPasswordLabel,
    required this.confirmPasswordLabel,
    required this.enterPasswordLabel,
    required this.passwordMismatchLabel,
    required this.obscureCurrent,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
  });

  final GlobalKey<FormState> formKey;
  final bool isDark;
  final String bodyText;
  final String passwordRules;
  final bool requireCurrentPassword;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String currentPasswordLabel;
  final String newPasswordLabel;
  final String confirmPasswordLabel;
  final String enterPasswordLabel;
  final String passwordMismatchLabel;
  final bool obscureCurrent;
  final bool obscureNew;
  final bool obscureConfirm;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bodyText,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (requireCurrentPassword) ...[
              PasswordDialogField(
                controller: currentPasswordController,
                label: currentPasswordLabel,
                obscureText: obscureCurrent,
                onToggle: onToggleCurrent,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return enterPasswordLabel;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            PasswordDialogField(
              controller: newPasswordController,
              label: newPasswordLabel,
              obscureText: obscureNew,
              onToggle: onToggleNew,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return enterPasswordLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PasswordDialogField(
              controller: confirmPasswordController,
              label: confirmPasswordLabel,
              obscureText: obscureConfirm,
              onToggle: onToggleConfirm,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return enterPasswordLabel;
                }
                if (value != newPasswordController.text) {
                  return passwordMismatchLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              passwordRules,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordDialogField extends StatelessWidget {
  const PasswordDialogField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
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
    );
  }
}
