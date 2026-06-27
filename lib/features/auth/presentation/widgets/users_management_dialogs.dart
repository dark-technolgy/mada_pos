import 'package:flutter/material.dart';

import 'users_management_dialog_sections.dart';

enum UserDialogMode { create, edit }

class UserDialogResult {
  const UserDialogResult({
    this.username,
    required this.fullName,
    required this.role,
    this.password,
    required this.isActive,
  });

  final String? username;
  final String fullName;
  final String role;
  final String? password;
  final bool isActive;
}

Future<UserDialogResult?> showUserManagementDialog({
  required BuildContext context,
  required UserDialogMode mode,
  required String title,
  required String fullNameLabel,
  required String usernameLabel,
  required String roleLabel,
  required String initialPasswordLabel,
  required String activeLabel,
  required String passwordRequiredLabel,
  required String usernameRequiredLabel,
  required String fullNameRequiredLabel,
  required String saveLabel,
  required String cancelLabel,
  String? initialFullName,
  String? initialUsername,
  String initialRole = 'cashier',
  bool initialIsActive = true,
}) {
  return showDialog<UserDialogResult>(
    context: context,
    builder: (context) => _UserManagementDialog(
      mode: mode,
      title: title,
      fullNameLabel: fullNameLabel,
      usernameLabel: usernameLabel,
      roleLabel: roleLabel,
      initialPasswordLabel: initialPasswordLabel,
      activeLabel: activeLabel,
      passwordRequiredLabel: passwordRequiredLabel,
      usernameRequiredLabel: usernameRequiredLabel,
      fullNameRequiredLabel: fullNameRequiredLabel,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
      initialFullName: initialFullName,
      initialUsername: initialUsername,
      initialRole: initialRole,
      initialIsActive: initialIsActive,
    ),
  );
}

Future<String?> showResetPasswordDialog({
  required BuildContext context,
  required String title,
  required String newPasswordLabel,
  required String passwordRequiredLabel,
  required String saveLabel,
  required String cancelLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ResetPasswordDialog(
      title: title,
      newPasswordLabel: newPasswordLabel,
      passwordRequiredLabel: passwordRequiredLabel,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _UserManagementDialog extends StatefulWidget {
  const _UserManagementDialog({
    required this.mode,
    required this.title,
    required this.fullNameLabel,
    required this.usernameLabel,
    required this.roleLabel,
    required this.initialPasswordLabel,
    required this.activeLabel,
    required this.passwordRequiredLabel,
    required this.usernameRequiredLabel,
    required this.fullNameRequiredLabel,
    required this.saveLabel,
    required this.cancelLabel,
    this.initialFullName,
    this.initialUsername,
    required this.initialRole,
    required this.initialIsActive,
  });

  final UserDialogMode mode;
  final String title;
  final String fullNameLabel;
  final String usernameLabel;
  final String roleLabel;
  final String initialPasswordLabel;
  final String activeLabel;
  final String passwordRequiredLabel;
  final String usernameRequiredLabel;
  final String fullNameRequiredLabel;
  final String saveLabel;
  final String cancelLabel;
  final String? initialFullName;
  final String? initialUsername;
  final String initialRole;
  final bool initialIsActive;

  @override
  State<_UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<_UserManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late String _selectedRole;
  late bool _isActive;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.initialFullName ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.initialUsername ?? '',
    );
    _passwordController = TextEditingController();
    _selectedRole = widget.initialRole;
    _isActive = widget.initialIsActive;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: UserManagementDialogForm(
        formKey: _formKey,
        mode: widget.mode,
        fullNameController: _fullNameController,
        usernameController: _usernameController,
        passwordController: _passwordController,
        fullNameLabel: widget.fullNameLabel,
        usernameLabel: widget.usernameLabel,
        roleLabel: widget.roleLabel,
        initialPasswordLabel: widget.initialPasswordLabel,
        activeLabel: widget.activeLabel,
        passwordRequiredLabel: widget.passwordRequiredLabel,
        usernameRequiredLabel: widget.usernameRequiredLabel,
        fullNameRequiredLabel: widget.fullNameRequiredLabel,
        selectedRole: _selectedRole,
        isActive: _isActive,
        obscurePassword: _obscurePassword,
        onRoleChanged: (value) {
          setState(() => _selectedRole = value);
        },
        onActiveChanged: (value) {
          setState(() => _isActive = value);
        },
        onTogglePassword: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              UserDialogResult(
                username: widget.mode == UserDialogMode.create
                    ? _usernameController.text.trim()
                    : null,
                fullName: _fullNameController.text.trim(),
                role: _selectedRole,
                password: widget.mode == UserDialogMode.create
                    ? _passwordController.text
                    : null,
                isActive: _isActive,
              ),
            );
          },
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.title,
    required this.newPasswordLabel,
    required this.passwordRequiredLabel,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final String title;
  final String newPasswordLabel;
  final String passwordRequiredLabel;
  final String saveLabel;
  final String cancelLabel;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ResetPasswordDialogForm(
        formKey: _formKey,
        controller: _controller,
        newPasswordLabel: widget.newPasswordLabel,
        passwordRequiredLabel: widget.passwordRequiredLabel,
        obscurePassword: _obscurePassword,
        onTogglePassword: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text);
          },
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
