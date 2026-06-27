import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../../core/database/database.dart';

class BranchFormPayload {
  const BranchFormPayload({
    required this.name,
    this.code,
    this.address,
    this.phone,
    required this.isDefault,
    required this.isActive,
  });

  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final bool isDefault;
  final bool isActive;
}

class BranchesService {
  const BranchesService();

  Future<List<Branche>> loadBranches(AppDatabase db) {
    return (db.select(db.branches)
          ..orderBy([
            (b) => OrderingTerm.desc(b.isDefault),
            (b) => OrderingTerm.asc(b.name),
          ]))
        .get();
  }

  Future<void> saveBranch(
    AppDatabase db, {
    Branche? branch,
    required BranchFormPayload payload,
  }) async {
    await db.transaction(() async {
      if (payload.isDefault) {
        await (db.update(db.branches)..where((b) => b.isDefault.equals(true)))
            .write(const BranchesCompanion(isDefault: Value(false)));
      }

      if (branch != null) {
        await (db.update(db.branches)..where((b) => b.id.equals(branch.id)))
            .write(
          BranchesCompanion(
            name: Value(payload.name),
            code: Value(payload.code),
            address: Value(payload.address),
            phone: Value(payload.phone),
            isDefault: Value(payload.isDefault),
            isActive: Value(payload.isActive),
          ),
        );
        return;
      }

      await db.into(db.branches).insert(
            BranchesCompanion.insert(
              name: payload.name,
              code: Value(payload.code),
              address: Value(payload.address),
              phone: Value(payload.phone),
              isDefault: Value(payload.isDefault),
              isActive: Value(payload.isActive),
            ),
          );
    });
  }

  Future<void> deleteBranch(AppDatabase db, int branchId) async {
    final branch = await (db.select(db.branches)
          ..where((b) => b.id.equals(branchId)))
        .getSingle();
    if (branch.isDefault) {
      throw const BranchesException('default-branch');
    }

    final invoiceCount = await (db.select(db.invoices)
          ..where((i) => i.branchId.equals(branchId)))
        .get();
    if (invoiceCount.isNotEmpty) {
      throw const BranchesException('has-invoices');
    }

    await (db.delete(db.branches)..where((b) => b.id.equals(branchId))).go();
  }
}

class BranchesException implements Exception {
  const BranchesException(this.code);
  final String code;
}
