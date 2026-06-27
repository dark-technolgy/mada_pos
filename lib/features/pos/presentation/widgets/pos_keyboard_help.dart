import 'package:flutter/material.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';

class PosKeyboardHelpDialog extends StatelessWidget {
  const PosKeyboardHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const PosKeyboardHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(l10n.keyboardShortcutsTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShortcutRow(keys: 'F2', action: l10n.shortcutFocusSearch),
            _ShortcutRow(keys: 'F3', action: l10n.shortcutFocusBarcode),
            _ShortcutRow(keys: 'F4', action: l10n.shortcutCompleteSale),
            _ShortcutRow(keys: 'F6', action: l10n.shortcutHoldInvoice),
            _ShortcutRow(keys: 'F7', action: l10n.shortcutRecallInvoice),
            _ShortcutRow(keys: 'Esc', action: l10n.shortcutClearCart),
            _ShortcutRow(keys: 'F1', action: l10n.shortcutShowHelp),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.close,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(action)),
        ],
      ),
    );
  }
}
