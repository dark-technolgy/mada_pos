import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../core/services/ui_preferences_service.dart';
import '../application/settings_service.dart';
import 'widgets/settings_sections.dart';
import 'widgets/role_permissions_section.dart';
import '../../../shared/widgets/compact_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyNameCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();
  final _usdRateCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _backupIntervalCtrl = TextEditingController();
  final SettingsService _settingsService = const SettingsService();
  List<Currency> _currencies = const [];
  String _defaultCurrencyCode = 'IQD';
  bool _taxIncluded = false;
  bool _autoBackupEnabled = false;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _companyLogoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyAddressCtrl.dispose();
    _usdRateCtrl.dispose();
    _taxRateCtrl.dispose();
    _backupIntervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final result = await _settingsService.loadScreenData(db);

    _companyNameCtrl.text = result.companyName;
    _companyPhoneCtrl.text = result.companyPhone;
    _companyAddressCtrl.text = result.companyAddress;
    _usdRateCtrl.text = result.usdRateText;
    _taxRateCtrl.text = result.taxRatePercent == 0
        ? ''
        : result.taxRatePercent.toString();
    _backupIntervalCtrl.text = result.backupIntervalHours.toString();

    if (!mounted) return;

    setState(() {
      _currencies = result.currencies;
      _defaultCurrencyCode = result.defaultCurrencyCode;
      _taxIncluded = result.taxIncluded;
      _autoBackupEnabled = result.autoBackupEnabled;
      _companyLogoPath = result.companyLogoPath;
      _isLoading = false;
    });
  }

  Future<void> _pickCompanyLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    setState(() => _companyLogoPath = path);
  }

  Future<void> _saveAll() async {
    final l10n = context.l10n;
    final themeMode = ref.read(themeModeProvider);
    final locale = ref.read(localeProvider);
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      await _settingsService.saveSettings(
        db,
        payload: SettingsSavePayload(
          companyName: _companyNameCtrl.text.trim(),
          companyPhone: _companyPhoneCtrl.text.trim(),
          companyAddress: _companyAddressCtrl.text.trim(),
          themeMode: themeMode,
          localeCode: locale.languageCode,
          defaultCurrencyCode: _defaultCurrencyCode,
          usdRate: double.tryParse(_usdRateCtrl.text),
          taxRatePercent: double.tryParse(_taxRateCtrl.text) ?? 0,
          taxIncluded: _taxIncluded,
          autoBackupEnabled: _autoBackupEnabled,
          backupIntervalHours: int.tryParse(_backupIntervalCtrl.text) ?? 24,
          companyLogoPath: _companyLogoPath,
        ),
      );

      ref.invalidate(currenciesProvider);
      ref.invalidate(currencyMapProvider);
      ref.invalidate(defaultCurrencyProvider);

      if (mounted) {
        AppFeedback.success(context, l10n.savedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.error}: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: LoadingView(message: l10n.loading),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.settings,
            subtitle: l10n.systemPreferences,
            actions: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAll,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? l10n.saving : l10n.saveSettings),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SettingsCompanySection(
                          title: l10n.companyInfo,
                          companyNameLabel: l10n.companyName,
                          phoneLabel: l10n.phone,
                          addressLabel: l10n.address,
                          companyLogoLabel: l10n.companyLogo,
                          pickLogoLabel: l10n.pickCompanyLogo,
                          companyNameController: _companyNameCtrl,
                          companyPhoneController: _companyPhoneCtrl,
                          companyAddressController: _companyAddressCtrl,
                          logoPath: _companyLogoPath,
                          onPickLogo: _pickCompanyLogo,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            SettingsAppearanceSection(
                              title: l10n.appearance,
                              optionTitle: l10n.darkMode,
                              optionSubtitle: l10n.enableDarkMode,
                              isDark: isDark,
                              value: themeMode == ThemeMode.dark,
                              onChanged: (value) {
                                ref.read(themeModeProvider.notifier).state =
                                    value ? ThemeMode.dark : ThemeMode.light;
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            SettingsSectionCard(
                              title: l10n.compactLayout,
                              isDark: isDark,
                              children: [
                                SettingsOptionTile(
                                  title: l10n.compactLayout,
                                  subtitle: l10n.compactLayoutHint,
                                  icon: Icons.view_compact_rounded,
                                  trailing: Switch(
                                    value: ref.watch(compactLayoutProvider),
                                    onChanged: (value) async {
                                      ref
                                          .read(compactLayoutProvider.notifier)
                                          .state = value;
                                      final db = ref.read(databaseProvider);
                                      await const UiPreferencesService().write(
                                        db,
                                        CompactLayout.settingsKey,
                                        value ? 'true' : 'false',
                                      );
                                      setState(() {});
                                    },
                                  ),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SettingsLanguageSection(
                              title: l10n.language,
                              isDark: isDark,
                              currentLocale: locale,
                              languages: [
                                SettingsLanguageItem(
                                  label: l10n.arabic,
                                  locale: const Locale('ar'),
                                ),
                                SettingsLanguageItem(
                                  label: l10n.english,
                                  locale: const Locale('en'),
                                ),
                                SettingsLanguageItem(
                                  label: l10n.kurdish,
                                  locale: const Locale('ku'),
                                ),
                              ],
                              onLocaleSelected: (selectedLocale) {
                                ref.read(localeProvider.notifier).state =
                                    selectedLocale;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsTaxSection(
                    title: l10n.taxSettings,
                    taxRateLabel: l10n.taxRatePercent,
                    taxIncludedLabel: l10n.taxIncludedInPrice,
                    taxRateController: _taxRateCtrl,
                    taxIncluded: _taxIncluded,
                    onTaxIncludedChanged: (value) =>
                        setState(() => _taxIncluded = value),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  SettingsBackupSection(
                    title: l10n.backup,
                    autoBackupLabel: l10n.autoBackupEnabled,
                    autoBackupSubtitle: l10n.backupInfoMessage,
                    intervalLabel: l10n.backupIntervalHours,
                    hoursLabel: l10n.hour,
                    autoBackupEnabled: _autoBackupEnabled,
                    onAutoBackupChanged: (value) =>
                        setState(() => _autoBackupEnabled = value),
                    intervalController: _backupIntervalCtrl,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SettingsCurrencySection(
                          title: l10n.currencies,
                          currencyLabel: l10n.currency,
                          usdRateLabel: l10n.usdRateIqd,
                          dinarSuffix: l10n.dinarSuffix,
                          currentCurrencyLabel: l10n.currentCurrencyLabel(
                            _defaultCurrencyCode,
                          ),
                          currencies: _currencies,
                          defaultCurrencyCode: _defaultCurrencyCode,
                          onCurrencyChanged: (value) {
                            setState(() => _defaultCurrencyCode = value);
                          },
                          usdRateController: _usdRateCtrl,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SettingsSystemInfoSection(
                          title: l10n.systemInfo,
                          isDark: isDark,
                          entries: [
                            SettingsInfoEntry(
                              label: l10n.versionLabel,
                              value: '1.0.0',
                            ),
                            SettingsInfoEntry(
                              label: l10n.developerLabel,
                              value: 'Mada',
                            ),
                            SettingsInfoEntry(
                              label: l10n.databaseLabel,
                              value: l10n.localDatabase,
                            ),
                            SettingsInfoEntry(
                              label: l10n.platformLabel,
                              value: l10n.desktop,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (ref.watch(sessionManagerProvider).isAdmin) ...[
                    const RolePermissionsSection(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
