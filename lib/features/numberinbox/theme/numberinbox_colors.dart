import 'package:flutter/material.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';

/// NumberInbox brand colors (docs/16-branding.md).
class NumberInboxColors {
  NumberInboxColors._();

  static const primary = NumberInboxPalette.actionGreen;
  static const accent = NumberInboxPalette.cyan;
  static const background = NumberInboxPalette.ice;
  static const danger = Color(0xFFC0392B);
  static const white = Colors.white;
  static const textPrimary = NumberInboxPalette.navy;
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
