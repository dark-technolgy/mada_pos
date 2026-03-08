import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final selectedIndex = ref.watch(selectedMenuIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Row(
        children: [
          // ─── SIDEBAR ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            width: isExpanded ? 260 : 72,
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
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        4,
                        Icons.warehouse_rounded,
                        l10n.inventory,
                        '/inventory',
                        isExpanded,
                        selectedIndex,
                        isDark,
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
                        5,
                        Icons.people_rounded,
                        l10n.customers,
                        '/customers',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        6,
                        Icons.local_shipping_rounded,
                        l10n.suppliers,
                        '/suppliers',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.financial, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        7,
                        Icons.receipt_long_rounded,
                        l10n.invoices,
                        '/invoices',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        8,
                        Icons.account_balance_wallet_rounded,
                        l10n.debts,
                        '/debts',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        9,
                        Icons.money_off_rounded,
                        l10n.expenses,
                        '/expenses',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.analytics, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        10,
                        Icons.bar_chart_rounded,
                        l10n.reports,
                        '/reports',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSectionTitle(l10n.system, isExpanded, isDark),
                      _buildMenuItem(
                        context,
                        ref,
                        11,
                        Icons.settings_rounded,
                        l10n.settings,
                        '/settings',
                        isExpanded,
                        selectedIndex,
                        isDark,
                      ),
                      _buildMenuItem(
                        context,
                        ref,
                        12,
                        Icons.backup_rounded,
                        l10n.backup,
                        '/backup',
                        isExpanded,
                        selectedIndex,
                        isDark,
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
          Expanded(child: child),
        ],
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
    bool isDark,
  ) {
    final isSelected = selectedIndex == index;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            ref.read(selectedMenuIndexProvider.notifier).state = index;
            context.go(route);
          },
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
          Tooltip(
            message: context.l10n.logout,
            child: InkWell(
              onTap: () {
                ref.read(currentUserProvider.notifier).state = null;
                context.go('/login');
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
}
