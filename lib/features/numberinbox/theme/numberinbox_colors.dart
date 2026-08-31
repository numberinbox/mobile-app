import 'package:flutter/material.dart';

/// NumberInbox brand colors (docs/16-branding.md).
class NumberInboxColors {
  NumberInboxColors._();

  static const primary = Color(0xFF2196F3);
  static const accent = Color(0xFF3DDC97);
  static const background = Color(0xFFF7F4EE);
  static const danger = Color(0xFFC0392B);
  static const white = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);

  /// Returns a [ThemeData] using NumberInbox brand colors.
  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: background,
        error: danger,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary),
        ),
      ),
    );
  }
}
