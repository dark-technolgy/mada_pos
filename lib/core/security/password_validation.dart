import '../localization/generated/app_localizations.dart';

String? passwordValidationMessage(AppLocalizations l10n, String? code) {
  return switch (code) {
    'password-too-short' => l10n.passwordTooShort,
    'password-no-upper' => l10n.passwordNoUpper,
    'password-no-lower' => l10n.passwordNoLower,
    'password-no-digit' => l10n.passwordNoDigit,
    'current-password-invalid' => l10n.invalidCredentials,
    _ => code,
  };
}
