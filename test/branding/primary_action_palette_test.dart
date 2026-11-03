import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastWithWhite(Color color) =>
    1.05 / (color.computeLuminance() + 0.05);

void main() {
  test('primary actions use the selected green, teal and blue stops', () {
    expect(NumberInboxPalette.primaryActionGradient.colors, const [
      Color(0xFF0D7C66),
      Color(0xFF0B7A94),
      Color(0xFF0A6FB5),
    ]);
  });

  test('primary labels icons and spinners share the white foreground', () {
    expect(NumberInboxPalette.primaryActionForeground, Colors.white);
  });

  test('the white foreground reaches 4.5:1 on every gradient stop', () {
    for (final stop in NumberInboxPalette.primaryActionGradient.colors) {
      expect(
        _contrastWithWhite(stop),
        greaterThanOrEqualTo(4.5),
        reason: 'white on $stop',
      );
    }
  });
}
