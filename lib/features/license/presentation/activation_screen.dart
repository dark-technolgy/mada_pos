import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_service.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/license_provider.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _keyCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await const LicenseService().activate(
      ref.read(databaseProvider),
      _keyCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(licenseInfoProvider);
      context.go('/login');
    } else {
      setState(() {
        _busy = false;
        _error = l10n.invalidLicenseKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = ref.watch(licenseInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: info.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (license) {
                  final trialText = license.trialDaysLeft != null
                      ? l10n.trialDaysLeft(license.trialDaysLeft!)
                      : null;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.activateLicense,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        license.status == LicenseStatus.expired
                            ? l10n.licenseExpiredMessage
                            : l10n.licenseTrialMessage,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (trialText != null) ...[
                        const SizedBox(height: 8),
                        Text(trialText),
                      ],
                      const SizedBox(height: 16),
                      SelectableText(
                        '${l10n.deviceId}: ${license.deviceId}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: license.deviceId),
                          );
                          AppFeedback.info(context, l10n.copied);
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l10n.copyDeviceId),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _keyCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.licenseKey,
                          border: const OutlineInputBorder(),
                          errorText: _error,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _activate,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.activate),
                      ),
                      if (license.status == LicenseStatus.trial) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : () => context.go('/login'),
                          child: Text(l10n.continueTrial),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
