import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config =
      loadYaml(File('flutter_launcher_icons.yaml').readAsStringSync()) as Map;
  final iconConfig = config['flutter_icons'] as Map;
  const ice = [245, 247, 235, 255];

  (int, int) pngSize(String path) {
    final bytes = File(path).readAsBytesSync();
    expect(bytes.take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ], reason: '$path must be a PNG image');
    final data = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    return (data.getUint32(16), data.getUint32(20));
  }

  Future<List<int>> pixelAt(String path, int x, int y) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (y * image.width + x) * 4;
    final pixel = List<int>.generate(
      4,
      (index) => data.getUint8(offset + index),
    );
    image.dispose();
    codec.dispose();
    return pixel;
  }

  test('flutter_launcher_icons configured for NumberInbox', () {
    expect(iconConfig['android'], isTrue);
    expect(iconConfig['ios'], isTrue);
    final imagePath = iconConfig['image_path'] as String;
    expect(imagePath.toLowerCase().contains('twake'), isFalse);
    expect(File(imagePath).existsSync(), isTrue, reason: '$imagePath missing');
    expect(pngSize(imagePath), (1024, 1024));
    expect(pngSize(iconConfig['adaptive_icon_foreground'] as String), (
      1024,
      1024,
    ));
  });

  test('adaptive icon background is brand ice', () {
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    expect(
      colors.toUpperCase().contains('#F5F7EB'),
      isTrue,
      reason: 'ic_launcher_background must be #F5F7EB',
    );
    expect(
      colors.contains('#000000'),
      isFalse,
      reason: 'upstream black background still present',
    );
  });

  test('launcher mipmaps exist', () {
    for (final dir in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final dirPath = 'android/app/src/main/res/mipmap-$dir';
      final files = Directory(
        dirPath,
      ).listSync().whereType<File>().map((f) => f.path).toList();
      expect(
        files.any((p) => p.endsWith('ic_launcher.png')),
        isTrue,
        reason: 'missing ic_launcher.png in mipmap-$dir',
      );
      expect(
        files.any((p) => p.endsWith('ic_launcher_round.png')),
        isTrue,
        reason: 'missing round icon in mipmap-$dir',
      );
    }
  });

  test('generated iOS and web icons have production dimensions', () {
    expect(pngSize('ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png'), (
      1024,
      1024,
    ));
    expect(pngSize('web/icons/Icon-192.png'), (192, 192));
    expect(pngSize('web/icons/Icon-maskable-512.png'), (512, 512));
  });

  test('every referenced iOS app icon has its expected size', () {
    const iconDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents =
        jsonDecode(File('$iconDirectory/Contents.json').readAsStringSync())
            as Map;
    for (final entry in contents['images'] as List) {
      final filename = (entry as Map)['filename'] as String?;
      if (filename == null) continue;
      final size = int.parse(filename.replaceFirst('.png', ''));
      expect(pngSize('$iconDirectory/$filename'), (size, size));
    }
  });

  test('launcher and store icons use the unframed light mark', () async {
    for (final path in [
      'assets/icons/icon_ni_logo.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png',
      'android/app/src/main/ic_launcher-playstore.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      final (width, height) = pngSize(path);
      expect(
        await pixelAt(path, 0, 0),
        ice,
        reason: '$path must have an ice background',
      );
      expect(
        await pixelAt(path, width ~/ 2, height ~/ 2),
        isNot(ice),
        reason: '$path must show the full-color mark, not the old envelope',
      );
    }
    expect(File('web/favicon.svg').readAsStringSync(), contains('#F5F7EB'));
  });

  test('iOS marketing icon is fully opaque', () async {
    const path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png';
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var transparentPixels = 0;
    for (var offset = 3; offset < data.lengthInBytes; offset += 4) {
      if (data.getUint8(offset) != 255) transparentPixels++;
    }
    expect(transparentPixels, 0, reason: '$path contains transparency');
    image.dispose();
    codec.dispose();
  });
}
