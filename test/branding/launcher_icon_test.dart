import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final config = loadYaml(File('flutter_launcher_icons.yaml').readAsStringSync()) as Map;
  final iconConfig = config['flutter_icons'] as Map;

  (int, int) pngSize(String path) {
    final bytes = File(path).readAsBytesSync();
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10],
        reason: '$path must be a PNG image');
    final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    return (data.getUint32(16), data.getUint32(20));
  }

  test('flutter_launcher_icons configured for NumberInbox', () {
    expect(iconConfig['android'], isTrue);
    expect(iconConfig['ios'], isTrue);
    final imagePath = iconConfig['image_path'] as String;
    expect(imagePath.toLowerCase().contains('twake'), isFalse);
    expect(File(imagePath).existsSync(), isTrue, reason: '$imagePath missing');
    expect(pngSize(imagePath), (1024, 1024));
    expect(pngSize(iconConfig['adaptive_icon_foreground'] as String), (1024, 1024));
  });

  test('adaptive icon background is brand navy', () {
    final colors = File(
            'android/app/src/main/res/values/colors.xml')
        .readAsStringSync();
    expect(colors.toUpperCase().contains('#0F172A'), isTrue,
        reason: 'ic_launcher_background must be #0F172A');
    expect(colors.contains('#000000'), isFalse,
        reason: 'upstream black background still present');
  });

  test('launcher mipmaps exist', () {
    for (final dir in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final dirPath = 'android/app/src/main/res/mipmap-$dir';
      final files = Directory(dirPath).listSync().whereType<File>().map((f) => f.path).toList();
      expect(files.any((p) => p.endsWith('ic_launcher.png')),
          isTrue, reason: 'missing ic_launcher.png in mipmap-$dir');
      expect(files.any((p) => p.endsWith('ic_launcher_round.png')),
          isTrue, reason: 'missing round icon in mipmap-$dir');
    }
  });

  test('generated iOS and web icons have production dimensions', () {
    expect(pngSize('ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png'),
        (1024, 1024));
    expect(pngSize('web/icons/Icon-192.png'), (192, 192));
    expect(pngSize('web/icons/Icon-maskable-512.png'), (512, 512));
  });
}
