import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';

class UsersUnauthorizedView extends StatelessWidget {
  const UsersUnauthorizedView({
    super.key,
    required this.isDark,
    required this.title,
    required this.subtitle,
  });

  final bool isDark;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: EmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}

class UsersLoadingView extends StatelessWidget {
  const UsersLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class UsersEmptyView extends StatelessWidget {
  const UsersEmptyView({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.people_outline_rounded,
      title: title,
      subtitle: subtitle,
    );
  }
}

class UsersListSection extends StatelessWidget {
  const UsersListSection({
    super.key,
    required this.users,
    required this.isDark,
    required this.currentUserId,
    required this.isSaving,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.editLabel,
    required this.resetPasswordLabel,
    required this.activateLabel,
    required this.deactivateLabel,
    required this.currentSessionLabel,
    required this.roleLabelFor,
    required this.onEditUser,
    required this.onResetPassword,
    required this.onToggleActive,
    this.onSetPin,
    this.onClearPin,
    this.setPinLabel,
    this.clearPinLabel,
  });

  final List<User> users;
  final bool isDark;
  final int? currentUserId;
  final bool isSaving;
  final String activeLabel;
  final String inactiveLabel;
  final String editLabel;
  final String resetPasswordLabel;
  final String activateLabel;
  final String deactivateLabel;
  final String currentSessionLabel;
  final String Function(String roleValue) roleLabelFor;
  final ValueChanged<User> onEditUser;
  final ValueChanged<User> onResetPassword;
  final ValueChanged<User> onToggleActive;
  final ValueChanged<User>? onSetPin;
  final ValueChanged<User>? onClearPin;
  final String? setPinLabel;
  final String? clearPinLabel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UserManagementCard(
          user: user,
          isDark: isDark,
          isSaving: isSaving,
          isSelf: currentUserId == user.id,
          activeLabel: activeLabel,
          inactiveLabel: inactiveLabel,
          editLabel: editLabel,
          resetPasswordLabel: resetPasswordLabel,
          activateLabel: activateLabel,
          deactivateLabel: deactivateLabel,
          currentSessionLabel: currentSessionLabel,
          roleLabel: roleLabelFor(user.role),
          onEdit: () => onEditUser(user),
          onResetPassword: () => onResetPassword(user),
          onToggleActive: () => onToggleActive(user),
          onSetPin: onSetPin == null ? null : () => onSetPin!(user),
          onClearPin: onClearPin == null ? null : () => onClearPin!(user),
          setPinLabel: setPinLabel,
          clearPinLabel: clearPinLabel,
        );
      },
    );
  }
}

class UserManagementCard extends StatelessWidget {
  const UserManagementCard({
    super.key,
    required this.user,
    required this.isDark,
    required this.isSaving,
    required this.isSelf,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.editLabel,
    required this.resetPasswordLabel,
    required this.activateLabel,
    required this.deactivateLabel,
    required this.currentSessionLabel,
    required this.roleLabel,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleActive,
    this.onSetPin,
    this.onClearPin,
    this.setPinLabel,
    this.clearPinLabel,
  });

  final User user;
  final bool isDark;
  final bool isSaving;
  final bool isSelf;
  final String activeLabel;
  final String inactiveLabel;
  final String editLabel;
  final String resetPasswordLabel;
  final String activateLabel;
  final String deactivateLabel;
  final String currentSessionLabel;
  final String roleLabel;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleActive;
  final VoidCallback? onSetPin;
  final VoidCallback? onClearPin;
  final String? setPinLabel;
  final String? clearPinLabel;

  @override
  Widget build(BuildContext context) {
    final statusColor = user.isActive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  user.isActive ? activeLabel : inactiveLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaChip(label: roleLabel, isDark: isDark),
              const SizedBox(width: 8),
              if (isSelf) _MetaChip(label: currentSessionLabel, isDark: isDark),
            ],
          ),
          if (onSetPin != null || onClearPin != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onSetPin != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSaving ? null : onSetPin,
                      icon: const Icon(Icons.pin_rounded, size: 16),
                      label: Text(setPinLabel ?? 'PIN'),
                    ),
                  ),
                if (onSetPin != null && onClearPin != null)
                  const SizedBox(width: 8),
                if (onClearPin != null && user.pin != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSaving ? null : onClearPin,
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: Text(clearPinLabel ?? 'Clear PIN'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(editLabel),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onResetPassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 16),
                  label: Text(resetPasswordLabel),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSaving || isSelf ? null : onToggleActive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.isActive
                        ? AppColors.error
                        : AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    user.isActive ? Icons.block_rounded : Icons.check_circle,
                    size: 16,
                  ),
                  label: Text(user.isActive ? deactivateLabel : activateLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
