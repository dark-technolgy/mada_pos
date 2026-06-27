import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/services/global_search_service.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'compact_layout.dart';
import 'keyboard_shortcuts_help.dart';

class _OpenGlobalSearchIntent extends Intent {
  const _OpenGlobalSearchIntent();
}

/// Wraps shell content with a global search field (Ctrl+Shift+F).
class GlobalSearchScope extends ConsumerWidget {
  const GlobalSearchScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
            _OpenGlobalSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true):
            _OpenGlobalSearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenGlobalSearchIntent: CallbackAction<_OpenGlobalSearchIntent>(
            onInvoke: (_) {
              _GlobalSearchDialog.show(context, ref);
              return null;
            },
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _GlobalSearchBarStrip(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlobalSearchBarStrip extends ConsumerWidget {
  const _GlobalSearchBarStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = CompactLayout.isCompact(ref);
    final hPad = CompactLayout.pagePadding(ref);

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: InkWell(
        onTap: () => _GlobalSearchDialog.show(context, ref),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: hPad,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.globalSearchHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ctrl+Shift+F',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.keyboardShortcutsTitle,
                icon: const Icon(Icons.keyboard_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => KeyboardShortcutsHelpDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalSearchDialog extends ConsumerStatefulWidget {
  const _GlobalSearchDialog();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => const _GlobalSearchDialog(),
    );
  }

  @override
  ConsumerState<_GlobalSearchDialog> createState() =>
      _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<_GlobalSearchDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _service = const GlobalSearchService();
  Timer? _debounce;
  List<GlobalSearchResult> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text;
    if (query.trim().length < 2) {
      if (mounted) setState(() => _results = const []);
      return;
    }

    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final results = await _service.search(db, query: query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  void _select(GlobalSearchResult result) {
    Navigator.of(context).pop();
    if (result.invoiceId != null) {
      ref.read(pendingInvoiceSearchProvider.notifier).state =
          result.title;
    }
    context.go(result.route);
  }

  IconData _iconFor(GlobalSearchResultType type) => switch (type) {
    GlobalSearchResultType.product => Icons.inventory_2_outlined,
    GlobalSearchResultType.customer => Icons.person_outline_rounded,
    GlobalSearchResultType.invoice => Icons.receipt_long_outlined,
  };

  String _sectionLabel(GlobalSearchResultType type) {
    final l10n = context.l10n;
    return switch (type) {
      GlobalSearchResultType.product => l10n.globalSearchProducts,
      GlobalSearchResultType.customer => l10n.globalSearchCustomers,
      GlobalSearchResultType.invoice => l10n.globalSearchInvoices,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width.clamp(360.0, 640.0);

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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.globalSearchHint,
                  ),
                  onSubmitted: (_) {
                    if (_results.isNotEmpty) _select(_results.first);
                  },
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )
              else if (_controller.text.trim().length >= 2 &&
                  _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.commandPaletteNoResults),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final showHeader = index == 0 ||
                          _results[index - 1].type != result.type;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                4,
                              ),
                              child: Text(
                                _sectionLabel(result.type),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                          ListTile(
                            leading: Icon(_iconFor(result.type), size: 22),
                            title: Text(result.title),
                            subtitle: result.subtitle != null
                                ? Text(result.subtitle!)
                                : null,
                            onTap: () => _select(result),
                          ),
                        ],
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
