import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart';

class BackupService {
  const BackupService();

  Future<List<Backup>> listBackups(AppDatabase db) {
    return (db.select(
      db.backups,
    )..orderBy([(backup) => OrderingTerm.desc(backup.createdAt)])).get();
  }

  Future<String> ensureBackupDirectory({String? rootPath}) async {
    final resolvedRootPath =
        rootPath ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (resolvedRootPath.isEmpty) {
      throw const BackupException('Home directory is unavailable');
    }

    final backupDir = Directory(p.join(resolvedRootPath, 'Mada_Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir.path;
  }

  Future<Backup> createBackup(
    AppDatabase db, {
    required File databaseFile,
    required String backupDir,
    DateTime? now,
  }) async {
    if (!await databaseFile.exists()) {
      throw const BackupException('Database file not found');
    }

    final timestamp = (now ?? DateTime.now())
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'mada_backup_$timestamp.db';
    final backupPath = p.join(backupDir, fileName);

    // Atomic backup using VACUUM INTO (Drift/SQLite)
    await db.customStatement('VACUUM INTO ?', [backupPath]);

    final copiedFile = File(backupPath);
    final size = await copiedFile.length();

    final backupId = await db.into(db.backups).insert(
      BackupsCompanion.insert(
        filePath: backupPath,
        type: 'local',
        status: 'success',
        sizeBytes: Value(size),
        notes: Value(fileName),
      ),
    );

    final backup = await (db.select(
      db.backups,
    )..where((b) => b.id.equals(backupId))).getSingle();

    return backup;
  }

  /// Copies [localBackupPath] into [cloudFolderPath] (e.g. OneDrive/Dropbox folder).
  Future<String> syncToCloudFolder({
    required String localBackupPath,
    required String cloudFolderPath,
  }) async {
    final source = File(localBackupPath);
    if (!await source.exists()) {
      throw const BackupException('Backup file not found');
    }
    final cloudDir = Directory(cloudFolderPath);
    if (!await cloudDir.exists()) {
      await cloudDir.create(recursive: true);
    }
    final targetPath = p.join(cloudFolderPath, p.basename(localBackupPath));
    await source.copy(targetPath);
    return targetPath;
  }

  Future<Backup> createBackupWithCloudSync(
    AppDatabase db, {
    required File databaseFile,
    required String backupDir,
    String? cloudFolderPath,
    DateTime? now,
  }) async {
    final backup = await createBackup(
      db,
      databaseFile: databaseFile,
      backupDir: backupDir,
      now: now,
    );

    if (cloudFolderPath == null || cloudFolderPath.trim().isEmpty) {
      return backup;
    }

    try {
      final cloudPath = await syncToCloudFolder(
        localBackupPath: backup.filePath,
        cloudFolderPath: cloudFolderPath.trim(),
      );
      await db.into(db.backups).insert(
            BackupsCompanion.insert(
              filePath: cloudPath,
              type: 'cloud',
              status: 'success',
              sizeBytes: Value(backup.sizeBytes),
              notes: Value(p.basename(cloudPath)),
            ),
          );
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Cloud sync failed: $e');
    }

    return backup;
  }

  Future<void> restoreBackup({
    required AppDatabase db,
    required Backup backup,
    required File databaseFile,
  }) async {
    if (backup.filePath.isEmpty) {
      throw const BackupException('File path is unavailable');
    }

    final backupFile = File(backup.filePath);
    if (!await backupFile.exists()) {
      throw const BackupException('Backup file is missing');
    }

    await db.close();
    if (await databaseFile.exists()) {
      await databaseFile.delete();
    }
    await backupFile.copy(databaseFile.path);
  }

  String formatFileSize(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;
}
