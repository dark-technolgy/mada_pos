import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../../../core/logging/app_logger.dart';
import 'backup_service.dart';

/// Runs a local DB backup when [auto_backup] is enabled and the interval elapsed.
class AutoBackupService {
  const AutoBackupService();

  static const lastAutoBackupAtKey = 'last_auto_backup_at';

  Future<void> runIfDue(AppDatabase db, {
    bool force = false,
    bool ignoreInterval = false,
  }) async {
    final autoOn = await _read(db, 'auto_backup');
    if (autoOn != 'true' && !force) return;

    if (!force && !ignoreInterval) {
      final hoursRaw = await _read(db, 'backup_interval_hours');
      final hours = int.tryParse(hoursRaw ?? '') ?? 24;
      if (hours <= 0) return;

      final lastRaw = await _read(db, lastAutoBackupAtKey);
      final last = (lastRaw == null || lastRaw.isEmpty)
          ? null
          : DateTime.tryParse(lastRaw);
      final now = DateTime.now();
      if (last != null && now.difference(last) < Duration(hours: hours)) {
        return;
      }
    }

    try {
      final dbFile = await resolveAppDatabaseFile();
      const backupSvc = BackupService();
      final dir = await backupSvc.ensureBackupDirectory();
      final cloudPath = await _read(db, 'cloud_backup_path');
      final cloudEnabled = await _read(db, 'cloud_backup_enabled');
      await backupSvc.createBackupWithCloudSync(
        db,
        databaseFile: dbFile,
        backupDir: dir,
        cloudFolderPath: cloudEnabled == 'true' ? cloudPath : null,
      );
      await _upsert(db, lastAutoBackupAtKey, DateTime.now().toIso8601String());
    } catch (e, st) {
      await AppLogger.record('Auto backup', error: e, stackTrace: st);
    }
  }

  Future<String?> _read(AppDatabase db, String key) async {
    final row = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _upsert(AppDatabase db, String key, String value) async {
    final existing = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.settings)..where((s) => s.key.equals(key))).write(
            SettingsCompanion(value: Value(value)),
          );
      return;
    }
    await db.into(db.settings).insert(
          SettingsCompanion.insert(
            key: key,
            value: value,
            group: const Value('backup'),
          ),
        );
  }
}
