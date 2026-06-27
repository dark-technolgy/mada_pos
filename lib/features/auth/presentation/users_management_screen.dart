import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/security/password_validation.dart';
import '../../../core/security/pin_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/users_management_screen_service.dart';
import '../application/user_management_service.dart';
import 'users_management_copy.dart';
import 'widgets/users_management_dialogs.dart';
import 'widgets/users_management_sections.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  List<User> _users = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  UsersManagementScreenService get _screenService =>
      UsersManagementScreenService(
        UserManagementService(ref.read(databaseProvider)),
      );

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _screenService.loadUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _runSavingAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _isSaving = true);
    try {
      await action();
      await _loadUsers();
      if (successMessage != null) {
        _showSuccess(successMessage);
      }
    } on UserManagementException catch (error) {
      if (mounted) {
        final l10n = context.l10n;
        _showError(passwordValidationMessage(l10n, error.message) ?? error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createUser() async {
    final copy = usersManagementCopyFor(context);
    final result = await showUserManagementDialog(
      context: context,
      mode: UserDialogMode.create,
      title: copy.addUser,
      fullNameLabel: copy.fullName,
      usernameLabel: copy.username,
      roleLabel: copy.role,
      initialPasswordLabel: copy.initialPassword,
      activeLabel: copy.active,
      passwordRequiredLabel: copy.passwordRequired,
      usernameRequiredLabel: copy.usernameRequired,
      fullNameRequiredLabel: copy.fullNameRequired,
      saveLabel: copy.save,
      cancelLabel: copy.cancel,
    );
    if (result == null) return;

    await _runSavingAction(() {
      return _screenService.createUser(
        UserCreatePayload(
          username: result.username!,
          fullName: result.fullName,
          role: result.role,
          password: result.password!,
        ),
      );
    }, successMessage: copy.savedMessage);
  }

  Future<void> _editUser(User user) async {
    final copy = usersManagementCopyFor(context);
    final result = await showUserManagementDialog(
      context: context,
      mode: UserDialogMode.edit,
      title: copy.edit,
      fullNameLabel: copy.fullName,
      usernameLabel: copy.username,
      roleLabel: copy.role,
      initialPasswordLabel: copy.initialPassword,
      activeLabel: copy.active,
      passwordRequiredLabel: copy.passwordRequired,
      usernameRequiredLabel: copy.usernameRequired,
      fullNameRequiredLabel: copy.fullNameRequired,
      saveLabel: copy.save,
      cancelLabel: copy.cancel,
      initialFullName: user.fullName,
      initialUsername: user.username,
      initialRole: user.role,
      initialIsActive: user.isActive,
    );
    if (result == null) return;

    await _runSavingAction(() {
      return _screenService.updateUser(
        user,
        UserUpdatePayload(
          fullName: result.fullName,
          role: result.role,
          isActive: result.isActive,
        ),
      );
    }, successMessage: copy.savedMessage);
  }

  Future<void> _resetPassword(User user) async {
    final copy = usersManagementCopyFor(context);
    final password = await showResetPasswordDialog(
      context: context,
      title: copy.resetPasswordFor(user.fullName),
      newPasswordLabel: copy.newPassword,
      passwordRequiredLabel: copy.passwordRequired,
      saveLabel: copy.save,
      cancelLabel: copy.cancel,
    );
    if (password == null) return;

    await _runSavingAction(
      () => _screenService.resetPassword(user, password),
      successMessage: copy.passwordResetMessage,
    );
  }

  Future<void> _setPin(User user) async {
    final copy = usersManagementCopyFor(context);
    final ctrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(copy.setUserPin),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: copy.enterPin),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(copy.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(copy.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pin == null || pin.isEmpty) return;
    final formatError = PinAuthService.validatePinFormat(pin);
    if (formatError != null) {
      _showError(copy.pinInvalidFormat);
      return;
    }
    final mgmt = UserManagementService(ref.read(databaseProvider));
    await _runSavingAction(
      () => mgmt.setUserPin(user: user, pin: pin),
      successMessage: copy.pinSetSuccess,
    );
  }

  Future<void> _clearPin(User user) async {
    final copy = usersManagementCopyFor(context);
    final mgmt = UserManagementService(ref.read(databaseProvider));
    await _runSavingAction(
      () => mgmt.clearUserPin(user: user),
      successMessage: copy.pinClearedSuccess,
    );
  }

  Future<void> _toggleActive(User user) async {
    final copy = usersManagementCopyFor(context);
    await _runSavingAction(
      () => _screenService.toggleActive(user),
      successMessage: copy.savedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final copy = usersManagementCopyFor(context);

    if (currentUser?.role != 'admin') {
      return UsersUnauthorizedView(
        isDark: isDark,
        title: copy.unauthorizedTitle,
        subtitle: copy.unauthorizedSubtitle,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: copy.title,
            subtitle: '${_users.length} ${copy.usersCountLabel}',
            actions: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _createUser,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(copy.addUser),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const UsersLoadingView()
                : _users.isEmpty
                ? UsersEmptyView(
                    title: copy.emptyTitle,
                    subtitle: copy.emptySubtitle,
                  )
                : UsersListSection(
                    users: _users,
                    isDark: isDark,
                    currentUserId: currentUser?.id,
                    isSaving: _isSaving,
                    activeLabel: copy.active,
                    inactiveLabel: copy.inactive,
                    editLabel: copy.edit,
                    resetPasswordLabel: copy.resetPassword,
                    activateLabel: copy.activate,
                    deactivateLabel: copy.deactivate,
                    currentSessionLabel: copy.currentSession,
                    roleLabelFor: copy.roleLabel,
                    onEditUser: _editUser,
                    onResetPassword: _resetPassword,
                    onToggleActive: _toggleActive,
                    onSetPin: _setPin,
                    onClearPin: _clearPin,
                    setPinLabel: copy.setUserPin,
                    clearPinLabel: copy.clearUserPin,
                  ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AppFeedback.error(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppFeedback.success(context, message);
  }
}
