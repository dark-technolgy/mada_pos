import 'package:flutter/widgets.dart';

UsersManagementCopy usersManagementCopyFor(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => const UsersManagementCopy(
      title: 'إدارة المستخدمين',
      addUser: 'إضافة مستخدم',
      usersCountLabel: 'مستخدم',
      emptyTitle: 'لا يوجد مستخدمون إضافيون',
      emptySubtitle: 'يمكنك إنشاء مستخدمين جدد وتحديد أدوارهم وصلاحياتهم.',
      unauthorizedTitle: 'غير مصرح',
      unauthorizedSubtitle: 'هذه الشاشة متاحة للمشرف فقط.',
      active: 'نشط',
      inactive: 'معطل',
      edit: 'تعديل',
      resetPassword: 'إعادة ضبط كلمة المرور',
      deactivate: 'تعطيل',
      activate: 'تفعيل',
      currentSession: 'الجلسة الحالية',
      fullName: 'الاسم الكامل',
      username: 'اسم المستخدم',
      role: 'الدور',
      initialPassword: 'كلمة المرور الأولية',
      newPassword: 'كلمة المرور الجديدة',
      passwordRequired: 'أدخل كلمة المرور',
      usernameRequired: 'أدخل اسم المستخدم',
      fullNameRequired: 'أدخل الاسم الكامل',
      save: 'حفظ',
      cancel: 'إلغاء',
      savedMessage: 'تم حفظ التغييرات بنجاح',
      passwordResetMessage: 'تمت إعادة ضبط كلمة المرور',
      setUserPin: 'تعيين PIN',
      clearUserPin: 'إزالة PIN',
      enterPin: 'أدخل PIN',
      pinInvalidFormat: 'يجب أن يكون PIN من 4 إلى 6 أرقام',
      pinSetSuccess: 'تم حفظ PIN',
      pinClearedSuccess: 'تم إزالة PIN',
    ),
    'ku' => const UsersManagementCopy(
      title: 'بەڕێوەبردنی بەکارهێنەران',
      addUser: 'زیادکردنی بەکارهێنەر',
      usersCountLabel: 'بەکارهێنەر',
      emptyTitle: 'هیچ بەکارهێنەری زیادە نییە',
      emptySubtitle:
          'دەتوانیت بەکارهێنەری نوێ دروست بکەیت و ڕۆڵەکانیان دیاری بکەیت.',
      unauthorizedTitle: 'دەسەڵاتت نییە',
      unauthorizedSubtitle: 'ئەم پەڕەیە تەنها بۆ بەڕێوەبەرە.',
      active: 'چالاک',
      inactive: 'ناچالاک',
      edit: 'دەستکاریکردن',
      resetPassword: 'ڕێکخستنەوەی وشەی نهێنی',
      deactivate: 'ناچالاککردن',
      activate: 'چالاککردن',
      currentSession: 'دانیشتنی ئێستا',
      fullName: 'ناوی تەواو',
      username: 'ناوی بەکارهێنەر',
      role: 'ڕۆڵ',
      initialPassword: 'وشەی نهێنیی سەرەتایی',
      newPassword: 'وشەی نهێنیی نوێ',
      passwordRequired: 'وشەی نهێنی بنووسە',
      usernameRequired: 'ناوی بەکارهێنەر بنووسە',
      fullNameRequired: 'ناوی تەواو بنووسە',
      save: 'پاشەکەوتکردن',
      cancel: 'هەڵوەشاندنەوە',
      savedMessage: 'گۆڕانکارییەکان بە سەرکەوتوویی پاشەکەوت کران',
      passwordResetMessage: 'وشەی نهێنی نوێکرایەوە',
      setUserPin: 'دانانی PIN',
      clearUserPin: 'لابردنی PIN',
      enterPin: 'PIN بنووسە',
      pinInvalidFormat: 'PIN دەبێت 4–6 ژمارە بێت',
      pinSetSuccess: 'PIN پاشەکەوت کرا',
      pinClearedSuccess: 'PIN لابرا',
    ),
    _ => const UsersManagementCopy(
      title: 'User Management',
      addUser: 'Add User',
      usersCountLabel: 'users',
      emptyTitle: 'No additional users yet',
      emptySubtitle: 'Create new users and assign roles and permissions.',
      unauthorizedTitle: 'Unauthorized',
      unauthorizedSubtitle: 'This screen is available to administrators only.',
      active: 'Active',
      inactive: 'Inactive',
      edit: 'Edit',
      resetPassword: 'Reset Password',
      deactivate: 'Deactivate',
      activate: 'Activate',
      currentSession: 'Current session',
      fullName: 'Full name',
      username: 'Username',
      role: 'Role',
      initialPassword: 'Initial password',
      newPassword: 'New password',
      passwordRequired: 'Enter password',
      usernameRequired: 'Enter username',
      fullNameRequired: 'Enter full name',
      save: 'Save',
      cancel: 'Cancel',
      savedMessage: 'Changes saved successfully',
      passwordResetMessage: 'Password reset successfully',
      setUserPin: 'Set PIN',
      clearUserPin: 'Remove PIN',
      enterPin: 'Enter PIN',
      pinInvalidFormat: 'PIN must be 4–6 digits',
      pinSetSuccess: 'PIN saved',
      pinClearedSuccess: 'PIN removed',
    ),
  };
}

class UsersManagementCopy {
  const UsersManagementCopy({
    required this.title,
    required this.addUser,
    required this.usersCountLabel,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.unauthorizedTitle,
    required this.unauthorizedSubtitle,
    required this.active,
    required this.inactive,
    required this.edit,
    required this.resetPassword,
    required this.deactivate,
    required this.activate,
    required this.currentSession,
    required this.fullName,
    required this.username,
    required this.role,
    required this.initialPassword,
    required this.newPassword,
    required this.passwordRequired,
    required this.usernameRequired,
    required this.fullNameRequired,
    required this.save,
    required this.cancel,
    required this.savedMessage,
    required this.passwordResetMessage,
    required this.setUserPin,
    required this.clearUserPin,
    required this.enterPin,
    required this.pinInvalidFormat,
    required this.pinSetSuccess,
    required this.pinClearedSuccess,
  });

  final String title;
  final String addUser;
  final String usersCountLabel;
  final String emptyTitle;
  final String emptySubtitle;
  final String unauthorizedTitle;
  final String unauthorizedSubtitle;
  final String active;
  final String inactive;
  final String edit;
  final String resetPassword;
  final String deactivate;
  final String activate;
  final String currentSession;
  final String fullName;
  final String username;
  final String role;
  final String initialPassword;
  final String newPassword;
  final String passwordRequired;
  final String usernameRequired;
  final String fullNameRequired;
  final String save;
  final String cancel;
  final String savedMessage;
  final String passwordResetMessage;
  final String setUserPin;
  final String clearUserPin;
  final String enterPin;
  final String pinInvalidFormat;
  final String pinSetSuccess;
  final String pinClearedSuccess;

  String roleLabel(String roleValue) => switch (roleValue) {
    'admin' => 'Admin',
    'manager' => 'Manager',
    'viewer' => 'Viewer',
    _ => 'Cashier',
  };

  String resetPasswordFor(String fullName) => switch (title) {
    'إدارة المستخدمين' => 'إعادة ضبط كلمة المرور: $fullName',
    'بەڕێوەبردنی بەکارهێنەران' => 'ڕێکخستنەوەی وشەی نهێنی: $fullName',
    _ => 'Reset Password: $fullName',
  };
}
