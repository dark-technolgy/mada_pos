import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/cash_register_service.dart';

class CashRegisterScreen extends ConsumerStatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  ConsumerState<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends ConsumerState<CashRegisterScreen> {
  final _service = const CashRegisterService();
  final _expectedCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _closeNotesCtrl = TextEditingController();
  CashRegisterData? _shift;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _expectedCtrl.dispose();
    _actualCtrl.dispose();
    _closeNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final db = ref.read(databaseProvider);
    await _service.ensureActiveShift(db, userId: user.id);
    final shift = await _service.activeShiftForUser(db, user.id);
    if (!mounted) return;
    setState(() {
      _shift = shift;
      _loading = false;
      if (shift != null) {
        _expectedCtrl.text = shift.openingAmount.toStringAsFixed(0);
      }
    });
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', ''));

  Future<void> _closeShift() async {
    final l10n = context.l10n;
    final shift = _shift;
    if (shift == null) return;
    final expected = _parse(_expectedCtrl.text);
    final actual = _parse(_actualCtrl.text);
    if (expected == null || actual == null) {
      AppFeedback.error(context, l10n.invalidCashAmount);
      return;
    }
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await _service.closeShift(
        db,
        shiftId: shift.id,
        expectedClosing: expected,
        actualAmount: actual,
        notes: _closeNotesCtrl.text.trim().isEmpty
            ? null
            : _closeNotesCtrl.text.trim(),
      );
      if (!mounted) return;
      AppFeedback.success(context, l10n.cashRegisterClosed);
      _actualCtrl.clear();
      _closeNotesCtrl.clear();
      await _refresh();
    } on CashRegisterException catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, l10n.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    if (_loading) {
      return Scaffold(
        body: LoadingView(message: l10n.loading),
      );
    }

    final shift = _shift;
    final expected = _parse(_expectedCtrl.text) ?? 0.0;
    final actual = _parse(_actualCtrl.text);
    final diff = actual != null ? actual - expected : null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: l10n.cashRegister, subtitle: user?.fullName ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      boxShadow: AppColors.cardShadow(isDark),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: shift == null
                          ? Center(
                              child: Text(
                                l10n.error,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.cashRegisterOpen,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${l10n.openingBalance}: ${shift.openingAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                Text(
                                  '${l10n.date}: ${shift.openedAt.toLocal()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _expectedCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.expectedInDrawer,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _actualCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.countedCash,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (diff != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${l10n.difference}: ${diff.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: diff.abs() < 1e-9
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _closeNotesCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.adjustmentNotesOptional,
                                    border: const OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _busy ? null : _closeShift,
                                  child: Text(l10n.closeCashRegister),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
