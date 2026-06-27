import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Consistent snackbars across the app.
class AppFeedback {
  AppFeedback._();

  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.success,
      duration: duration,
    );
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, backgroundColor: AppColors.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, backgroundColor: AppColors.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message);
  }
}
