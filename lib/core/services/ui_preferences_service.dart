import 'package:drift/drift.dart' show Value;

import '../database/database.dart';

/// Persists UI state (filters, layout) in the settings table.
class UiPreferencesService {
  const UiPreferencesService();

  Future<String?> read(AppDatabase db, String key) async {
    final row = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(AppDatabase db, String key, String value) async {
    final updated = await (db.update(db.settings)
          ..where((s) => s.key.equals(key)))
        .write(SettingsCompanion(value: Value(value), group: const Value('ui')));

    if (updated == 0) {
      try {
        await db.into(db.settings).insert(
              SettingsCompanion.insert(
                key: key,
                value: value,
                group: const Value('ui'),
              ),
            );
      } on Exception {
        await (db.update(db.settings)..where((s) => s.key.equals(key))).write(
          SettingsCompanion(value: Value(value), group: const Value('ui')),
        );
      }
    }
  }
}
