import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/branding/adaptive_foreground_renderer.dart' as renderer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <circle cx="54" cy="54" r="25" fill="#123456"/>
</svg>
''';

  const oversizedSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <rect x="0" y="0" width="108" height="108" fill="#123456"/>
</svg>
''';

  const offCenterSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <circle cx="25" cy="25" r="25" fill="#123456"/>
</svg>
''';

  const emptySvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
</svg>
''';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('icon_renderer_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String outputPath() => '${tempDir.path}/foreground.png';

  String previewPath(int size, String mask) =>
      '${tempDir.path}/previews/icon_${size}px_$mask.png';

  Future<void> renderSource(String svgSource) {
    final source = File('${tempDir.path}/source.svg')
      ..writeAsStringSync(svgSource);
    return renderer.renderAdaptiveForeground(
      sourcePath: source.path,
      outputPath: outputPath(),
      previewDirectory: '${tempDir.path}/previews',
    );
  }

  group('renderAdaptiveForeground', () {
    test('valid source produces a master and six previews at given paths',
        () async {
      await renderSource(validSvg);

      final masterBytes = File(outputPath()).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(masterBytes);
      final master = (await codec.getNextFrame()).image;
      expect(master.width, 1024);
      expect(master.height, 1024);
      master.dispose();
      codec.dispose();

      for (final size in [48, 96]) {
        for (final mask in ['circle', 'rounded-square', 'squircle']) {
          final preview = File(previewPath(size, mask));
          expect(
            preview.existsSync(),
            isTrue,
            reason: 'missing preview $size/$mask',
          );
          expect(preview.lengthSync(), greaterThan(0));
        }
      }
    });

    test('oversized artwork throws a geometry StateError', () async {
      await expectLater(
        renderSource(oversizedSvg),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('safe circle'),
          ),
        ),
      );
    });

    test('failed validation leaves preseeded destinations unchanged',
        () async {
      final paths = [
        outputPath(),
        for (final size in [48, 96])
          for (final mask in ['circle', 'rounded-square', 'squircle'])
            previewPath(size, mask),
      ];
      for (final path in paths) {
        File(path).parent.createSync(recursive: true);
        File(path).writeAsBytesSync([1, 2, 3, 4]);
      }

      await expectLater(renderSource(oversizedSvg), throwsStateError);

      for (final path in paths) {
        expect(
          File(path).readAsBytesSync(),
          [1, 2, 3, 4],
          reason: '$path was overwritten by a failed render',
        );
      }
    });

    test('empty source is rejected', () async {
      await expectLater(renderSource(emptySvg), throwsStateError);
    });

    test('off-center artwork is rejected', () async {
      await expectLater(renderSource(offCenterSvg), throwsStateError);
    });

    test('rendering honors supplied paths, never repo defaults', () async {
      final master = File('assets/icons/icon_ni_foreground.png');
      final beforeBytes = master.readAsBytesSync();

      await renderSource(validSvg);

      expect(master.readAsBytesSync(), beforeBytes);
      final entries = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      // source.svg + foreground.png + six previews, nothing else.
      expect(entries, hasLength(1 + 1 + 6));
    });
  });

  group('renderMaskPreview', () {
    Future<({int width, ByteData pixels})> decodePng(Uint8List bytes) async {
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final width = image.width;
      image.dispose();
      codec.dispose();
      return (width: width, pixels: pixels);
    }

    Future<ui.Image> decodeMaster() async {
      final codec = await ui.instantiateImageCodec(
        File('assets/icons/icon_ni_foreground.png').readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return image;
    }

    Future<ui.Image> makeMarkerImage() async {
      const total = 1024.0;
      const markerPx = 12 * total / 108;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromCenter(
          center: const ui.Offset(total / 2, total / 2),
          width: markerPx,
          height: markerPx,
        ),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      picture.dispose();
      return image;
    }

    List<int> alphaMap(int width, ByteData pixels) => List<int>.generate(
          width * width,
          (index) => pixels.getUint8(index * 4 + 3),
        );

    test('masks differ, keep transparency, and hold exact dimensions',
        () async {
      final master = await decodeMaster();
      try {
        for (final size in [48, 96]) {
          final alphas = <List<int>>[];
          for (final mask in [
            renderer.PreviewMask.circle,
            renderer.PreviewMask.roundedSquare,
            renderer.PreviewMask.squircle,
          ]) {
            final bytes = await renderer.renderMaskPreview(
              master,
              size: size,
              mask: mask,
            );
            final decoded = await decodePng(bytes);
            expect(decoded.width, size);
            alphas.add(alphaMap(decoded.width, decoded.pixels));
            for (final corner in [(0, 0), (size - 1, 0), (0, size - 1)]) {
              expect(
                decoded.pixels
                    .getUint8((corner.$2 * size + corner.$1) * 4 + 3),
                0,
                reason: '$mask at $size has an opaque corner',
              );
            }
          }
          expect(alphas[0], isNot(alphas[1]), reason: 'circle == rounded');
          expect(alphas[0], isNot(alphas[2]), reason: 'circle == squircle');
          expect(alphas[1], isNot(alphas[2]), reason: 'rounded == squircle');
        }
      } finally {
        master.dispose();
      }
    });

    test('ice shows through inside the mask clear of the artwork', () async {
      const ice = [245, 247, 235, 255];
      final master = await decodeMaster();
      try {
        for (final size in [48, 96]) {
          final scale = size ~/ 48;
          for (final mask in [
            renderer.PreviewMask.circle,
            renderer.PreviewMask.roundedSquare,
            renderer.PreviewMask.squircle,
          ]) {
            final decoded = await decodePng(
              await renderer.renderMaskPreview(
                master,
                size: size,
                mask: mask,
              ),
            );
            for (final point in [(24, 3), (24, 44)]) {
              final x = point.$1 * scale;
              final y = point.$2 * scale;
              final pixel = List<int>.generate(
                4,
                (index) => decoded.pixels
                    .getUint8((y * size + x) * 4 + index),
              );
              expect(
                pixel,
                ice,
                reason: '$mask at $size is not ice at $x,$y',
              );
            }
          }
        }
      } finally {
        master.dispose();
      }
    });

    test('synthetic marker proves the 72dp viewport scale', () async {
      final marker = await makeMarkerImage();
      try {
        for (final entry in [(48, 8), (96, 16)]) {
          final size = entry.$1;
          final decoded = await decodePng(
            await renderer.renderMaskPreview(
              marker,
              size: size,
              mask: renderer.PreviewMask.circle,
            ),
          );
          var xmin = size, xmax = -1;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              final offset = (y * size + x) * 4;
              final red = decoded.pixels.getUint8(offset);
              final green = decoded.pixels.getUint8(offset + 1);
              final blue = decoded.pixels.getUint8(offset + 2);
              if (red - green > 100 && red - blue > 100) {
                if (x < xmin) xmin = x;
                if (x > xmax) xmax = x;
              }
            }
          }
          expect(
            xmax - xmin + 1,
            inInclusiveRange(entry.$2 - 1, entry.$2 + 1),
            reason: 'marker width at $size',
          );
        }
      } finally {
        marker.dispose();
      }
    });

    test('no mask removes significant foreground', () async {
      int significantCount(int width, ByteData pixels) {
        var count = 0;
        for (var i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) >= 16) count++;
        }
        return count;
      }

      final master = await decodeMaster();
      try {
        for (final size in [48, 96]) {
          final unmasked = significantCount(
            size,
            (await decodePng(
              await renderer.renderMaskPreview(
                master,
                size: size,
                mask: renderer.PreviewMask.none,
                background: null,
              ),
            ))
                .pixels,
          );
          expect(unmasked, greaterThan(0));
          for (final mask in [
            renderer.PreviewMask.circle,
            renderer.PreviewMask.roundedSquare,
            renderer.PreviewMask.squircle,
          ]) {
            final masked = significantCount(
              size,
              (await decodePng(
                await renderer.renderMaskPreview(
                  master,
                  size: size,
                  mask: mask,
                  background: null,
                ),
              ))
                  .pixels,
            );
            // Identical counts are expected: the artwork sits well inside
            // every mask. The half-percent allowance covers only one-pixel
            // sampling-boundary differences.
            expect(
              (masked - unmasked).abs() / unmasked,
              lessThan(0.005),
              reason: '$mask at $size removes foreground',
            );
          }
        }
      } finally {
        master.dispose();
      }
    });

    test('artwork measures and centers correctly in previews', () async {
      final master = await decodeMaster();
      try {
        for (final entry in [(48, 33.3), (96, 66.7)]) {
          final size = entry.$1;
          final decoded = await decodePng(
            await renderer.renderMaskPreview(
              master,
              size: size,
              mask: renderer.PreviewMask.none,
              background: null,
            ),
          );
          var xmin = size, xmax = -1, ymin = size, ymax = -1;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              if (decoded.pixels.getUint8((y * size + x) * 4 + 3) < 16) {
                continue;
              }
              if (x < xmin) xmin = x;
              if (x > xmax) xmax = x;
              if (y < ymin) ymin = y;
              if (y > ymax) ymax = y;
            }
          }
          expect(
            xmax - xmin + 1,
            inInclusiveRange(entry.$2 - 1.5, entry.$2 + 1.5),
            reason: 'artwork width at $size',
          );
          expect(
            ((xmin + xmax + 1) / 2 - size / 2).abs(),
            lessThanOrEqualTo(1.0),
            reason: 'artwork center at $size',
          );
          expect(
            ((ymin + ymax + 1) / 2 - size / 2).abs(),
            lessThanOrEqualTo(1.0),
            reason: 'artwork middle at $size',
          );
        }
      } finally {
        master.dispose();
      }
    });
  });
}
