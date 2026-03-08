class AppConstants {
  AppConstants._();

  static const String appName = 'KeenX POS';
  static const String appNameAr = 'كينكس للمبيعات';
  static const String companyName = 'KeenX';
  static const String companyAddress = 'Baghdad, Iraq - بغداد، العراق';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'keenx_pos.db';
  static const int dbVersion = 1;

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
  static const String backupFolder = 'keenx_backups';
}
