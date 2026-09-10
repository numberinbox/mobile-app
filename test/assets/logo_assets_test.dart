import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logo assets use outlined paths (no font-dependent <text>)', () {
    for (final name in [
      'assets/images/ic_logo_with_text.svg',
      'assets/images/ic_logo_with_text_beta.svg',
    ]) {
      test('$name has no <text> elements', () {
        final content = File(name).readAsStringSync();
        expect(content.contains('<text'), isFalse,
            reason: '$name must not contain <text> (renders inconsistently on Android vs iOS)');
      });

      test('$name has outlined letter paths', () {
        final content = File(name).readAsStringSync();
        expect(content.contains('<path'), isTrue);
        expect(content.contains('fill="black"'), isTrue);
        expect(content.contains('#2196F3'), isTrue);
      });

      test('$name keeps brand icon', () {
        final content = File(name).readAsStringSync();
        expect(content.contains('iconGrad'), isTrue);
      });
    }
  });
}
