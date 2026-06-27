import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class CategoryFormPayload {
  const CategoryFormPayload({
    required this.nameAr,
    this.nameEn,
    this.nameKu,
    required this.isActive,
  });

  final String nameAr;
  final String? nameEn;
  final String? nameKu;
  final bool isActive;
}

class CategoriesService {
  const CategoriesService();

  Future<List<Category>> loadCategories(AppDatabase db) {
    return db.select(db.categories).get();
  }

  Future<void> saveCategory(
    AppDatabase db, {
    required CategoryFormPayload payload,
    Category? category,
  }) async {
    if (category != null) {
      await (db.update(
        db.categories,
      )..where((entry) => entry.id.equals(category.id))).write(
        CategoriesCompanion(
          nameAr: Value(payload.nameAr),
          nameEn: Value(payload.nameEn),
          nameKu: Value(payload.nameKu),
          isActive: Value(payload.isActive),
        ),
      );
      return;
    }

    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            nameAr: payload.nameAr,
            nameEn: Value(payload.nameEn),
            nameKu: Value(payload.nameKu),
            isActive: Value(payload.isActive),
          ),
        );
  }

  Future<void> deleteCategory(AppDatabase db, int categoryId) {
    return (db.delete(
      db.categories,
    )..where((entry) => entry.id.equals(categoryId))).go();
  }
}
