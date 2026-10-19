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

/// Top-left RGBA pixel, used as a cheap opaque-background probe.
List<int> _cornerPixel(Uint8List rgba, int width, int height) =>
    [rgba[0], rgba[1], rgba[2]];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
  final splash = pubspec['flutter_native_splash'] as Map?;

  test('native splash uses a white background', () {
    expect(splash, isNotNull);
    expect((splash!['color'] as String).toLowerCase(), '#ffffff',
        reason: 'every startup surface is pure white, not the navy brand');
    expect((splash['color_dark'] as String).toLowerCase(), '#ffffff',
        reason: 'a device in dark appearance must not show a black splash');
    final android12 = splash['android_12'] as Map?;
    expect((android12!['color'] as String).toLowerCase(), '#ffffff');
    expect((android12['color_dark'] as String).toLowerCase(), '#ffffff',
        reason: 'Android 12 night splash must be white too');
  });

  test('web splash generation is disabled', () {
    // The web splash is hand-authored; letting the package regenerate it
    // rewrites web/index.html with the navy template.
    expect(splash!['web'], isFalse,
        reason: 'web splash must stay hand-authored');
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

  test('no navy remains in the committed splash configuration', () {
    final config = splash!;
    for (final entry in {
      'color': config['color'],
      'color_dark': config['color_dark'],
      'android_12.color': (config['android_12'] as Map?)?['color'],
      'android_12.color_dark': (config['android_12'] as Map?)?['color_dark'],
    }.entries) {
      final value = entry.value;
      if (value == null) continue;
      expect(value.toString().toLowerCase(), isNot('#0f172a'),
          reason: '${entry.key} must not stay navy after the white migration');
    }
  });

  test('generated native splash backgrounds are opaque white', () async {
    const iosBackground =
        'ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png';
    for (final path in [
      iosBackground,
      'android/app/src/main/res/drawable/background.png',
      'android/app/src/main/res/drawable-v21/background.png',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path missing');
      final image = await _decodePng(path);
      final rgba = await _rgbaBytes(image);
      expect(_opaqueBounds(rgba, image.width, image.height), isNotNull,
          reason: '$path must be opaque, not transparent');
      expect(_cornerPixel(rgba, image.width, image.height), const [255, 255, 255],
          reason: '$path must be pure white');
    }
  });

  test('android night launch layer is white, not black', () async {
    // drawable-night is what a device in dark appearance paints behind the mark.
    final night = File('android/app/src/main/res/drawable-night/background.png');
    if (!night.existsSync()) {
      // No night layer means the day drawable is reused, which is already
      // asserted white above.
      return;
    }
    final image = await _decodePng(night.path);
    final rgba = await _rgbaBytes(image);
    expect(_cornerPixel(rgba, image.width, image.height), const [255, 255, 255],
        reason: 'the night launch background must stay white');
  });

  test('android 12 day and night splash themes are white with the mark icon',
      () {
    for (final dir in ['values-v31', 'values-night-v31']) {
      final path = 'android/app/src/main/res/$dir/styles.xml';
      final xml = File(path).readAsStringSync();
      expect(xml, contains('android:windowSplashScreenBackground'),
          reason: '$path must set the Android 12 splash background');
      expect(xml, isNot(contains('#0F172A')),
          reason: '$path still paints a navy Android 12 splash');
      expect(xml.toLowerCase(), contains('#ffffff'),
          reason: '$dir Android 12 splash background must be white');
      expect(xml, contains('@drawable/android12splash'),
          reason: '$path must keep the centered N/@ mark as the splash icon');
    }
  });

  test('android day and night themes cannot flash black or hide system icons',
      () {
    for (final dir in ['values', 'values-night']) {
      final xml =
          File('android/app/src/main/res/$dir/styles.xml').readAsStringSync();
      expect(xml, isNot(contains('Theme.Black')),
          reason: '$dir must not use a black window parent; it would flash '
              'black on a white splash in dark appearance');
      expect(xml, contains('android:windowLightStatusBar'),
          reason: '$dir needs light status-bar icons on a white window');
      expect(xml, contains('android:windowLightNavigationBar'),
          reason: '$dir needs light navigation-bar icons on a white window');
      for (final style in ['LaunchTheme', 'NormalTheme']) {
        expect(xml, contains(style),
            reason: '$dir must define $style');
      }
    }
  });

  test('web splash and PWA manifest are white', () {
    final css = File('web/splash/style.css').readAsStringSync();
    expect(css.toLowerCase(), isNot(contains('#0f172a')),
        reason: 'the web splash must not paint a navy background');
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest.toLowerCase(), isNot(contains('#0f172a')),
        reason: 'the PWA manifest must not request a navy frame');
    expect(manifest, contains('#FFFFFF'),
        reason: 'manifest background/theme color must be white');
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

  test('the splash mark source is bundled in the app so the loading screen '
      'can show the same artwork', () {
    final assets = ((pubspec['flutter'] as Map)['assets'] as List?) ?? const [];
    expect(
      assets.contains('assets/splash/'),
      isTrue,
      reason: 'the Flutter loading screen renders '
              'assets/splash/numberinbox_splash_mark.png, so the folder must '
              'be bundled',
    );
  });

  test('every native splash stage shows the same visible mark', () async {
    // iOS LaunchImage 1x paints at its point size (256x256 pt canvas);
    // Android mdpi bitmaps paint at their pixel size as dp. The platforms
    // center the canvas in the full window, so equal canvases and visible
    // widths keep the handoff stationary.
    final stages = await Future.wait([
      _visibleMark('ios/Runner/Assets.xcassets/LaunchImage.imageset/'
          'LaunchImage.png'),
      _visibleMark('android/app/src/main/res/drawable-mdpi/splash.png'),
      _visibleMark(
          'android/app/src/main/res/drawable-mdpi/android12splash.png'),
    ]);

    final widths = stages.map((s) => s.$1).toList();
    for (var i = 1; i < widths.length; i++) {
      expect(widths[i], closeTo(widths[0], 1),
          reason: 'stage ${stages[i].$4} shows ${stages[i].$1} dp while '
              'stage ${stages[0].$4} shows ${stages[0].$1} dp');
    }
    for (final stage in stages) {
      expect(stage.$1, closeTo(100, 1),
          reason: '${stage.$4} should show the ~100 dp visible mark, '
              'got ${stage.$1} dp');
      expect((stage.$2 - 0.5).abs(), lessThanOrEqualTo(0.01),
          reason: '${stage.$4} mark is off-center horizontally');
      expect((stage.$3 - 0.5).abs(), lessThanOrEqualTo(0.01),
          reason: '${stage.$4} mark is off-center vertically');
    }
  });
}

/// Visible mark measured in dp: (widthDp, centerXFraction, centerYFraction, name).
Future<(double, double, double, String)> _visibleMark(String path) async {
  final image = await _decodePng(path);
  final rgba = await _rgbaBytes(image);
  // Android 12 canvases are 288 dp; regular splash 256 dp; iOS 1x is points.
  final canvasDp = path.contains('android12') ? 288.0 : 256.0;
  final bounds = _opaqueBounds(rgba, image.width, image.height)!;
  final widthDp = (bounds[2] - bounds[0]) / image.width * canvasDp;
  final centerXFrac = (bounds[0] + bounds[2]) / 2 / image.width;
  final centerYFrac = (bounds[1] + bounds[3]) / 2 / image.height;
  return (widthDp, centerXFrac, centerYFrac, path);
}
