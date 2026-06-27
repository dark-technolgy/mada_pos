import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/settings/application/settings_service.dart';

void main() {
  const service = SettingsService();

  test('SettingsService loads seeded settings context', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await service.loadScreenData(database);

    expect(result.currencies, isNotEmpty);
    expect(result.defaultCurrencyCode, 'IQD');
    expect(result.usdRateText, isNotEmpty);
  });

  test(
    'SettingsService saves company profile theme locale and currency',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await service.saveSettings(
        database,
        payload: const SettingsSavePayload(
          companyName: 'Mada Stores',
          companyPhone: '7500000000',
          companyAddress: 'Erbil',
          themeMode: ThemeMode.light,
          localeCode: 'en',
          defaultCurrencyCode: 'USD',
          usdRate: 1495,
          taxRatePercent: 5,
          taxIncluded: false,
        ),
      );

      final settings = await database.select(database.settings).get();
      final settingsMap = {
        for (final setting in settings) setting.key: setting.value,
      };
      final currencies = await database.select(database.currencies).get();
      final usd = currencies.firstWhere((currency) => currency.code == 'USD');
      final defaultCurrency = currencies.firstWhere(
        (currency) => currency.isDefault,
      );

      expect(settingsMap['company_name'], 'Mada Stores');
      expect(settingsMap['company_phone'], '7500000000');
      expect(settingsMap['company_address'], 'Erbil');
      expect(settingsMap['theme_mode'], 'light');
      expect(settingsMap['language'], 'en');
      expect(usd.exchangeRate, 1495);
      expect(defaultCurrency.code, 'USD');

      final loaded = await service.loadScreenData(database);
      expect(loaded.companyName, 'Mada Stores');
      expect(loaded.companyPhone, '7500000000');
      expect(loaded.companyAddress, 'Erbil');
      expect(loaded.defaultCurrencyCode, 'USD');
      expect(loaded.usdRateText, '1495.0');
      expect(loaded.taxRatePercent, 5);
      expect(loaded.taxIncluded, isFalse);
    },
  );
}
