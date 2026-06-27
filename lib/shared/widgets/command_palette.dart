import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/router/navigation_menu.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'keyboard_shortcuts_help.dart';

class _PaletteItem {
  const _PaletteItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.permission,
  });

  final int index;
  final IconData icon;
  final String label;
  final String? permission;
}

/// Desktop quick navigation (Ctrl/Cmd+K).
class CommandPalette {
  CommandPalette._();

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final session = ref.read(sessionManagerProvider);
    final items = _buildItems(l10n)
        .where(
          (item) =>
              item.permission == null ||
              session.hasPermission(item.permission!),
        )
        .toList();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _CommandPaletteDialog(items: items),
    );
  }

  static List<_PaletteItem> _buildItems(AppLocalizations l10n) => [
    _PaletteItem(
      index: NavigationMenu.dashboard,
      icon: Icons.dashboard_rounded,
      label: l10n.dashboard,
      permission: null,
    ),
    _PaletteItem(
      index: NavigationMenu.pos,
      icon: Icons.point_of_sale_rounded,
      label: l10n.pos,
      permission: 'create_invoice',
    ),
    _PaletteItem(
      index: NavigationMenu.products,
      icon: Icons.inventory_2_rounded,
      label: l10n.products,
      permission: 'manage_products',
    ),
    _PaletteItem(
      index: NavigationMenu.categories,
      icon: Icons.category_rounded,
      label: l10n.categories,
      permission: 'manage_products',
    ),
    _PaletteItem(
      index: NavigationMenu.units,
      icon: Icons.straighten_rounded,
      label: l10n.units,
      permission: 'manage_products',
    ),
    _PaletteItem(
      index: NavigationMenu.inventory,
      icon: Icons.warehouse_rounded,
      label: l10n.inventory,
      permission: 'manage_inventory',
    ),
    _PaletteItem(
      index: NavigationMenu.warehouses,
      icon: Icons.store_rounded,
      label: l10n.warehouses,
      permission: 'manage_inventory',
    ),
    _PaletteItem(
      index: NavigationMenu.customers,
      icon: Icons.people_rounded,
      label: l10n.customers,
      permission: 'manage_customers',
    ),
    _PaletteItem(
      index: NavigationMenu.suppliers,
      icon: Icons.local_shipping_rounded,
      label: l10n.suppliers,
      permission: 'manage_suppliers',
    ),
    _PaletteItem(
      index: NavigationMenu.invoices,
      icon: Icons.receipt_long_rounded,
      label: l10n.invoices,
      permission: 'create_invoice',
    ),
    _PaletteItem(
      index: NavigationMenu.quotes,
      icon: Icons.request_quote_rounded,
      label: l10n.quotes,
      permission: 'create_invoice',
    ),
    _PaletteItem(
      index: NavigationMenu.cashRegister,
      icon: Icons.savings_outlined,
      label: l10n.cashRegister,
      permission: 'cash_register',
    ),
    _PaletteItem(
      index: NavigationMenu.debts,
      icon: Icons.account_balance_wallet_rounded,
      label: l10n.debts,
      permission: 'manage_debts',
    ),
    _PaletteItem(
      index: NavigationMenu.expenses,
      icon: Icons.money_off_rounded,
      label: l10n.expenses,
      permission: 'manage_expenses',
    ),
    _PaletteItem(
      index: NavigationMenu.reports,
      icon: Icons.bar_chart_rounded,
      label: l10n.reports,
      permission: 'view_reports',
    ),
    _PaletteItem(
      index: NavigationMenu.users,
      icon: Icons.admin_panel_settings_rounded,
      label: l10n.users,
      permission: 'manage_users',
    ),
    _PaletteItem(
      index: NavigationMenu.auditLog,
      icon: Icons.history_rounded,
      label: l10n.auditLog,
      permission: 'manage_users',
    ),
    _PaletteItem(
      index: NavigationMenu.settings,
      icon: Icons.settings_rounded,
      label: l10n.settings,
      permission: 'manage_settings',
    ),
    _PaletteItem(
      index: NavigationMenu.backup,
      icon: Icons.backup_rounded,
      label: l10n.backup,
      permission: 'manage_backup',
    ),
    _PaletteItem(
      index: NavigationMenu.about,
      icon: Icons.info_outline_rounded,
      label: l10n.about,
      permission: null,
    ),
  ];
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _OpenKeyboardHelpIntent extends Intent {
  const _OpenKeyboardHelpIntent();
}

class AppCommandPaletteShortcuts extends ConsumerWidget {
  const AppCommandPaletteShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.f1): _OpenKeyboardHelpIntent(),
      },
      child: Actions(
        actions: {
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              unawaited(CommandPalette.show(context, ref));
              return null;
            },
          ),
          _OpenKeyboardHelpIntent: CallbackAction<_OpenKeyboardHelpIntent>(
            onInvoke: (_) {
              KeyboardShortcutsHelpDialog.show(context);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.items});

  final List<_PaletteItem> items;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _queryController = TextEditingController();
  final _queryFocus = FocusNode();
  List<_PaletteItem> _visible = const [];

  @override
  void initState() {
    super.initState();
    _visible = widget.items;
    _queryController.addListener(_filter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _queryController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _visible = widget.items;
        return;
      }
      _visible = widget.items
          .where((item) => item.label.toLowerCase().contains(q))
          .toList();
    });
  }

  void _go(_PaletteItem item) {
    final route = NavigationMenu.routeForIndex(item.index);
    Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 560.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _queryController,
                  focusNode: _queryFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    hintText: l10n.commandPaletteSearchHint,
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder)
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ctrl+K',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (_visible.isNotEmpty) _go(_visible.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.commandPaletteTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: _visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.commandPaletteNoResults,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _visible.length,
                        itemBuilder: (context, index) {
                          final item = _visible[index];
                          return ListTile(
                            leading: Icon(item.icon, size: 22),
                            title: Text(item.label),
                            onTap: () => _go(item),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
