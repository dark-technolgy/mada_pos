import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/backup/application/backup_service.dart';

void main() {
  const service = BackupService();

  test(
    'BackupService creates backup directory and copies database file',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final tempRoot = await Directory.systemTemp.createTemp(
        'Mada_backup_test',
      );
      addTearDown(() async => tempRoot.delete(recursive: true));

      final sourceDb = File('${tempRoot.path}/app.db');
      await sourceDb.writeAsString('backup-content');

      final backupDir = await service.ensureBackupDirectory(
        rootPath: tempRoot.path,
      );
      final backup = await service.createBackup(
        database,
        databaseFile: sourceDb,
        backupDir: backupDir,
        now: DateTime(2026, 3, 9, 12, 30),
      );

      final copiedFile = File(backup.filePath);
      expect(await copiedFile.exists(), isTrue);
      expect(await copiedFile.readAsString(), 'backup-content');
      expect(backup.type, 'local');
      expect(backup.status, 'success');
      expect(backup.notes, 'Mada_backup_2026-03-09T12-30-00.db');
    },
  );

  test('BackupService lists backups newest first and formats sizes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.backups)
        .insert(
          BackupsCompanion.insert(
            filePath: '/tmp/older.db',
            type: 'local',
            status: 'success',
            sizeBytes: const Value(512),
            createdAt: Value(DateTime(2026, 3, 8, 10)),
          ),
        );
    await database
        .into(database.backups)
        .insert(
          BackupsCompanion.insert(
            filePath: '/tmp/newer.db',
            type: 'local',
            status: 'success',
            sizeBytes: const Value(2048),
            createdAt: Value(DateTime(2026, 3, 9, 10)),
          ),
        );

    final backups = await service.listBackups(database);

    expect(backups.first.filePath, '/tmp/newer.db');
    expect(backups.last.filePath, '/tmp/older.db');
    expect(service.formatFileSize(512), '512 B');
    expect(service.formatFileSize(2048), '2.0 KB');
    expect(service.formatFileSize(2 * 1024 * 1024), '2.0 MB');
  });
}
