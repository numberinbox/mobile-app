import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// docs/16-branding.md visual tokens on the native splash.
void main() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
  final splash = pubspec['flutter_native_splash'] as Map?;

  test('native splash uses brand background', () {
    expect(splash, isNotNull);
    expect((splash!['color'] as String).toLowerCase(), '#0b3d2e',
        reason: 'splash background must be the deep-green brand color');
  });

  test('no Twake branding assets on the splash', () {
    final imagePaths = [
      splash?['image_ios'],
      splash?['image_android'],
      splash?['branding'],
      (splash?['android_12'] as Map?)?['image'],
      (splash?['android_12'] as Map?)?['branding'],
    ].whereType<String>();
    for (final path in imagePaths) {
      expect(path.toLowerCase().contains('twp'), isFalse,
          reason: '$path is an upstream Twake asset');
      expect(File(path).existsSync(), isTrue, reason: '$path missing');
    }
  });
}
