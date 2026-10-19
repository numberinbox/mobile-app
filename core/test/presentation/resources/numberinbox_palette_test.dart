import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumberInboxPalette::primaryActionGradient', () {
    test(
      'WHEN painted on a light-mode primary action\n'
      'THEN it runs left-to-right from actionGreen to actionBlue',
      () {
        const gradient = NumberInboxPalette.primaryActionGradient;

        expect(gradient, isA<LinearGradient>());
        expect(gradient.begin, AlignmentDirectional.centerStart);
        expect(gradient.end, AlignmentDirectional.centerEnd);
        expect(
          gradient.colors,
          [NumberInboxPalette.actionGreen, NumberInboxPalette.actionBlue],
        );
      },
    );
  });
}
