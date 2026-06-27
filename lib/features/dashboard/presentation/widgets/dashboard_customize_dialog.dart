import 'package:flutter/material.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../application/dashboard_layout_prefs.dart';

class DashboardCustomizeDialog extends StatefulWidget {
  const DashboardCustomizeDialog({super.key, required this.initial});

  final DashboardLayoutPrefs initial;

  static Future<DashboardLayoutPrefs?> show(
    BuildContext context, {
    required DashboardLayoutPrefs initial,
  }) {
    return showDialog<DashboardLayoutPrefs>(
      context: context,
      builder: (context) => DashboardCustomizeDialog(initial: initial),
    );
  }

  @override
  State<DashboardCustomizeDialog> createState() =>
      _DashboardCustomizeDialogState();
}

class _DashboardCustomizeDialogState extends State<DashboardCustomizeDialog> {
  late DashboardLayoutPrefs _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.dashboardCustomize),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(l10n.dashboardShowStats),
              value: _prefs.showStats,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(showStats: v)),
            ),
            SwitchListTile(
              title: Text(l10n.dashboardShowInsights),
              value: _prefs.showSmartInsights,
              onChanged: (v) => setState(
                () => _prefs = _prefs.copyWith(showSmartInsights: v),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.dashboardShowRecentTransactions),
              value: _prefs.showRecentTransactions,
              onChanged: (v) => setState(
                () => _prefs = _prefs.copyWith(showRecentTransactions: v),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.dashboardShowLowStock),
              value: _prefs.showLowStock,
              onChanged: (v) => setState(
                () => _prefs = _prefs.copyWith(showLowStock: v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, DashboardLayoutPrefs.defaults),
          child: Text(l10n.resetToDefaults),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _prefs),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
