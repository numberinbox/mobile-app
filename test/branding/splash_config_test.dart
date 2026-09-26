import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// docs/16-branding.md visual tokens on the native splash.
///
/// Startup alignment: the native splash shows only the navy background and a
/// centered N/@ mark. No wordmark, no spinner there; those live on the
/// Flutter loading screen (HomeView).
Future<ui.Image> _decodePng(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<Uint8List> _rgbaBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// Bounding box of pixels with alpha above [threshold], or null when fully
/// transparent. Returns (left, top, right, bottom) inclusive-exclusive.
List<int>? _opaqueBounds(Uint8List rgba, int width, int height,
    {int threshold = 16}) {
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] > threshold) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  if (right < 0) return null;
  return [left, top, right + 1, bottom + 1];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
  final splash = pubspec['flutter_native_splash'] as Map?;

  test('native splash uses brand background', () {
    expect(splash, isNotNull);
    expect((splash!['color'] as String).toLowerCase(), '#0f172a',
        reason: 'splash background must match the navy brand launch screen');
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

  test('native splash has no wordmark branding slot', () {
    final config = splash!;
    expect(config.containsKey('branding'), isFalse,
        reason: 'native splash must show only the mark; '
            'the wordmark lives on the Flutter loading screen');
    final android12 = config['android_12'] as Map?;
    expect(android12 == null || !android12.containsKey('branding'), isTrue,
        reason: 'Android 12 splash must show only the mark');
  });

  test('native splash background is navy in both configurations', () {
    final config = splash!;
    expect((config['color'] as String).toLowerCase(), '#0f172a');
    final android12 = config['android_12'] as Map?;
    expect(android12, isNotNull);
    expect((android12!['color'] as String).toLowerCase(), '#0f172a');
  });

  test('dedicated splash mark assets exist with expected dimensions',
      () async {
    const markPath = 'assets/splash/numberinbox_splash_mark.png';
    const android12Path =
        'assets/splash/numberinbox_splash_mark_android12.png';
    final config = splash!;
    expect(config['image_android'], markPath);
    expect(config['image_ios'], markPath);
    expect((config['android_12'] as Map?)?['image'], android12Path);

    final mark = await _decodePng(markPath);
    expect(mark.width, 1024);
    expect(mark.height, 1024);
    final android12 = await _decodePng(android12Path);
    expect(android12.width, 1152);
    expect(android12.height, 1152);
  });

  test('splash mark is centered with quiet padding', () async {
    final image =
        await _decodePng('assets/splash/numberinbox_splash_mark.png');
    final bounds =
        _opaqueBounds(await _rgbaBytes(image), image.width, image.height);
    expect(bounds, isNotNull, reason: 'splash mark must be visible');
    final centerX = (bounds![0] + bounds[2]) / 2;
    final centerY = (bounds[1] + bounds[3]) / 2;
    expect((centerX - 512).abs(), lessThanOrEqualTo(4),
        reason: 'mark must be horizontally centered, got $bounds');
    expect((centerY - 512).abs(), lessThanOrEqualTo(4),
        reason: 'mark must be vertically centered, got $bounds');
    final visibleWidth = bounds[2] - bounds[0];
    expect(visibleWidth, greaterThanOrEqualTo(360));
    expect(visibleWidth, lessThanOrEqualTo(440));
  });

  test('android 12 splash art clears the circular mask', () async {
    const size = 1152;
    const radius = 384; // 768px safe-area diameter
    final image = await _decodePng(
        'assets/splash/numberinbox_splash_mark_android12.png');
    final rgba = await _rgbaBytes(image);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (rgba[(y * size + x) * 4 + 3] > 16) {
          final dx = x + 0.5 - size / 2;
          final dy = y + 0.5 - size / 2;
          expect(dx * dx + dy * dy, lessThanOrEqualTo(radius * radius),
              reason: 'opaque pixel at ($x, $y) escapes the safe circle');
        }
      }
    }
  });
}
