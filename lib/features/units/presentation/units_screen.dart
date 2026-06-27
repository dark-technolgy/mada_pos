import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/units_service.dart';

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen> {
  final UnitsService _service = const UnitsService();
  List<Unit> _units = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final units = await _service.loadUnits(db);
    if (mounted) setState(() => _units = units);
  }

  Future<void> _showDialog([Unit? unit]) async {
    final l10n = context.l10n;
    final nameAr = TextEditingController(text: unit?.nameAr ?? '');
    final nameEn = TextEditingController(text: unit?.nameEn ?? '');
    final abbr = TextEditingController(text: unit?.abbreviation ?? '');
    var isActive = unit?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(unit == null ? l10n.addUnit : l10n.editUnit),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameAr,
                  decoration: InputDecoration(labelText: l10n.nameAr),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameEn,
                  decoration: InputDecoration(labelText: l10n.nameEn),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: abbr,
                  decoration: InputDecoration(labelText: l10n.abbreviation),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.active),
                  value: isActive,
                  onChanged: (v) => setDialog(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true || nameAr.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    try {
      await _service.saveUnit(
        db,
        unit: unit,
        payload: UnitFormPayload(
          nameAr: nameAr.text.trim(),
          nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
          abbreviation: abbr.text.trim().isEmpty ? null : abbr.text.trim(),
          isActive: isActive,
        ),
      );
      await _load();
    } on UnitsException {
      if (!mounted) return;
      AppFeedback.error(context, l10n.cannotDeleteUnitInUse);
    }
  }

  Future<void> _delete(Unit unit) async {
    final l10n = context.l10n;
    final ok = await ConfirmationDialog.show(
      context,
      title: l10n.deleteUnitTitle,
      message: l10n.deleteUnitMessage(unit.nameAr),
      confirmText: l10n.delete,
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    try {
      await _service.deleteUnit(db, unit.id);
      await _load();
    } on UnitsException {
      if (!mounted) return;
      AppFeedback.error(context, l10n.cannotDeleteUnitInUse);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.units,
            subtitle: '${_units.length} ${l10n.items}',
            actions: [
              ElevatedButton.icon(
                onPressed: () => _showDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addUnit),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _units.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final unit = _units[index];
                return ListTile(
                  tileColor:
                      isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  title: Text(unit.nameAr),
                  subtitle: Text(
                    [
                      if (unit.nameEn != null) unit.nameEn!,
                      if (unit.abbreviation != null) unit.abbreviation!,
                      if (!unit.isActive) l10n.inactive,
                    ].join(' • '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _showDialog(unit);
                      } else if (v == 'delete') {
                        _delete(unit);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
