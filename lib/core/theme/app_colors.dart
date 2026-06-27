import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors (Sky + Midnight)
  static const Color primary = Color(0xFF38BDF8);
  static const Color primaryLight = Color(0xFF7DD3FC);
  static const Color primaryDark = Color(0xFF0EA5E9);

  // Accent Colors
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentLight = Color(0xFF67E8F9);
  static const Color accentDark = Color(0xFF06B6D4);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0B1220);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkSidebar = Color(0xFF030712);

  // Light Theme Colors
  static const Color lightBg = Color(0xFFF7FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightSidebar = Color(0xFFF8FAFC);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft elevation used across list screens, tables, and filter toolbars.
  static List<BoxShadow> cardShadow(bool isDark) => [
    BoxShadow(
      color: (isDark ? Colors.black : lightTextMuted).withValues(
        alpha: isDark ? 0.22 : 0.1,
      ),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
}
