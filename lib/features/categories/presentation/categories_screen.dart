import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = ref.read(databaseProvider);
    final categories = await db.select(db.categories).get();
    setState(() => _categories = categories);
  }

  Future<void> _showCategoryDialog([Category? category]) async {
    final l10n = context.l10n;
    final nameArCtrl = TextEditingController(text: category?.nameAr ?? '');
    final nameEnCtrl = TextEditingController(text: category?.nameEn ?? '');
    final nameKuCtrl = TextEditingController(text: category?.nameKu ?? '');
    bool isActive = category?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category != null
                            ? l10n.editCategory
                            : l10n.addNewCategory,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameArCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.categoryNameArabic,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.requiredField
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: nameEnCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.categoryNameEnglish,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: nameKuCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.categoryNameKurdish,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(l10n.active),
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(context, true);
                              }
                            },
                            child: Text(
                              category != null ? l10n.save : l10n.add,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final db = ref.read(databaseProvider);
      try {
        if (category != null) {
          await (db.update(
            db.categories,
          )..where((c) => c.id.equals(category.id))).write(
            CategoriesCompanion(
              nameAr: Value(nameArCtrl.text.trim()),
              nameEn: Value(
                nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
              ),
              nameKu: Value(
                nameKuCtrl.text.trim().isEmpty ? null : nameKuCtrl.text.trim(),
              ),
              isActive: Value(isActive),
            ),
          );
        } else {
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  nameAr: nameArCtrl.text.trim(),
                  nameEn: Value(
                    nameEnCtrl.text.trim().isEmpty
                        ? null
                        : nameEnCtrl.text.trim(),
                  ),
                  nameKu: Value(
                    nameKuCtrl.text.trim().isEmpty
                        ? null
                        : nameKuCtrl.text.trim(),
                  ),
                  isActive: Value(isActive),
                ),
              );
        }
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                category != null
                    ? l10n.categoryUpdatedSuccessfully
                    : l10n.categoryAddedSuccessfully,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.errorOccurred}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    nameArCtrl.dispose();
    nameEnCtrl.dispose();
    nameKuCtrl.dispose();
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
      await (db.delete(
        db.categories,
      )..where((c) => c.id.equals(category.id))).go();
      _loadCategories();
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
            child: _categories.isEmpty
                ? EmptyState(
                    icon: Icons.category_outlined,
                    title: l10n.noCategories,
                    subtitle: l10n.startByAddingCategories,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.category_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cat.nameAr,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (cat.isActive
                                                  ? AppColors.success
                                                  : AppColors.error)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cat.isActive
                                          ? l10n.active
                                          : l10n.inactive,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: cat.isActive
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => _showCategoryDialog(cat),
                                    color: AppColors.primary,
                                    tooltip: 'تعديل',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    onPressed: () => _deleteCategory(cat),
                                    color: AppColors.error,
                                    tooltip: 'حذف',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
