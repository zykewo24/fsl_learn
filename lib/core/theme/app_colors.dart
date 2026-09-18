import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color secondary = Color(0xFF3B82F6);

  static const Color background = Color(0xFFF8FAFC);

  static const Color white = Colors.white;

  static const Color text = Color(0xFF111827);

  static const Color subtitle = Color(0xFF6B7280);

  // Aliases for compatibility with app_text_styles.dart
  static const Color textPrimary = text;

  static const Color textSecondary = subtitle;

  static const Color border = Color(0xFFE5E7EB);

  // Used for text fields and light backgrounds
  static const Color field = Color(0xFFF3F4F6);

  // Alias for compatibility with app_theme.dart
  static const Color lightGrey = field;

  static const Color info = Color(0xFFEFF6FF);

  /// Live practice feedback: correct hand placement.
  static const Color success = Color(0xFF16A34A);

  /// Live practice feedback: wrong hand placement.
  static const Color danger = Color(0xFFDC2626);

  static const Color shadow = Color(0x11000000);
}