import 'package:flutter/material.dart';

/// Shared light-mode colors for NumberInbox. Logo gradients live in the artwork.
class NumberInboxPalette {
  const NumberInboxPalette._();

  static const emerald = Color(0xFF10B981);
  static const cyan = Color(0xFF06B6D4);
  static const navy = Color(0xFF0F172A);
  static const coolGray = Color(0xFFE5E7EB);
  static const ice = Color(0xFFF5F7EB);
  static const actionGreen = Color(0xFF047857);
  static const actionBlue = Color(0xFF0369A1);

  /// The shared light-mode gradient every primary Compose/OTP action paints,
  /// so a single token keeps the brand surfaces from drifting apart.
  static const primaryActionGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [actionGreen, actionBlue],
  );

  static const selection = Color(0xFFDDF7EC);
}
