import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Opt-in device test for the actual native-to-Flutter handoff. Extract PNGs
/// from a cold-start screen recording (for example with ffmpeg's `fps=10`
/// filter), then run:
///
/// NI_SPLASH_FRAME_DIR=/tmp/frames NI_SPLASH_FIRST_FRAME=30 \
/// NI_SPLASH_LAST_FRAME=40 NI_SPLASH_PX_PER_DP=2.625 \
/// flutter test test/branding/splash_handoff_capture_test.dart
///
/// FIRST must be the last stable native-only frame; LAST must be a stable
/// Flutter frame with the wordmark. The numbered interval includes the exit.
/// If a capture misses the native-only frame, set NI_SPLASH_REFERENCE_FRAME to
/// a native-only PNG from an earlier capture of the same device and build.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final directory = Platform.environment['NI_SPLASH_FRAME_DIR'];
  final first = int.tryParse(
    Platform.environment['NI_SPLASH_FIRST_FRAME'] ?? '',
  );
  final last = int.tryParse(Platform.environment['NI_SPLASH_LAST_FRAME'] ?? '');
  final pixelsPerDp = double.tryParse(
    Platform.environment['NI_SPLASH_PX_PER_DP'] ?? '',
  );
  final referencePath = Platform.environment['NI_SPLASH_REFERENCE_FRAME'];
  final configured =
      directory != null &&
      first != null &&
      last != null &&
      pixelsPerDp != null &&
      pixelsPerDp > 0;

  test(
    'native mark remains visible and stationary until Flutter is ready',
    () async {
      final start = first!;
      final end = last!;
      final density = pixelsPerDp!;
      expect(end, greaterThan(start));
      final firstFrame = await _decodeFrame(directory!, start);
      final referenceFrame = referencePath == null
          ? firstFrame
          : await _decodeFile(File(referencePath));
      final native = await _findMark(
        referenceFrame,
        _Bounds(
          (referenceFrame.width * .20).round(),
          (referenceFrame.height * .25).round(),
          (referenceFrame.width * .80).round(),
          (referenceFrame.height * .70).round(),
        ),
      );
      expect(
        native,
        isNotNull,
        reason: 'first frame must show the native mark',
      );
      final reference = native!;
      expect(firstFrame.width, referenceFrame.width);
      expect(firstFrame.height, referenceFrame.height);
      final margin = (20 * density).round();
      final markRegion = _Bounds(
        reference.bounds.left - margin,
        reference.bounds.top - margin,
        reference.bounds.right + margin,
        reference.bounds.bottom + margin,
      );

      for (var number = start; number <= end; number++) {
        final frame = number == start
            ? firstFrame
            : await _decodeFrame(directory, number);
        expect(frame.width, firstFrame.width);
        expect(frame.height, firstFrame.height);
        final mark = await _findMark(frame, markRegion);
        expect(
          mark,
          isNotNull,
          reason: 'frame $number lost the N/@ mark during the handoff',
        );
        if (mark == null) continue;

        expect(
          mark.coloredPixels,
          greaterThanOrEqualTo(reference.coloredPixels * .8),
          reason: 'frame $number fades the mark nearly to white',
        );
        expect(
          (mark.bounds.centerX - reference.bounds.centerX).abs() / density,
          lessThanOrEqualTo(2),
          reason: 'frame $number moves the mark horizontally',
        );
        expect(
          (mark.bounds.centerY - reference.bounds.centerY).abs() / density,
          lessThanOrEqualTo(2),
          reason: 'frame $number moves the mark vertically',
        );
        expect(
          (mark.bounds.width - reference.bounds.width).abs() / density,
          lessThanOrEqualTo(2),
          reason: 'frame $number changes the visible mark width',
        );
        expect(
          (mark.bounds.height - reference.bounds.height).abs() / density,
          lessThanOrEqualTo(2),
          reason: 'frame $number changes the visible mark height',
        );
      }
    },
    skip: configured
        ? null
        : 'Set NI_SPLASH_FRAME_DIR, FIRST_FRAME, LAST_FRAME, and PX_PER_DP for a device capture.',
  );
}

Future<ui.Image> _decodeFrame(String directory, int number) async {
  final file = File(
    '$directory/frame-${number.toString().padLeft(3, '0')}.png',
  );
  return _decodeFile(file);
}

Future<ui.Image> _decodeFile(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  return (await codec.getNextFrame()).image;
}

Future<_Mark?> _findMark(ui.Image image, _Bounds region) async {
  // The N/@ artwork is emerald/cyan. Restrict later frames to the native
  // mark's region so the newly appearing wordmark is not counted as the mark.
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  var count = 0;
  for (
    var y = region.top.clamp(0, image.height);
    y < region.bottom.clamp(0, image.height);
    y++
  ) {
    for (
      var x = region.left.clamp(0, image.width);
      x < region.right.clamp(0, image.width);
      x++
    ) {
      final offset = (y * image.width + x) * 4;
      final red = data.getUint8(offset);
      final green = data.getUint8(offset + 1);
      final blue = data.getUint8(offset + 2);
      if (green - red < 35 || blue - red < 35 || blue < 120) continue;
      count++;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (count == 0) return null;
  return _Mark(_Bounds(left, top, right, bottom), count);
}

class _Bounds {
  const _Bounds(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

class _Mark {
  const _Mark(this.bounds, this.coloredPixels);

  final _Bounds bounds;
  final int coloredPixels;
}
