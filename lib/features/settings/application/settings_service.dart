import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/database/database.dart';
import '../../../core/utils/tax_settings.dart';

class SettingsLoadResult {
  const SettingsLoadResult({
    required this.companyName,
    required this.companyPhone,
    required this.companyAddress,
    required this.usdRateText,
    required this.currencies,
    required this.defaultCurrencyCode,
    required this.taxRatePercent,
    required this.taxIncluded,
    required this.autoBackupEnabled,
    required this.backupIntervalHours,
    this.companyLogoPath,
  });

  final String companyName;
  final String companyPhone;
  final String companyAddress;
  final String usdRateText;
  final List<Currency> currencies;
  final String defaultCurrencyCode;
  final double taxRatePercent;
  final bool taxIncluded;
  final bool autoBackupEnabled;
  final int backupIntervalHours;
  final String? companyLogoPath;
}

class SettingsSavePayload {
  const SettingsSavePayload({
    required this.companyName,
    required this.companyPhone,
    required this.companyAddress,
    required this.themeMode,
    required this.localeCode,
    required this.defaultCurrencyCode,
    this.usdRate,
    required this.taxRatePercent,
    required this.taxIncluded,
    required this.autoBackupEnabled,
    required this.backupIntervalHours,
    this.companyLogoPath,
  });

  final String companyName;
  final String companyPhone;
  final String companyAddress;
  final String? companyLogoPath;
  final ThemeMode themeMode;
  final String localeCode;
  final String defaultCurrencyCode;
  final double? usdRate;
  final double taxRatePercent;
  final bool taxIncluded;
  final bool autoBackupEnabled;
  final int backupIntervalHours;
}

class SettingsService {
  const SettingsService();

  Future<SettingsLoadResult> loadScreenData(AppDatabase db) async {
    final settings = await db.select(db.settings).get();
    final currencies =
        await (db.select(db.currencies)..orderBy([
              (currency) => OrderingTerm.desc(currency.isDefault),
              (currency) => OrderingTerm.asc(currency.code),
            ]))
            .get();
    final usdCurrency = await (db.select(
      db.currencies,
    )..where((currency) => currency.code.equals('USD'))).getSingleOrNull();
    final settingsMap = {
      for (final setting in settings) setting.key: setting.value,
    };

    final taxSettings = await TaxSettingsLoader.load(db);

    return SettingsLoadResult(
      companyName: settingsMap['company_name'] ?? '',
      companyPhone: settingsMap['company_phone'] ?? '',
      companyAddress: settingsMap['company_address'] ?? '',
      usdRateText: usdCurrency?.exchangeRate.toString() ?? '',
      currencies: currencies,
      defaultCurrencyCode:
          currencies
              .where((currency) => currency.isDefault)
              .firstOrNull
              ?.code ??
          'IQD',
      taxRatePercent: taxSettings.ratePercent,
      taxIncluded: taxSettings.taxIncluded,
      autoBackupEnabled: settingsMap['auto_backup'] == 'true',
      backupIntervalHours:
          int.tryParse(settingsMap['backup_interval_hours'] ?? '') ?? 24,
      companyLogoPath: settingsMap['company_logo_path'],
    );
  }

  Future<void> saveSettings(
    AppDatabase db, {
    required SettingsSavePayload payload,
  }) async {
    await db.transaction(() async {
      await _upsertSetting(db, 'company_name', payload.companyName);
      await _upsertSetting(db, 'company_phone', payload.companyPhone);
      await _upsertSetting(db, 'company_address', payload.companyAddress);
      if (payload.companyLogoPath != null) {
        await _upsertSetting(db, 'company_logo_path', payload.companyLogoPath!);
      }
      await _upsertSetting(
        db,
        'theme_mode',
        _themeModeValue(payload.themeMode),
      );
      await _upsertSetting(db, 'language', payload.localeCode);

      if (payload.usdRate != null && payload.usdRate! > 0) {
        await (db.update(db.currencies)
              ..where((currency) => currency.code.equals('USD')))
            .write(CurrenciesCompanion(exchangeRate: Value(payload.usdRate!)));
      }

      await (db.update(db.currencies)
            ..where((currency) => currency.isDefault.equals(true)))
          .write(const CurrenciesCompanion(isDefault: Value(false)));
      await (db.update(db.currencies)..where(
            (currency) => currency.code.equals(payload.defaultCurrencyCode),
          ))
          .write(const CurrenciesCompanion(isDefault: Value(true)));

      await TaxSettingsLoader.save(
        db,
        ratePercent: payload.taxRatePercent.clamp(0, 100),
        taxIncluded: payload.taxIncluded,
      );

      await _upsertSetting(
        db,
        'auto_backup',
        payload.autoBackupEnabled ? 'true' : 'false',
      );
      await _upsertSetting(
        db,
        'backup_interval_hours',
        payload.backupIntervalHours.toString(),
      );
    });
  }

  Future<void> _upsertSetting(AppDatabase db, String key, String value) async {
    final existing = await (db.select(
      db.settings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.settings)
            ..where((setting) => setting.key.equals(key)))
          .write(SettingsCompanion(value: Value(value)));
      return;
    }

    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: key, value: value));
  }

  String _themeModeValue(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
  }
}
