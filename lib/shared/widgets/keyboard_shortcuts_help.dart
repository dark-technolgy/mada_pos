import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/theme/app_colors.dart';

/// Global keyboard shortcuts reference (F1).
class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const KeyboardShortcutsHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPos = GoRouterState.of(context).matchedLocation.startsWith('/pos');

    return AlertDialog(
      title: Text(l10n.keyboardShortcutsTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(l10n.shortcutsGlobalSection),
              _ShortcutRow(keys: 'Ctrl+K', action: l10n.commandPaletteTitle),
              _ShortcutRow(
                keys: 'Ctrl+Shift+F',
                action: l10n.globalSearchHint,
              ),
              _ShortcutRow(keys: 'F1', action: l10n.shortcutShowHelp),
              const SizedBox(height: 12),
              _SectionTitle(l10n.shortcutsPosSection),
              _ShortcutRow(keys: 'F2', action: l10n.shortcutFocusSearch),
              _ShortcutRow(keys: 'F3', action: l10n.shortcutFocusBarcode),
              _ShortcutRow(keys: 'F4', action: l10n.shortcutCompleteSale),
              _ShortcutRow(keys: 'F5', action: l10n.splitPayment),
              _ShortcutRow(keys: 'Esc', action: l10n.shortcutClearCart),
              if (onPos)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.shortcutsPosActiveHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
          const SizedBox(width: 14),
          Expanded(child: Text(action)),
        ],
      ),
    );
  }
}
