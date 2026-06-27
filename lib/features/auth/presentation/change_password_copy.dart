import 'package:flutter/widgets.dart';

ChangePasswordDialogCopy changePasswordDialogCopyFor(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => const ChangePasswordDialogCopy(
      title: 'تغيير كلمة المرور',
      mandatoryBody:
          'يجب تغيير كلمة مرور المدير الافتراضية قبل متابعة الدخول إلى النظام.',
      optionalBody: 'أدخل كلمة المرور الحالية ثم اختر كلمة مرور جديدة.',
      currentPasswordLabel: 'كلمة المرور الحالية',
      newPasswordLabel: 'كلمة المرور الجديدة',
      confirmPasswordLabel: 'تأكيد كلمة المرور الجديدة',
      passwordMismatch: 'كلمتا المرور غير متطابقتين',
      passwordRules:
          'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل، وحرف كبير، وحرف صغير، ورقم.',
    ),
    'ku' => const ChangePasswordDialogCopy(
      title: 'گۆڕینی وشەی نهێنی',
      mandatoryBody:
          'پێویستە وشەی نهێنیی بنەڕەتیی بەڕێوەبەر بگۆڕدرێت پێش بەردەوامبوون لە چوونەژوورەوە.',
      optionalBody:
          'وشەی نهێنیی ئێستا بنووسە و پاشان وشەی نهێنییەکی نوێ هەڵبژێرە.',
      currentPasswordLabel: 'وشەی نهێنیی ئێستا',
      newPasswordLabel: 'وشەی نهێنیی نوێ',
      confirmPasswordLabel: 'دڵنیابوونەوەی وشەی نهێنیی نوێ',
      passwordMismatch: 'وشە نهێنییەکان یەکناگرنەوە',
      passwordRules:
          'وشەی نهێنی دەبێت لانیکەم 8 پیت بێت و پیتی گەورە و بچووک و ژمارەی تێدا بێت.',
    ),
    _ => const ChangePasswordDialogCopy(
      title: 'Change Password',
      mandatoryBody:
          'You must change the default administrator password before entering the system.',
      optionalBody: 'Enter your current password and choose a new one.',
      currentPasswordLabel: 'Current password',
      newPasswordLabel: 'New password',
      confirmPasswordLabel: 'Confirm new password',
      passwordMismatch: 'Passwords do not match',
      passwordRules:
          'Password must be at least 8 characters and include uppercase, lowercase, and a number.',
    ),
  };
}

class ChangePasswordDialogCopy {
  const ChangePasswordDialogCopy({
    required this.title,
    required this.mandatoryBody,
    required this.optionalBody,
    required this.currentPasswordLabel,
    required this.newPasswordLabel,
    required this.confirmPasswordLabel,
    required this.passwordMismatch,
    required this.passwordRules,
  });

  final String title;
  final String mandatoryBody;
  final String optionalBody;
  final String currentPasswordLabel;
  final String newPasswordLabel;
  final String confirmPasswordLabel;
  final String passwordMismatch;
  final String passwordRules;
}
