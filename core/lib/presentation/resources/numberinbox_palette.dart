import 'package:flutter/material.dart';

/// Shared light-mode colors for NumberInbox. Logo gradients live in the artwork.
class NumberInboxPalette {
  const NumberInboxPalette._();

  static const emerald = Color(0xFF10B981);
  static const cyan = Color(0xFF06B6D4);
  static const navy = Color(0xFF0F172A);
  static const coolGray = Color(0xFFE5E7EB);
  static const ice = Color(0xFFF5F7EB);
  static const interactiveAccent = Color(0xFF0B7A94);
  static const actionGreen = interactiveAccent;
  static const actionBlue = Color(0xFF0369A1);
  // Representative colours sampled from the detailed mark. They are brand
  // reference values only: white text on them is 1.9:1 to 3.5:1, so controls
  // that carry a label use the darker action stops below (ADR 0121).
  static const logoGreen = Color(0xFF05D792);
  static const logoCyan = Color(0xFF03CDFC);
  static const logoBlue = Color(0xFF018AFC);
  // Same green, teal and blue family as the logo, dark enough for the white
  // label to reach at least 4.5:1 on every stop.
  static const primaryActionStart = Color(0xFF0D7C66);
  static const primaryActionMiddle = Color(0xFF0B7A94);
  static const primaryActionEnd = Color(0xFF0A6FB5);
  static const primaryActionForeground = Colors.white;

  /// The shared light-mode gradient every primary Compose/OTP action paints,
  /// so a single token keeps the brand surfaces from drifting apart.
  static const primaryActionGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [primaryActionStart, primaryActionMiddle, primaryActionEnd],
  );

  static const selection = Color(0xFFDDF7EC);
}
