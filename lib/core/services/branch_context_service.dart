import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../database/database.dart';

/// Persists the branch used for new sales and filtered views.
class BranchContextService {
  const BranchContextService();

  static const activeBranchKey = 'active_branch_id';

  Future<List<Branche>> loadActiveBranches(AppDatabase db) {
    return (db.select(db.branches)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([
            (b) => OrderingTerm.desc(b.isDefault),
            (b) => OrderingTerm.asc(b.name),
          ]))
        .get();
  }

  Future<int?> readActiveBranchId(AppDatabase db) async {
    final row = await (db.select(db.settings)
          ..where((s) => s.key.equals(activeBranchKey)))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '');
  }

  Future<Branche?> readActiveBranch(AppDatabase db) async {
    final id = await readActiveBranchId(db);
    if (id == null) return null;
    return (db.select(db.branches)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> setActiveBranchId(AppDatabase db, int branchId) async {
    final existing = await (db.select(db.settings)
          ..where((s) => s.key.equals(activeBranchKey)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.settings)
            ..where((s) => s.key.equals(activeBranchKey)))
          .write(SettingsCompanion(value: Value('$branchId')));
      return;
    }
    await db.into(db.settings).insert(
          SettingsCompanion.insert(
            key: activeBranchKey,
            value: '$branchId',
            group: const Value('general'),
          ),
        );
  }

  Future<int> ensureDefaultBranch(AppDatabase db) async {
    final defaultBranch = await (db.select(db.branches)
          ..where((b) => b.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (defaultBranch != null) {
      final active = await readActiveBranchId(db);
      if (active == null) {
        await setActiveBranchId(db, defaultBranch.id);
      }
      return defaultBranch.id;
    }

    final id = await db.into(db.branches).insert(
          BranchesCompanion.insert(
            name: 'الفرع الرئيسي',
            code: const Value('MAIN'),
            isDefault: const Value(true),
          ),
        );
    await setActiveBranchId(db, id);
    return id;
  }
}
