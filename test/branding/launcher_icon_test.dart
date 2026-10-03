import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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

  group('adaptive foreground safe geometry', () {
    const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
    const expectedDimensions = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };

    String densityPath(String density) =>
        'android/app/src/main/res/drawable-$density/ic_launcher_foreground.png';

    Future<
        ({
          int width,
          ByteData pixels,
          double maxRadius,
          int xmin,
          int xmax,
          int ymin,
          int ymax,
          int visible
        })> foregroundGeometry(String path) async {
      final codec =
          await ui.instantiateImageCodec(File(path).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final width = image.width;
      image.dispose();
      codec.dispose();
      var maxRadius = 0.0;
      var xmin = width, xmax = -1, ymin = width, ymax = -1, visible = 0;
      for (var y = 0; y < width; y++) {
        for (var x = 0; x < width; x++) {
          if (pixels.getUint8((y * width + x) * 4 + 3) < 16) continue;
          visible++;
          if (x < xmin) xmin = x;
          if (x > xmax) xmax = x;
          if (y < ymin) ymin = y;
          if (y > ymax) ymax = y;
          final dx = ((x + 0.5) - width / 2) * 108 / width;
          final dy = ((y + 0.5) - width / 2) * 108 / width;
          maxRadius = math.max(maxRadius, math.sqrt(dx * dx + dy * dy));
        }
      }
      return (
        width: width,
        pixels: pixels,
        maxRadius: maxRadius,
        xmin: xmin,
        xmax: xmax,
        ymin: ymin,
        ymax: ymax,
        visible: visible
      );
    }

    test('master foreground is 1024x1024', () {
      expect(
        pngSize(iconConfig['adaptive_icon_foreground'] as String),
        (1024, 1024),
      );
    });

    test('generated densities have native dimensions', () {
      for (final density in densities) {
        final size = expectedDimensions[density]!;
        expect(pngSize(densityPath(density)), (size, size));
      }
    });

    test('visible artwork fits the 33dp safe circle', () async {
      final paths = [
        iconConfig['adaptive_icon_foreground'] as String,
        for (final density in densities) densityPath(density),
      ];
      for (final path in paths) {
        final geometry = await foregroundGeometry(path);
        expect(
          geometry.maxRadius,
          lessThanOrEqualTo(33.0),
          reason: '$path extends beyond the 33dp safe circle',
        );
      }
    });

    test('visible artwork stays centered within one pixel', () async {
      final paths = [
        iconConfig['adaptive_icon_foreground'] as String,
        for (final density in densities) densityPath(density),
      ];
      for (final path in paths) {
        final geometry = await foregroundGeometry(path);
        expect(
          ((geometry.xmin + geometry.xmax + 1) / 2 - geometry.width / 2).abs(),
          lessThanOrEqualTo(1.0),
          reason: '$path is off-center horizontally',
        );
        expect(
          ((geometry.ymin + geometry.ymax + 1) / 2 - geometry.width / 2).abs(),
          lessThanOrEqualTo(1.0),
          reason: '$path is off-center vertically',
        );
      }
    });

    test('visible artwork keeps a useful 48-52dp size', () async {
      final paths = [
        iconConfig['adaptive_icon_foreground'] as String,
        for (final density in densities) densityPath(density),
      ];
      for (final path in paths) {
        final geometry = await foregroundGeometry(path);
        final width = geometry.width;
        final dpWidth = (geometry.xmax - geometry.xmin + 1) * 108 / width;
        final dpHeight = (geometry.ymax - geometry.ymin + 1) * 108 / width;
        expect(dpWidth, inInclusiveRange(48.0, 52.0), reason: '$path width');
        expect(dpHeight, inInclusiveRange(48.0, 52.0), reason: '$path height');
      }
    });

    test('foreground stays transparent with substantial artwork', () async {
      final paths = [
        iconConfig['adaptive_icon_foreground'] as String,
        for (final density in densities) densityPath(density),
      ];
      for (final path in paths) {
        final geometry = await foregroundGeometry(path);
        final width = geometry.width;
        final pixels = geometry.pixels;
        for (final corner in [(0, 0), (width - 1, 0), (0, width - 1)]) {
          expect(
            pixels.getUint8((corner.$2 * width + corner.$1) * 4 + 3),
            0,
            reason: '$path has an opaque corner',
          );
        }
        expect(
          geometry.visible / (width * width),
          greaterThan(0.05),
          reason: '$path has almost no visible artwork',
        );
      }
    });

    test('launcher masks remove no foreground pixels', () async {
      // Same layer-coordinate model as the review previews: the full
      // 108dp layer with masks in the central 72dp viewport (half-width
      // 36dp, rounded corner radius 18dp, squircle exponent 4). The circle
      // retains radius 36dp.
      bool inRoundedSquare(double dx, double dy) {
        const half = 36.0;
        const corner = 18.0;
        if (dx.abs() > half || dy.abs() > half) return false;
        final ox = dx.abs() - (half - corner);
        final oy = dy.abs() - (half - corner);
        if (ox > 0 && oy > 0 && ox * ox + oy * oy > corner * corner) {
          return false;
        }
        return true;
      }

      bool inSquircle(double dx, double dy) {
        const half = 36.0;
        final nx = dx.abs() / half;
        final ny = dy.abs() / half;
        return nx * nx * nx * nx + ny * ny * ny * ny <= 1.0;
      }

      final paths = [
        iconConfig['adaptive_icon_foreground'] as String,
        for (final density in densities) densityPath(density),
      ];
      for (final path in paths) {
        final geometry = await foregroundGeometry(path);
        final width = geometry.width;
        final pixels = geometry.pixels;
        var circleRemoved = 0;
        var roundedRemoved = 0;
        var squircleRemoved = 0;
        for (var y = 0; y < width; y++) {
          for (var x = 0; x < width; x++) {
            if (pixels.getUint8((y * width + x) * 4 + 3) < 16) continue;
            final dx = ((x + 0.5) - width / 2) * 108 / width;
            final dy = ((y + 0.5) - width / 2) * 108 / width;
            if (dx * dx + dy * dy > 36 * 36) circleRemoved++;
            if (!inRoundedSquare(dx, dy)) roundedRemoved++;
            if (!inSquircle(dx, dy)) squircleRemoved++;
          }
        }
        expect(circleRemoved, 0, reason: '$path loses pixels to a circle');
        expect(
          roundedRemoved,
          0,
          reason: '$path loses pixels to a rounded square',
        );
        expect(squircleRemoved, 0, reason: '$path loses pixels to a squircle');
      }
    });

    test('adaptive resources reference the corrected layers', () {
      for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
        final xml = File(
          'android/app/src/main/res/mipmap-anydpi-v26/$name',
        ).readAsStringSync();
        expect(
          xml.contains('@drawable/ic_launcher_foreground'),
          isTrue,
          reason: '$name must reference the foreground',
        );
        expect(
          xml.contains('@color/ic_launcher_background'),
          isTrue,
          reason: '$name must reference the ice background',
        );
      }
    });
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
