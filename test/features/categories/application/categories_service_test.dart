import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/categories/application/categories_service.dart';

void main() {
  const service = CategoriesService();

  test('CategoriesService creates and loads categories', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await service.saveCategory(
      database,
      payload: const CategoryFormPayload(
        nameAr: 'إلكترونيات',
        nameEn: 'Electronics',
        nameKu: 'ئەلیکترۆنیات',
        isActive: true,
      ),
    );

    final categories = await service.loadCategories(database);

    expect(categories, hasLength(1));
    expect(categories.single.nameAr, 'إلكترونيات');
    expect(categories.single.nameEn, 'Electronics');
    expect(categories.single.isActive, isTrue);
  });

  test('CategoriesService updates existing category', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final categoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'قديم'));
    final category = await (database.select(
      database.categories,
    )..where((entry) => entry.id.equals(categoryId))).getSingle();

    await service.saveCategory(
      database,
      category: category,
      payload: const CategoryFormPayload(
        nameAr: 'جديد',
        nameEn: 'New',
        isActive: false,
      ),
    );

    final updated = await (database.select(
      database.categories,
    )..where((entry) => entry.id.equals(categoryId))).getSingle();

    expect(updated.nameAr, 'جديد');
    expect(updated.nameEn, 'New');
    expect(updated.isActive, isFalse);
  });

  test('CategoriesService deletes category', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final categoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(nameAr: 'Delete me'));

    await service.deleteCategory(database, categoryId);

    final categories = await database.select(database.categories).get();
    expect(categories, isEmpty);
  });
}
