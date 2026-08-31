import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// docs/16-branding.md: launcher icon in brand colors, upstream assets gone.
void main() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
  final iconConfig = pubspec['flutter_launcher_icons'] as Map?;

  test('flutter_launcher_icons configured for NumberInbox', () {
    expect(iconConfig, isNotNull, reason: 'add flutter_launcher_icons config');
    expect(iconConfig!['android'], isTrue);
    expect(iconConfig['ios'], isTrue);
    final imagePath = iconConfig['image_path'] as String;
    expect(imagePath.toLowerCase().contains('twake'), isFalse);
    expect(File(imagePath).existsSync(), isTrue, reason: '$imagePath missing');
  });

  test('adaptive icon background is brand blue', () {
    final colors = File(
            'android/app/src/main/res/values/colors.xml')
        .readAsStringSync();
    expect(colors.toUpperCase().contains('#2196F3'), isTrue,
        reason: 'ic_launcher_background must be #2196F3');
    expect(colors.contains('#000000'), isFalse,
        reason: 'upstream black background still present');
  });

  test('launcher mipmaps exist', () {
    for (final dir in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final dirPath = 'android/app/src/main/res/mipmap-$dir';
      final files = Directory(dirPath).listSync().whereType<File>().map((f) => f.path).toList();
      expect(files.any((p) => p.contains('ic_launcher')),
          isTrue, reason: 'missing ic_launcher in mipmap-$dir');
    }
  });
}
