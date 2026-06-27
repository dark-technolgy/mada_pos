import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_colors.dart';

class ProductFormHeader extends StatelessWidget {
  const ProductFormHeader({
    super.key,
    required this.isDark,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.savingLabel,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final bool isDark;
  final String title;
  final String cancelLabel;
  final String saveLabel;
  final String savingLabel;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(isSaving ? savingLabel : saveLabel),
          ),
        ],
      ),
    );
  }
}

class ProductFormContent extends StatelessWidget {
  const ProductFormContent({
    super.key,
    required this.formKey,
    required this.isDark,
    required this.basicTitle,
    required this.categoryUnitTitle,
    required this.pricingTitle,
    required this.barcodeTitle,
    required this.stockTitle,
    required this.nameArLabel,
    required this.nameEnLabel,
    required this.nameKuLabel,
    required this.notesLabel,
    required this.categoryLabel,
    required this.withoutCategoryLabel,
    required this.unitLabel,
    required this.withoutUnitLabel,
    required this.purchasePriceLabel,
    required this.sellingPriceLabel,
    required this.wholesalePriceLabel,
    required this.minSellingPriceLabel,
    required this.barcodeLabel,
    required this.skuLabel,
    required this.initialQuantityLabel,
    required this.minimumLimitLabel,
    required this.maximumLimitLabel,
    required this.productIsActiveLabel,
    required this.fieldRequiredLabel,
    required this.nameArCtrl,
    required this.nameEnCtrl,
    required this.nameKuCtrl,
    required this.descriptionCtrl,
    required this.purchasePriceCtrl,
    required this.sellingPriceCtrl,
    required this.wholesalePriceCtrl,
    required this.minPriceCtrl,
    required this.barcodeCtrl,
    required this.skuCtrl,
    required this.initialStockCtrl,
    required this.minStockCtrl,
    required this.maxStockCtrl,
    required this.categories,
    required this.units,
    required this.selectedCategoryId,
    required this.selectedUnitId,
    required this.isActive,
    required this.isEditing,
    required this.onCategoryChanged,
    required this.onUnitChanged,
    required this.onActiveChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool isDark;
  final String basicTitle;
  final String categoryUnitTitle;
  final String pricingTitle;
  final String barcodeTitle;
  final String stockTitle;
  final String nameArLabel;
  final String nameEnLabel;
  final String nameKuLabel;
  final String notesLabel;
  final String categoryLabel;
  final String withoutCategoryLabel;
  final String unitLabel;
  final String withoutUnitLabel;
  final String purchasePriceLabel;
  final String sellingPriceLabel;
  final String wholesalePriceLabel;
  final String minSellingPriceLabel;
  final String barcodeLabel;
  final String skuLabel;
  final String initialQuantityLabel;
  final String minimumLimitLabel;
  final String maximumLimitLabel;
  final String productIsActiveLabel;
  final String fieldRequiredLabel;
  final TextEditingController nameArCtrl;
  final TextEditingController nameEnCtrl;
  final TextEditingController nameKuCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController purchasePriceCtrl;
  final TextEditingController sellingPriceCtrl;
  final TextEditingController wholesalePriceCtrl;
  final TextEditingController minPriceCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController initialStockCtrl;
  final TextEditingController minStockCtrl;
  final TextEditingController maxStockCtrl;
  final List<Category> categories;
  final List<Unit> units;
  final int? selectedCategoryId;
  final int? selectedUnitId;
  final bool isActive;
  final bool isEditing;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onUnitChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductSectionCard(
                    title: basicTitle,
                    isDark: isDark,
                    children: [
                      ProductFormField(
                        label: nameArLabel,
                        controller: nameArCtrl,
                        required: true,
                        requiredMessage: fieldRequiredLabel,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ProductFormField(
                              label: nameEnLabel,
                              controller: nameEnCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: nameKuLabel,
                              controller: nameKuCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProductFormField(
                        label: notesLabel,
                        controller: descriptionCtrl,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ProductSectionCard(
                    title: categoryUnitTitle,
                    isDark: isDark,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: selectedCategoryId,
                              decoration: InputDecoration(
                                labelText: categoryLabel,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(withoutCategoryLabel),
                                ),
                                ...categories.map(
                                  (category) => DropdownMenuItem(
                                    value: category.id,
                                    child: Text(category.nameAr),
                                  ),
                                ),
                              ],
                              onChanged: onCategoryChanged,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: selectedUnitId,
                              decoration: InputDecoration(labelText: unitLabel),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(withoutUnitLabel),
                                ),
                                ...units.map(
                                  (unit) => DropdownMenuItem(
                                    value: unit.id,
                                    child: Text(unit.nameAr),
                                  ),
                                ),
                              ],
                              onChanged: onUnitChanged,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductSectionCard(
                    title: pricingTitle,
                    isDark: isDark,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ProductFormField(
                              label: purchasePriceLabel,
                              controller: purchasePriceCtrl,
                              keyboardType: TextInputType.number,
                              required: true,
                              requiredMessage: fieldRequiredLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: sellingPriceLabel,
                              controller: sellingPriceCtrl,
                              keyboardType: TextInputType.number,
                              required: true,
                              requiredMessage: fieldRequiredLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ProductFormField(
                              label: wholesalePriceLabel,
                              controller: wholesalePriceCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: minSellingPriceLabel,
                              controller: minPriceCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ProductSectionCard(
                    title: barcodeTitle,
                    isDark: isDark,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ProductFormField(
                              label: barcodeLabel,
                              controller: barcodeCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: skuLabel,
                              controller: skuCtrl,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ProductSectionCard(
                    title: stockTitle,
                    isDark: isDark,
                    children: [
                      Row(
                        children: [
                          if (!isEditing)
                            Expanded(
                              child: ProductFormField(
                                label: initialQuantityLabel,
                                controller: initialStockCtrl,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          if (!isEditing) const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: minimumLimitLabel,
                              controller: minStockCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ProductFormField(
                              label: maximumLimitLabel,
                              controller: maxStockCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(productIsActiveLabel),
                        value: isActive,
                        onChanged: onActiveChanged,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductSectionCard extends StatelessWidget {
  const ProductSectionCard({
    super.key,
    required this.title,
    required this.isDark,
    required this.children,
  });

  final String title;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class ProductFormField extends StatelessWidget {
  const ProductFormField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.requiredMessage,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? requiredMessage;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return requiredMessage ?? '';
              }
              return null;
            }
          : null,
    );
  }
}
