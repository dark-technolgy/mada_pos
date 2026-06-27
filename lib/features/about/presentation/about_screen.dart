import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/help_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/quick_tour_dialog.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: l10n.about, subtitle: AppConstants.appVersion),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: Text(l10n.quickTour),
                  subtitle: Text(l10n.setupWizardSubtitle),
                  onTap: () => QuickTourDialog.show(context),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l10n.userManual),
                  subtitle: Text(l10n.openUserManualHint),
                  onTap: () async {
                    try {
                      await HelpService.openUserManual(locale: locale);
                    } catch (e, st) {
                      await AppLogger.record(
                        'Open user manual',
                        error: e,
                        stackTrace: st,
                      );
                      if (!context.mounted) return;
                      AppFeedback.warning(context, l10n.manualNotFound);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(l10n.openLogs),
                  subtitle: Text(AppLogger.logFilePath ?? l10n.logsFolder),
                  onTap: () => HelpService.openLogsFolder(),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Mada Smart POS'),
                  subtitle: const Text('Baghdad, Iraq - بغداد، العراق'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
