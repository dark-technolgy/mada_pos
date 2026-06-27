import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;

import '../constants/app_constants.dart';
import '../database/database.dart';

enum LicenseStatus { trial, active, expired }

class LicenseInfo {
  const LicenseInfo({
    required this.status,
    required this.deviceId,
    this.trialDaysLeft,
  });

  final LicenseStatus status;
  final String deviceId;
  final int? trialDaysLeft;

  bool get canUseApp =>
      status == LicenseStatus.active || status == LicenseStatus.trial;
}

class LicenseService {
  const LicenseService();

  static const _installDateKey = 'license_install_date';
  static const _licenseKeySetting = 'license_key';
  static int get _trialDays => AppConstants.trialDays;

  Future<LicenseInfo> load(AppDatabase db) async {
    await _ensureInstallDate(db);
    final deviceId = await _deviceFingerprint();
    final storedKey = await _readSetting(db, _licenseKeySetting);

    if (storedKey != null && _validateKey(deviceId, storedKey)) {
      return LicenseInfo(status: LicenseStatus.active, deviceId: deviceId);
    }

    final installDate = DateTime.tryParse(
      await _readSetting(db, _installDateKey) ?? '',
    );
    if (installDate == null) {
      return LicenseInfo(status: LicenseStatus.expired, deviceId: deviceId);
    }

    final daysUsed = DateTime.now().difference(installDate).inDays;
    final left = _trialDays - daysUsed;
    if (left > 0) {
      return LicenseInfo(
        status: LicenseStatus.trial,
        deviceId: deviceId,
        trialDaysLeft: left,
      );
    }

    return LicenseInfo(status: LicenseStatus.expired, deviceId: deviceId);
  }

  Future<bool> activate(AppDatabase db, String key) async {
    final deviceId = await _deviceFingerprint();
    final normalized = key.trim().toUpperCase();
    if (!_validateKey(deviceId, normalized)) return false;

    await _upsert(db, _licenseKeySetting, normalized);
    return true;
  }

  static String generateKeyForDevice(String deviceId) {
    final digest = sha256.convert(
      utf8.encode('${AppConstants.licenseSecret}|$deviceId'),
    );
    final hex = digest.toString().substring(0, 16).toUpperCase();
    return 'MADA-${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  static bool _validateKey(String deviceId, String key) {
    final expected = generateKeyForDevice(deviceId);
    return key.trim().toUpperCase() == expected;
  }

  static Future<String> _deviceFingerprint() async {
    String biosUuid = '';
    if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-Command',
            'Get-CimInstance -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID',
          ],
        );
        biosUuid = result.stdout.toString().trim();
      } catch (_) {}
    }

    final parts = <String>[
      biosUuid.isNotEmpty ? biosUuid : Platform.localHostname,
      Platform.environment['USERNAME'] ?? '',
      Platform.environment['COMPUTERNAME'] ?? '',
      AppConstants.appVersion,
    ];
    final digest = sha256.convert(utf8.encode(parts.join('|')));
    return digest.toString().substring(0, 24).toUpperCase();
  }

  Future<void> _ensureInstallDate(AppDatabase db) async {
    final existing = await _readSetting(db, _installDateKey);
    if (existing != null && existing.isNotEmpty) return;
    await _upsert(db, _installDateKey, DateTime.now().toIso8601String());
  }

  Future<String?> _readSetting(AppDatabase db, String key) async {
    final row = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _upsert(AppDatabase db, String key, String value) async {
    final existing = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.settings).insert(
            SettingsCompanion.insert(key: key, value: value),
          );
    } else {
      await (db.update(db.settings)..where((s) => s.key.equals(key))).write(
            SettingsCompanion(value: Value(value)),
          );
    }
  }
}
