class AppConstants {
  AppConstants._();

  static const String appName = 'Mada Smart POS';
  static const String appNameAr = 'مدى للمبيعات الذكية';
  static const String companyName = 'Mada';
  static const String companyAddress = 'Baghdad, Iraq - بغداد، العراق';
  static const String appVersion = '1.0.0';
  static const int trialDays = 30;

  /// Used to generate per-device license keys (keep private in your org).
  static const String licenseSecret = 'mada-pos-license-v1';

  // Database
  static const String dbName = 'mada_pos.db';
  static const int dbVersion = 6;

  // Session
  static const int sessionTimeoutMinutes = 30;
  static const int pinLockTimeoutMinutes = 5;

  // Invoice
  static const String invoicePrefix = 'INV';
  static const String purchasePrefix = 'PUR';
  static const String returnPrefix = 'RET';
  static const String quotePrefix = 'QOT';

  // Pagination
  static const int defaultPageSize = 50;

  // Currency
  static const String defaultCurrencyCode = 'IQD';
  static const String defaultCurrencySymbol = 'د.ع';

  // Backup
  static const String backupFolder = 'mada_backups';

  // Supabase
  static const String supabaseUrl = 'https://xuafnfxlhoaweumsoqww.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
