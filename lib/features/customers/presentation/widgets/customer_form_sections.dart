import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CustomerFormHeader extends StatelessWidget {
  const CustomerFormHeader({
    super.key,
    required this.isDark,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.savingLabel,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
    this.extraActions,
  });

  final bool isDark;
  final String title;
  final String cancelLabel;
  final String saveLabel;
  final String savingLabel;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final List<Widget>? extraActions;

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
          if (extraActions != null) ...[
            ...extraActions!,
            const SizedBox(width: 8),
          ],
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

class CustomerFormContent extends StatelessWidget {
  const CustomerFormContent({
    super.key,
    required this.formKey,
    required this.isDark,
    required this.sectionTitle,
    required this.nameLabel,
    required this.phoneLabel,
    required this.emailLabel,
    required this.addressLabel,
    required this.notesLabel,
    required this.activeLabel,
    required this.requiredLabel,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.notesController,
    required this.isActive,
    required this.onActiveChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool isDark;
  final String sectionTitle;
  final String nameLabel;
  final String phoneLabel;
  final String emailLabel;
  final String addressLabel;
  final String notesLabel;
  final String activeLabel;
  final String requiredLabel;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController notesController;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: 600,
        child: Form(
          key: formKey,
          child: Column(
            children: [
              CustomerFormSectionCard(
                title: sectionTitle,
                isDark: isDark,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: nameLabel),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? requiredLabel
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          decoration: InputDecoration(labelText: phoneLabel),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: emailController,
                          decoration: InputDecoration(labelText: emailLabel),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(labelText: addressLabel),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(labelText: notesLabel),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(activeLabel),
                    value: isActive,
                    onChanged: onActiveChanged,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerFormSectionCard extends StatelessWidget {
  const CustomerFormSectionCard({
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
