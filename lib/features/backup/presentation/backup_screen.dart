import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/page_header.dart';
import '../application/backup_service.dart';
import 'widgets/backup_sections.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  List<Backup> _backups = [];
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _autoBackupEnabled = true;
  bool _cloudBackupEnabled = false;
  String _cloudBackupPath = '';
  int _backupIntervalHours = 24;
  final BackupService _backupService = const BackupService();

  static const _intervalChoices = [6, 12, 24, 48, 72];

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadScheduleSettings();
  }

  Future<void> _loadBackups() async {
    final db = ref.read(databaseProvider);
    final backups = await _backupService.listBackups(db);
    setState(() => _backups = backups);
  }

  Future<void> _loadScheduleSettings() async {
    final db = ref.read(databaseProvider);
    final rows = await db.select(db.settings).get();
    final map = {for (final r in rows) r.key: r.value};
    if (!mounted) return;
    setState(() {
      _autoBackupEnabled = map['auto_backup'] != 'false';
      _cloudBackupEnabled = map['cloud_backup_enabled'] == 'true';
      _cloudBackupPath = map['cloud_backup_path'] ?? '';
      _backupIntervalHours =
          int.tryParse(map['backup_interval_hours'] ?? '') ?? 24;
    });
  }

  Future<void> _pickCloudFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    final db = ref.read(databaseProvider);
    await _upsertSetting(db, 'cloud_backup_path', path);
    setState(() => _cloudBackupPath = path);
  }

  Future<void> _setCloudBackup(bool enabled) async {
    final db = ref.read(databaseProvider);
    await _upsertSetting(db, 'cloud_backup_enabled', enabled ? 'true' : 'false');
    setState(() => _cloudBackupEnabled = enabled);
  }

  Future<void> _upsertSetting(AppDatabase db, String key, String value) async {
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

  Future<void> _setAutoBackup(bool enabled) async {
    final db = ref.read(databaseProvider);
    await _upsertSetting(db, 'auto_backup', enabled ? 'true' : 'false');
    setState(() => _autoBackupEnabled = enabled);
  }

  Future<void> _setIntervalHours(int hours) async {
    final db = ref.read(databaseProvider);
    await _upsertSetting(db, 'backup_interval_hours', '$hours');
    setState(() => _backupIntervalHours = hours);
  }

  Future<void> _createBackup() async {
    final l10n = context.l10n;
    setState(() => _isBackingUp = true);

    try {
      final db = ref.read(databaseProvider);
      final dbFile = await resolveAppDatabaseFile();
      final backupDir = await _backupService.ensureBackupDirectory();
      final backup = await _backupService.createBackupWithCloudSync(
        db,
        databaseFile: dbFile,
        backupDir: backupDir,
        cloudFolderPath: _cloudBackupEnabled ? _cloudBackupPath : null,
      );

      await _loadBackups();

      if (mounted) {
        AppFeedback.success(
          context,
          l10n.backupCreatedAt(backup.filePath),
          duration: const Duration(seconds: 4),
        );
      }
    } on BackupException catch (error) {
      if (mounted) {
        final message = error.message == 'Database file not found'
            ? l10n.databaseFileNotFound
            : error.message;
        AppFeedback.error(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.error}: $e');
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup(Backup backup) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.restoreBackup,
      message: l10n.restoreBackupMessage(p.basename(backup.filePath)),
      confirmText: l10n.restoreBackup,
    );

    if (!confirmed) return;

    setState(() => _isRestoring = true);

    try {
      final db = ref.read(databaseProvider);
      final dbFile = await resolveAppDatabaseFile();
      await _backupService.restoreBackup(
        db: db,
        backup: backup,
        databaseFile: dbFile,
      );

      if (mounted) {
        AppFeedback.success(
          context,
          l10n.backupRestoredRestart,
          duration: const Duration(seconds: 5),
        );
      }
    } on BackupException catch (error) {
      if (mounted) {
        final message = switch (error.message) {
          'File path is unavailable' => l10n.filePathUnavailable,
          'Backup file is missing' => l10n.backupFileMissing,
          _ => error.message,
        };
        AppFeedback.error(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.error}: $e');
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          PageHeader(
            title: l10n.backup,
            subtitle: '${_backups.length} ${l10n.items}',
            actions: [
              ElevatedButton.icon(
                onPressed: _isBackingUp ? null : _createBackup,
                icon: _isBackingUp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.backup_rounded, size: 18),
                label: Text(
                  _isBackingUp ? l10n.creatingBackup : l10n.createBackup,
                ),
              ),
            ],
          ),
          BackupInfoCard(message: l10n.backupInfoMessage, isDark: isDark),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.autoBackupEnabled),
                      value: _autoBackupEnabled,
                      onChanged: (v) => _setAutoBackup(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.cloudBackupEnabled),
                      subtitle: _cloudBackupPath.isEmpty
                          ? Text(l10n.cloudBackupPathHint)
                          : Text(
                              _cloudBackupPath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      value: _cloudBackupEnabled,
                      onChanged: (v) => _setCloudBackup(v),
                    ),
                    if (_cloudBackupEnabled)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: _pickCloudFolder,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(l10n.chooseCloudFolder),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.backupIntervalHours),
                      trailing: DropdownButton<int>(
                        value: _intervalChoices.contains(_backupIntervalHours)
                            ? _backupIntervalHours
                            : 24,
                        items: [
                          for (final h in _intervalChoices)
                            DropdownMenuItem(value: h, child: Text('$h')),
                        ],
                        onChanged: _autoBackupEnabled
                            ? (v) {
                                if (v != null) _setIntervalHours(v);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _backups.isEmpty
                ? BackupsEmptyState(
                    title: l10n.noBackups,
                    subtitle: l10n.createFirstBackupNow,
                    isDark: isDark,
                  )
                : BackupsListSection(
                    backups: _backups,
                    isDark: isDark,
                    isRestoring: _isRestoring,
                    restoreLabel: l10n.restoreBackup,
                    formatFileSize: _backupService.formatFileSize,
                    onRestore: _restoreBackup,
                  ),
          ),
        ],
      ),
    );
  }
}
