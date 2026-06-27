import 'package:flutter/material.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/theme/app_colors.dart';

class QuickTourDialog extends StatefulWidget {
  const QuickTourDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QuickTourDialog(),
    );
  }

  @override
  State<QuickTourDialog> createState() => _QuickTourDialogState();
}

class _QuickTourDialogState extends State<QuickTourDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = [
      _TourStep(
        title: l10n.tourStep1Title,
        content: l10n.tourStep1Content,
        icon: Icons.point_of_sale_rounded,
        color: AppColors.primary,
      ),
      _TourStep(
        title: l10n.tourStep2Title,
        content: l10n.tourStep2Content,
        icon: Icons.inventory_2_rounded,
        color: AppColors.warning,
      ),
      _TourStep(
        title: l10n.tourStep3Title,
        content: l10n.tourStep3Content,
        icon: Icons.analytics_rounded,
        color: AppColors.success,
      ),
      _TourStep(
        title: l10n.tourStep4Title,
        content: l10n.tourStep4Content,
        icon: Icons.security_rounded,
        color: AppColors.info,
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Container(
        width: 450,
        height: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final step = steps[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(step.icon, size: 80, color: step.color),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    steps.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == i
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (_currentPage < steps.length - 1)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage < steps.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        _currentPage < steps.length - 1
                            ? l10n.next
                            : l10n.close,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TourStep {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _TourStep({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });
}
