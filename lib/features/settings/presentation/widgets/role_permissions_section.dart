import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/security/permission_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_feedback.dart';

class RolePermissionsSection extends ConsumerStatefulWidget {
  const RolePermissionsSection({super.key});

  @override
  ConsumerState<RolePermissionsSection> createState() =>
      _RolePermissionsSectionState();
}

class _RolePermissionsSectionState extends ConsumerState<RolePermissionsSection> {
  static const _roles = ['manager', 'cashier', 'viewer'];
  String _selectedRole = 'manager';
  Set<String> _permissions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final perms =
        await const PermissionService().permissionsForRole(db, _selectedRole);
    if (!mounted) return;
    setState(() {
      _permissions = perms;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await const PermissionService().setRolePermissions(
      db,
      role: _selectedRole,
      permissions: _permissions,
    );
    if (mounted) {
      AppFeedback.success(context, context.l10n.savedSuccessfully);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rolePermissions,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.rolePermissionsHint,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _roles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() {
                  _selectedRole = value;
                  _loading = true;
                });
                await _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: AppPermissions.all.map((permission) {
                  final selected = _permissions.contains(permission);
                  return FilterChip(
                    label: Text(permission, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _permissions.add(permission);
                        } else {
                          _permissions.remove(permission);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: Text(l10n.saveSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
