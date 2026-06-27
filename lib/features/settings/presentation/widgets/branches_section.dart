import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../branches/application/branches_service.dart';

class BranchesSection extends ConsumerStatefulWidget {
  const BranchesSection({super.key});

  @override
  ConsumerState<BranchesSection> createState() => _BranchesSectionState();
}

class _BranchesSectionState extends ConsumerState<BranchesSection> {
  final _service = const BranchesService();
  List<Branche> _branches = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final list = await _service.loadBranches(db);
    if (!mounted) return;
    setState(() {
      _branches = list;
      _loading = false;
    });
  }

  Future<void> _showDialog([Branche? branch]) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: branch?.name ?? '');
    final codeCtrl = TextEditingController(text: branch?.code ?? '');
    final addressCtrl = TextEditingController(text: branch?.address ?? '');
    final phoneCtrl = TextEditingController(text: branch?.phone ?? '');
    var isDefault = branch?.isDefault ?? false;
    var isActive = branch?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(branch == null ? l10n.addBranch : l10n.editBranch),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.branchName),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(labelText: l10n.branchCode),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(labelText: l10n.address),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(labelText: l10n.phone),
                ),
                SwitchListTile(
                  title: Text(l10n.defaultBranch),
                  value: isDefault,
                  onChanged: (v) => setDialogState(() => isDefault = v),
                ),
                SwitchListTile(
                  title: Text(l10n.active),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      codeCtrl.dispose();
      addressCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }

    final payload = BranchFormPayload(
      name: nameCtrl.text.trim(),
      code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      isDefault: isDefault,
      isActive: isActive,
    );
    nameCtrl.dispose();
    codeCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();

    try {
      await _service.saveBranch(
        ref.read(databaseProvider),
        branch: branch,
        payload: payload,
      );
      await _load();
      ref.invalidate(branchesProvider);
      if (mounted) AppFeedback.success(context, l10n.savedSuccessfully);
    } on BranchesException catch (e) {
      if (mounted) {
        AppFeedback.error(context, _branchError(l10n, e.code));
      }
    }
  }

  String _branchError(dynamic l10n, String code) => switch (code) {
    'default-branch' => l10n.cannotDeleteDefaultBranch,
    'has-invoices' => l10n.cannotDeleteBranchHasInvoices,
    _ => l10n.errorOccurred,
  };

  Future<void> _delete(Branche branch) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBranch),
        content: Text(l10n.deleteBranchMessage(branch.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteBranch(ref.read(databaseProvider), branch.id);
      await _load();
      ref.invalidate(branchesProvider);
      if (mounted) AppFeedback.success(context, l10n.deletedSuccessfully);
    } on BranchesException catch (e) {
      if (mounted) AppFeedback.error(context, _branchError(l10n, e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.branches,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addBranch),
                ),
              ],
            ),
            Text(
              l10n.branchesHint,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_branches.isEmpty)
              Text(l10n.noBranches)
            else
              ..._branches.map(
                (b) => ListTile(
                  title: Text(b.name),
                  subtitle: Text(
                    [
                      if (b.code != null) b.code!,
                      if (b.isDefault) l10n.defaultBranch,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showDialog(b),
                      ),
                      if (!b.isDefault)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.error,
                          ),
                          onPressed: () => _delete(b),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
