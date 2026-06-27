import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../application/categories_service.dart';
import 'widgets/categories_sections.dart';
import 'widgets/category_dialogs.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<Category> _categories = [];
  final CategoriesService _categoriesService = const CategoriesService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = ref.read(databaseProvider);
    final categories = await _categoriesService.loadCategories(db);
    setState(() => _categories = categories);
  }

  Future<void> _showCategoryDialog([Category? category]) async {
    final l10n = context.l10n;
    final result = await showCategoryDialog(
      context: context,
      title: category != null ? l10n.editCategory : l10n.addNewCategory,
      nameArLabel: l10n.categoryNameArabic,
      nameEnLabel: l10n.categoryNameEnglish,
      nameKuLabel: l10n.categoryNameKurdish,
      activeLabel: l10n.active,
      requiredFieldLabel: l10n.requiredField,
      cancelLabel: l10n.cancel,
      saveLabel: category != null ? l10n.save : l10n.add,
      initialNameAr: category?.nameAr,
      initialNameEn: category?.nameEn,
      initialNameKu: category?.nameKu,
      initialIsActive: category?.isActive ?? true,
    );

    if (result != null) {
      final db = ref.read(databaseProvider);
      try {
        await _categoriesService.saveCategory(
          db,
          category: category,
          payload: CategoryFormPayload(
            nameAr: result.nameAr,
            nameEn: result.nameEn,
            nameKu: result.nameKu,
            isActive: result.isActive,
          ),
        );
        await _loadCategories();
        if (mounted) {
          AppFeedback.success(
            context,
            category != null
                ? l10n.categoryUpdatedSuccessfully
                : l10n.categoryAddedSuccessfully,
          );
        }
      } catch (e) {
        if (mounted) {
          AppFeedback.error(context, '${l10n.errorOccurred}: $e');
        }
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.deleteCategoryTitle,
      message: l10n.deleteCategoryMessage(category.nameAr),
      confirmText: l10n.delete,
    );

    if (confirmed) {
      final db = ref.read(databaseProvider);
      await _categoriesService.deleteCategory(db, category.id);
      await _loadCategories();
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
            title: l10n.categories,
            subtitle: '${_categories.length} ${l10n.items}',
            actions: [
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.add),
              ),
            ],
          ),
          Expanded(
            child: CategoriesGridSection(
              categories: _categories,
              isDark: isDark,
              noCategoriesLabel: l10n.noCategories,
              emptySubtitle: l10n.startByAddingCategories,
              activeLabel: l10n.active,
              inactiveLabel: l10n.inactive,
              editTooltip: l10n.edit,
              deleteTooltip: l10n.delete,
              onEditCategory: _showCategoryDialog,
              onDeleteCategory: _deleteCategory,
            ),
          ),
        ],
      ),
    );
  }
}
