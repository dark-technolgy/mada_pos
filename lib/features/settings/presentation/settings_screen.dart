import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';

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
  List<Currency> _currencies = const [];
  String _defaultCurrencyCode = 'IQD';
  bool _isSaving = false;

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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final settings = await db.select(db.settings).get();
    final currencies =
        await (db.select(db.currencies)..orderBy([
              (c) => OrderingTerm.desc(c.isDefault),
              (c) => OrderingTerm.asc(c.code),
            ]))
            .get();

    for (final s in settings) {
      switch (s.key) {
        case 'company_name':
          _companyNameCtrl.text = s.value;
          break;
        case 'company_phone':
          _companyPhoneCtrl.text = s.value;
          break;
        case 'company_address':
          _companyAddressCtrl.text = s.value;
          break;
      }
    }

    // Load USD rate
    final usdCurrency = await (db.select(
      db.currencies,
    )..where((c) => c.code.equals('USD'))).getSingleOrNull();
    if (usdCurrency != null) {
      _usdRateCtrl.text = usdCurrency.exchangeRate.toString();
    }

    if (!mounted) return;

    setState(() {
      _currencies = currencies;
      _defaultCurrencyCode =
          currencies
              .where((currency) => currency.isDefault)
              .firstOrNull
              ?.code ??
          'IQD';
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.settings)..where((s) => s.key.equals(key))).write(
        SettingsCompanion(value: Value(value)),
      );
    } else {
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: key, value: value));
    }
  }

  Future<void> _saveAll() async {
    final l10n = context.l10n;
    setState(() => _isSaving = true);
    try {
      await _saveSetting('company_name', _companyNameCtrl.text.trim());
      await _saveSetting('company_phone', _companyPhoneCtrl.text.trim());
      await _saveSetting('company_address', _companyAddressCtrl.text.trim());

      // Update USD rate
      final rate = double.tryParse(_usdRateCtrl.text);
      final db = ref.read(databaseProvider);
      if (rate != null && rate > 0) {
        await (db.update(db.currencies)..where((c) => c.code.equals('USD')))
            .write(CurrenciesCompanion(exchangeRate: Value(rate)));
      }

      await (db.update(db.currencies)..where((c) => c.isDefault.equals(true)))
          .write(const CurrenciesCompanion(isDefault: Value(false)));
      await (db.update(db.currencies)
            ..where((c) => c.code.equals(_defaultCurrencyCode)))
          .write(const CurrenciesCompanion(isDefault: Value(true)));

      ref.invalidate(currenciesProvider);
      ref.invalidate(currencyMapProvider);
      ref.invalidate(defaultCurrencyProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
                      // Company Info
                      Expanded(
                        child: _buildSection(l10n.companyInfo, [
                          TextField(
                            controller: _companyNameCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.companyName,
                              prefixIcon: Icon(Icons.business_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _companyPhoneCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.phone,
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _companyAddressCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.address,
                              prefixIcon: Icon(Icons.location_on_rounded),
                            ),
                            maxLines: 2,
                          ),
                        ], isDark),
                      ),
                      const SizedBox(width: 20),
                      // Appearance
                      Expanded(
                        child: Column(
                          children: [
                            _buildSection(l10n.appearance, [
                              _buildOptionTile(
                                l10n.darkMode,
                                l10n.enableDarkMode,
                                Icons.dark_mode_rounded,
                                trailing: Switch(
                                  value: themeMode == ThemeMode.dark,
                                  onChanged: (v) {
                                    ref.read(themeModeProvider.notifier).state =
                                        v ? ThemeMode.dark : ThemeMode.light;
                                  },
                                ),
                                isDark: isDark,
                              ),
                            ], isDark),
                            const SizedBox(height: 20),
                            _buildSection(l10n.language, [
                              _buildLanguageOption(
                                l10n.arabic,
                                const Locale('ar'),
                                locale,
                                isDark,
                              ),
                              const Divider(height: 1),
                              _buildLanguageOption(
                                l10n.english,
                                const Locale('en'),
                                locale,
                                isDark,
                              ),
                              const Divider(height: 1),
                              _buildLanguageOption(
                                l10n.kurdish,
                                const Locale('ku'),
                                locale,
                                isDark,
                              ),
                            ], isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currency
                      Expanded(
                        child: _buildSection(l10n.currencies, [
                          DropdownButtonFormField<String>(
                            initialValue:
                                _currencies.any(
                                  (currency) =>
                                      currency.code == _defaultCurrencyCode,
                                )
                                ? _defaultCurrencyCode
                                : null,
                            decoration: InputDecoration(
                              labelText: l10n.currency,
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                            items: _currencies
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency.code,
                                    child: Text(
                                      '${currency.code} - ${currency.nameAr}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _defaultCurrencyCode = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _usdRateCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.usdRateIqd,
                              prefixIcon: Icon(Icons.currency_exchange_rounded),
                              suffixText: l10n.dinarSuffix,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.currentCurrencyLabel(_defaultCurrencyCode),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ], isDark),
                      ),
                      const SizedBox(width: 20),
                      // System Info
                      Expanded(
                        child: _buildSection(l10n.systemInfo, [
                          _buildInfoRow(l10n.versionLabel, '1.0.0', isDark),
                          _buildInfoRow(l10n.developerLabel, 'KeenX', isDark),
                          _buildInfoRow(
                            l10n.databaseLabel,
                            l10n.localDatabase,
                            isDark,
                          ),
                          _buildInfoRow(
                            l10n.platformLabel,
                            l10n.desktop,
                            isDark,
                          ),
                        ], isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    String title,
    String subtitle,
    IconData icon, {
    required Widget trailing,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _buildLanguageOption(
    String label,
    Locale langLocale,
    Locale currentLocale,
    bool isDark,
  ) {
    final isSelected = currentLocale == langLocale;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? AppColors.primary
              : (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 20,
            )
          : null,
      onTap: () => ref.read(localeProvider.notifier).state = langLocale,
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
