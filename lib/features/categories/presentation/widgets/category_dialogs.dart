import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CategoryDialogResult {
  const CategoryDialogResult({
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

Future<CategoryDialogResult?> showCategoryDialog({
  required BuildContext context,
  required String title,
  required String nameArLabel,
  required String nameEnLabel,
  required String nameKuLabel,
  required String activeLabel,
  required String requiredFieldLabel,
  required String cancelLabel,
  required String saveLabel,
  String? initialNameAr,
  String? initialNameEn,
  String? initialNameKu,
  bool initialIsActive = true,
}) {
  final nameArCtrl = TextEditingController(text: initialNameAr ?? '');
  final nameEnCtrl = TextEditingController(text: initialNameEn ?? '');
  final nameKuCtrl = TextEditingController(text: initialNameKu ?? '');
  final formKey = GlobalKey<FormState>();
  var isActive = initialIsActive;

  return showDialog<CategoryDialogResult>(
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
                      title,
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
                      decoration: InputDecoration(labelText: nameArLabel),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? requiredFieldLabel
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nameEnCtrl,
                            decoration: InputDecoration(labelText: nameEnLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: nameKuCtrl,
                            decoration: InputDecoration(labelText: nameKuLabel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(activeLabel),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(cancelLabel),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;

                            Navigator.pop(
                              context,
                              CategoryDialogResult(
                                nameAr: nameArCtrl.text.trim(),
                                nameEn: nameEnCtrl.text.trim().isEmpty
                                    ? null
                                    : nameEnCtrl.text.trim(),
                                nameKu: nameKuCtrl.text.trim().isEmpty
                                    ? null
                                    : nameKuCtrl.text.trim(),
                                isActive: isActive,
                              ),
                            );
                          },
                          child: Text(saveLabel),
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
  ).whenComplete(() {
    nameArCtrl.dispose();
    nameEnCtrl.dispose();
    nameKuCtrl.dispose();
  });
}
