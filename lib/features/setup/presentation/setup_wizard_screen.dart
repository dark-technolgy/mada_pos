import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../settings/application/settings_service.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();
  final _usdRateCtrl = TextEditingController(text: '1480');
  String _selectedLanguage = 'ar';
  int _currentPage = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _companyNameCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyAddressCtrl.dispose();
    _usdRateCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1 && !_formKey.currentState!.validate()) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      const service = SettingsService();
      
      await service.saveSettings(
        db,
        payload: SettingsSavePayload(
          companyName: _companyNameCtrl.text.trim(),
          companyPhone: _companyPhoneCtrl.text.trim(),
          companyAddress: _companyAddressCtrl.text.trim(),
          themeMode: ThemeMode.dark,
          localeCode: _selectedLanguage,
          defaultCurrencyCode: 'IQD',
          usdRate: double.tryParse(_usdRateCtrl.text),
          taxRatePercent: 0,
          taxIncluded: false,
          autoBackupEnabled: true,
          backupIntervalHours: 24,
        ),
      );

      // Mark setup as finished
      final setupFinished = await (db.select(db.settings)..where((s) => s.key.equals('setup_finished'))).getSingleOrNull();
      if (setupFinished == null) {
        await db.into(db.settings).insert(SettingsCompanion.insert(key: 'setup_finished', value: 'true'));
      } else {
        await (db.update(db.settings)..where((s) => s.key.equals('setup_finished')))
            .write(const SettingsCompanion(value: Value('true')));
      }

      ref.invalidate(appBootstrapProvider);
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildWelcomeStep(l10n),
                    _buildCompanyStep(l10n),
                    _buildFinishStep(l10n),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton(
                    onPressed: _isSaving ? null : (_currentPage == 2 ? _finish : _nextPage),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentPage == 2 ? l10n.startUsingApp : l10n.next),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(dynamic l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          l10n.welcomeToMada,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.setupWizardSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 32),
        _buildLanguageSelector(),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختر اللغة / Select Language', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          children: [
            _langBtn('ar', 'العربية'),
            const SizedBox(width: 12),
            _langBtn('en', 'English'),
          ],
        ),
      ],
    );
  }

  Widget _langBtn(String code, String label) {
    final active = _selectedLanguage == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(color: active ? AppColors.primary : AppColors.darkBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: active ? AppColors.primary : Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCompanyStep(dynamic l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.companyInfo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          _field(_companyNameCtrl, l10n.companyName, required: true),
          _field(_companyPhoneCtrl, l10n.phone),
          _field(_companyAddressCtrl, l10n.address),
          _field(_usdRateCtrl, l10n.usdRateIqd, isNumber: true),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => v == null || v.isEmpty ? 'مطلوب' : null : null,
      ),
    );
  }

  Widget _buildFinishStep(dynamic l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        Text(l10n.allSet, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(l10n.readyToStartMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.darkTextSecondary)),
      ],
    );
  }
}
