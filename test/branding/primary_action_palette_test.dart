import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary actions match the selected logo-colour preview', () {
    expect(NumberInboxPalette.primaryActionGradient.colors, const [
      Color(0xFF05D792),
      Color(0xFF03CDFC),
      Color(0xFF018AFC),
    ]);
  });

  test('primary labels icons and spinners share the selected white foreground', () {
    expect(NumberInboxPalette.primaryActionForeground, Colors.white);
  });
}
