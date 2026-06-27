import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/router/navigation_menu.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/account_security_service.dart';
import '../../core/security/password_validation.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/change_password_dialog.dart';
import '../providers/app_providers.dart';
import 'app_feedback.dart';
import '../../core/services/branch_context_service.dart';
import '../../features/auth/presentation/pin_lock_screen.dart';
import 'command_palette.dart';
import 'compact_layout.dart';
import 'global_search_bar.dart';
import 'notifications_panel.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _passwordCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensurePasswordChangedIfRequired());
    });
  }

  Future<void> _ensurePasswordChangedIfRequired() async {
    if (_passwordCheckDone || !mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final db = ref.read(databaseProvider);
    final security = AccountSecurityService(db);
    if (!await security.shouldRequirePasswordChange(user)) {
      _passwordCheckDone = true;
      return;
    }

    _passwordCheckDone = true;
    if (!mounted) return;

    final result = await ChangePasswordDialog.show(
      context,
      requireCurrentPassword: false,
      isMandatory: true,
    );
    if (result == null || !mounted) {
      await ref.read(sessionManagerProvider).endSession();
      if (mounted) context.go('/login');
      return;
    }

    try {
      final updated = await security.changePassword(
        user: user,
        newPassword: result.newPassword,
        validateCurrentPassword: false,
      );
      ref.read(currentUserProvider.notifier).state = updated;
      if (mounted) {
        AppFeedback.success(context, context.l10n.savedSuccessfully);
      }
    } on AccountSecurityException catch (error) {
      if (mounted) {
        final message =
            passwordValidationMessage(context.l10n, error.message) ??
            error.message;
        AppFeedback.error(context, message);
        await ref.read(sessionManagerProvider).endSession();
        if (mounted) context.go('/login');
      }
    } catch (e, st) {
      await AppLogger.record('Mandatory password change', error: e, stackTrace: st);
      if (mounted) {
        AppFeedback.error(context, context.l10n.errorOccurred);
        await ref.read(sessionManagerProvider).endSession();
        if (mounted) context.go('/login');
      }
    }
  }

  String _localizedRole(BuildContext context, String? role) {
    final l10n = context.l10n;
    return switch (role) {
      'admin' => l10n.adminRole,
      'manager' => l10n.managerRole,
      'cashier' => l10n.cashier,
      null || '' => '',
      _ => role,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = NavigationMenu.indexForLocation(location);
    if (index >= 0) {
      final current = ref.read(selectedMenuIndexProvider);
      if (current != index) {
        ref.read(selectedMenuIndexProvider.notifier).state = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final selectedIndex = ref.watch(selectedMenuIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarWidth = isExpanded
        ? CompactLayout.sidebarExpandedWidth(ref)
        : CompactLayout.sidebarCollapsedWidth(ref);
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionManagerProvider);

    final isLocked = ref.watch(screenLockedProvider);

    return AppCommandPaletteShortcuts(
      child: Listener(
        onPointerDown: (_) => session.recordActivity(),
        child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Row(
        children: [
          // ─── SIDEBAR ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Logo & Toggle
                _buildHeader(context, ref, isExpanded, isDark),
                const SizedBox(height: 8),
                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    children: [
                      _buildMenuItem(
                        context,
                        ref,
                        0,
                        Icons.dashboard_rounded,
                        l10n.dashboard,
                        '/dashboard',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: true,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        1,
                        Icons.point_of_sale_rounded,
                        l10n.pos,
                        '/pos',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('create_invoice'),
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.products, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        2,
                        Icons.inventory_2_rounded,
                        l10n.products,
                        '/products',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_products'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        3,
                        Icons.category_rounded,
                        l10n.categories,
                        '/categories',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_products'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        4,
                        Icons.straighten_rounded,
                        l10n.units,
                        '/units',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_products'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        5,
                        Icons.warehouse_rounded,
                        l10n.inventory,
                        '/inventory',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_inventory'),
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(
                        l10n.relationships,
                        isExpanded,
                        isDark,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        7,
                        Icons.people_rounded,
                        l10n.customers,
                        '/customers',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_customers'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        8,
                        Icons.local_shipping_rounded,
                        l10n.suppliers,
                        '/suppliers',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_suppliers'),
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.financial, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        9,
                        Icons.receipt_long_rounded,
                        l10n.invoices,
                        '/invoices',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('create_invoice'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        11,
                        Icons.savings_outlined,
                        l10n.cashRegister,
                        '/cash-register',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('cash_register'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        12,
                        Icons.account_balance_wallet_rounded,
                        l10n.debts,
                        '/debts',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_debts'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        13,
                        Icons.money_off_rounded,
                        l10n.expenses,
                        '/expenses',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_expenses'),
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.analytics, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        14,
                        Icons.bar_chart_rounded,
                        l10n.reports,
                        '/reports',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('view_reports'),
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.system, isExpanded, isDark),
                      if (session.hasPermission('manage_users'))
                        _buildMenuItem(
                          context,
                          ref,
                          15,
                          Icons.admin_panel_settings_rounded,
                          l10n.users,
                          '/users',
                          isExpanded,
                          selectedIndex,
                          isDark,
                          enabled: true,
                        ),
                      _buildMenuItem(
                        context,
                        ref,
                        17,
                        Icons.settings_rounded,
                        l10n.settings,
                        '/settings',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_settings'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        18,
                        Icons.backup_rounded,
                        l10n.backup,
                        '/backup',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: session.hasPermission('manage_backup'),
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        19,
                        Icons.info_outline_rounded,
                        l10n.about,
                        '/about',
                        isExpanded,
                        selectedIndex,
                        isDark,
                        enabled: true,
                      ),
                    ],
                  ),
                ),
                // User Info & Logout
                _buildUserSection(context, ref, isExpanded, isDark, user),
              ],
            ),
          ),
          // ─── MAIN CONTENT ───
          Expanded(
            child: GlobalSearchScope(child: widget.child),
          ),
        ],
      ),
          if (isLocked && user != null)
            Positioned.fill(
              child: PinLockScreen(userName: user.fullName),
            ),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isExpanded,
    bool isDark,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'K',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.appName,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            _BranchSelector(isDark: isDark),
          ],
          const Spacer(),
          InkWell(
            onTap: () {
              ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isExpanded
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
    String route,
    bool isExpanded,
    int selectedIndex,
    bool isDark, {
    bool enabled = true,
  }) {
    final isSelected = selectedIndex == index;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: enabled
                ? () {
                    ref.read(selectedMenuIndexProvider.notifier).state = index;
                    context.go(route);
                  }
                : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 12 : 0,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isExpanded, bool isDark) {
    if (!isExpanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 12, top: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Divider(
        height: 1,
        color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
            .withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildUserSection(
    BuildContext context,
    WidgetRef ref,
    bool isExpanded,
    bool isDark,
    dynamic user,
  ) {
    final localizedRole = _localizedRole(context, user?.role as String?);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              user?.fullName?.substring(0, 1) ?? 'U',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.fullName ?? context.l10n.profile,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    localizedRole,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isExpanded)
            Tooltip(
              message: context.l10n.notifications,
              child: InkWell(
                onTap: () => _showNotifications(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: AppColors.warning.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          if (isExpanded) const SizedBox(width: 4),
          if (isExpanded &&
              ref.read(sessionManagerProvider).canUsePinLock)
            Tooltip(
              message: context.l10n.lockScreenNow,
              child: InkWell(
                onTap: () => ref.read(sessionManagerProvider).lockScreen(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
          if (isExpanded) const SizedBox(width: 4),
          Tooltip(
            message: context.l10n.changePassword,
            child: InkWell(
              onTap: user == null
                  ? null
                  : () => _changePassword(context, ref, user as User),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 18,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: context.l10n.logout,
            child: InkWell(
              onTap: () async {
                await ref.read(sessionManagerProvider).endSession();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    ref.invalidate(appNotificationsProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.notifications),
        content: const NotificationsPanel(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final result = await ChangePasswordDialog.show(
      context,
      requireCurrentPassword: true,
    );
    if (result == null || !context.mounted) return;

    final database = ref.read(databaseProvider);
    final service = AccountSecurityService(database);

    try {
      final updatedUser = await service.changePassword(
        user: user,
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      ref.read(currentUserProvider.notifier).state = updatedUser;

      if (context.mounted) {
        AppFeedback.success(context, context.l10n.savedSuccessfully);
      }
    } on AccountSecurityException catch (error) {
      if (context.mounted) {
        final message =
            passwordValidationMessage(context.l10n, error.message) ??
            error.message;
        AppFeedback.error(context, message);
      }
    } catch (e, st) {
      await AppLogger.record('App shell action', error: e, stackTrace: st);
      if (context.mounted) {
        AppFeedback.error(context, context.l10n.errorOccurred);
      }
    }
  }
}

class _BranchSelector extends ConsumerWidget {
  const _BranchSelector({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final activeId = ref.watch(activeBranchIdProvider);
    return branchesAsync.when(
      data: (branches) {
        if (branches.length <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: activeId ?? branches.first.id,
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              items: branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) async {
                if (id == null) return;
                ref.read(activeBranchIdProvider.notifier).state = id;
                await const BranchContextService().setActiveBranchId(
                  ref.read(databaseProvider),
                  id,
                );
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(width: 24),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
