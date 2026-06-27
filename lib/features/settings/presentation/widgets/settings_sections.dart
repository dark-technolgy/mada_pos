import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/database.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.isDark,
    required this.children,
  });

  final String title;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
}

class SettingsCompanySection extends StatelessWidget {
  const SettingsCompanySection({
    super.key,
    required this.title,
    required this.companyNameLabel,
    required this.phoneLabel,
    required this.addressLabel,
    required this.companyLogoLabel,
    required this.pickLogoLabel,
    required this.companyNameController,
    required this.companyPhoneController,
    required this.companyAddressController,
    required this.logoPath,
    required this.onPickLogo,
    required this.isDark,
  });

  final String title;
  final String companyNameLabel;
  final String phoneLabel;
  final String addressLabel;
  final String companyLogoLabel;
  final String pickLogoLabel;
  final TextEditingController companyNameController;
  final TextEditingController companyPhoneController;
  final TextEditingController companyAddressController;
  final String? logoPath;
  final VoidCallback onPickLogo;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        TextField(
          controller: companyNameController,
          decoration: InputDecoration(
            labelText: companyNameLabel,
            prefixIcon: const Icon(Icons.business_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: companyPhoneController,
          decoration: InputDecoration(
            labelText: phoneLabel,
            prefixIcon: const Icon(Icons.phone_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: companyAddressController,
          decoration: InputDecoration(
            labelText: addressLabel,
            prefixIcon: const Icon(Icons.location_on_rounded),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Text(
          companyLogoLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (logoPath != null && File(logoPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(logoPath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  Icons.image_outlined,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onPickLogo,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(pickLogoLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsTaxSection extends StatelessWidget {
  const SettingsTaxSection({
    super.key,
    required this.title,
    required this.taxRateLabel,
    required this.taxIncludedLabel,
    required this.taxRateController,
    required this.taxIncluded,
    required this.onTaxIncludedChanged,
    required this.isDark,
  });

  final String title;
  final String taxRateLabel;
  final String taxIncludedLabel;
  final TextEditingController taxRateController;
  final bool taxIncluded;
  final ValueChanged<bool> onTaxIncludedChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        TextField(
          controller: taxRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: taxRateLabel,
            prefixIcon: const Icon(Icons.percent_rounded),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(taxIncludedLabel),
          value: taxIncluded,
          onChanged: onTaxIncludedChanged,
        ),
      ],
    );
  }
}

class SettingsAppearanceSection extends StatelessWidget {
  const SettingsAppearanceSection({
    super.key,
    required this.title,
    required this.optionTitle,
    required this.optionSubtitle,
    required this.isDark,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String optionTitle;
  final String optionSubtitle;
  final bool isDark;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        SettingsOptionTile(
          title: optionTitle,
          subtitle: optionSubtitle,
          icon: Icons.dark_mode_rounded,
          trailing: Switch(value: value, onChanged: onChanged),
          isDark: isDark,
        ),
      ],
    );
  }
}

class SettingsLanguageSection extends StatelessWidget {
  const SettingsLanguageSection({
    super.key,
    required this.title,
    required this.isDark,
    required this.currentLocale,
    required this.onLocaleSelected,
    required this.languages,
  });

  final String title;
  final bool isDark;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleSelected;
  final List<SettingsLanguageItem> languages;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        for (var index = 0; index < languages.length; index++) ...[
          SettingsLanguageOption(
            label: languages[index].label,
            locale: languages[index].locale,
            currentLocale: currentLocale,
            isDark: isDark,
            onTap: () => onLocaleSelected(languages[index].locale),
          ),
          if (index < languages.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class SettingsCurrencySection extends StatelessWidget {
  const SettingsCurrencySection({
    super.key,
    required this.title,
    required this.currencyLabel,
    required this.usdRateLabel,
    required this.dinarSuffix,
    required this.currentCurrencyLabel,
    required this.currencies,
    required this.defaultCurrencyCode,
    required this.onCurrencyChanged,
    required this.usdRateController,
    required this.isDark,
  });

  final String title;
  final String currencyLabel;
  final String usdRateLabel;
  final String dinarSuffix;
  final String currentCurrencyLabel;
  final List<Currency> currencies;
  final String defaultCurrencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final TextEditingController usdRateController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              currencies.any((currency) => currency.code == defaultCurrencyCode)
              ? defaultCurrencyCode
              : null,
          decoration: InputDecoration(
            labelText: currencyLabel,
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
          items: currencies
              .map(
                (currency) => DropdownMenuItem<String>(
                  value: currency.code,
                  child: Text('${currency.code} - ${currency.nameAr}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onCurrencyChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: usdRateController,
          decoration: InputDecoration(
            labelText: usdRateLabel,
            prefixIcon: const Icon(Icons.currency_exchange_rounded),
            suffixText: dinarSuffix,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Text(
          currentCurrencyLabel,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}

class SettingsBackupSection extends StatelessWidget {
  const SettingsBackupSection({
    super.key,
    required this.title,
    required this.autoBackupLabel,
    required this.autoBackupSubtitle,
    required this.intervalLabel,
    required this.hoursLabel,
    required this.autoBackupEnabled,
    required this.onAutoBackupChanged,
    required this.intervalController,
    required this.isDark,
  });

  final String title;
  final String autoBackupLabel;
  final String autoBackupSubtitle;
  final String intervalLabel;
  final String hoursLabel;
  final bool autoBackupEnabled;
  final ValueChanged<bool> onAutoBackupChanged;
  final TextEditingController intervalController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: [
        SettingsOptionTile(
          title: autoBackupLabel,
          subtitle: autoBackupSubtitle,
          icon: Icons.backup_rounded,
          trailing: Switch(
            value: autoBackupEnabled,
            onChanged: onAutoBackupChanged,
          ),
          isDark: isDark,
        ),
        if (autoBackupEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: intervalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: intervalLabel,
              prefixIcon: const Icon(Icons.timer_rounded),
              suffixText: hoursLabel,
            ),
          ),
        ],
      ],
    );
  }
}

class SettingsSystemInfoSection extends StatelessWidget {
  const SettingsSystemInfoSection({
    super.key,
    required this.title,
    required this.isDark,
    required this.entries,
  });

  final String title;
  final bool isDark;
  final List<SettingsInfoEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: title,
      isDark: isDark,
      children: entries
          .map(
            (entry) => SettingsInfoRow(
              label: entry.label,
              value: entry.value,
              isDark: isDark,
            ),
          )
          .toList(),
    );
  }
}

class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
}

class SettingsLanguageOption extends StatelessWidget {
  const SettingsLanguageOption({
    super.key,
    required this.label,
    required this.locale,
    required this.currentLocale,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final Locale currentLocale;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentLocale == locale;

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
      onTap: onTap,
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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

class SettingsLanguageItem {
  const SettingsLanguageItem({required this.label, required this.locale});

  final String label;
  final Locale locale;
}

class SettingsInfoEntry {
  const SettingsInfoEntry({required this.label, required this.value});

  final String label;
  final String value;
}
