// Side-effect-free Android adaptive-icon rendering helpers.
//
// Importing this module registers no tests, initializes no bindings, and
// writes no files. The explicitly invoked entry point lives in
// `render_adaptive_foreground.dart`; verification tests import only this
// module.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';

/// Launcher preview mask shapes.
enum PreviewMask {
  circle,
  roundedSquare,
  squircle,

  /// No clipping. Test-only: lets verification compare masked coverage
  /// against the unmasked foreground using the same crop and scale.
  /// Production preview generation never uses this value.
  none,
}

const _renderSize = 1024;
const _layerSize = 108.0;
const _safeRadius = 33.0;
const _minArtworkDp = 48.0;
const _maxArtworkDp = 52.0;

/// Renders the SVG at [sourcePath] to a 1024×1024 transparent PNG at
/// [outputPath], then writes 48px/96px masked previews into
/// [previewDirectory]. Every path is explicit: nothing falls back to a
/// hardcoded repository destination.
///
/// The rendered master is validated before anything is written; invalid
/// geometry throws [StateError] and leaves all destinations untouched.
Future<void> renderAdaptiveForeground({
  required String sourcePath,
  required String outputPath,
  required String previewDirectory,
}) async {
  final svgSource = File(sourcePath).readAsStringSync();
  final pictureInfo = await vg.loadPicture(SvgStringLoader(svgSource), null);
  try {
    // Picture.toImage rasterizes at intrinsic size without scaling, so
    // replay the vector scaled to the render size explicitly. Uniform
    // width-based scaling keeps nonsquare sources nonsquare, which the
    // geometry validation below rejects.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(_renderSize / pictureInfo.size.width);
    canvas.drawPicture(pictureInfo.picture);
    final scaled = recorder.endRecording();
    try {
      final image = await scaled.toImage(_renderSize, _renderSize);
      try {
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        assertForegroundGeometry(image.width, image.height, pixels);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(outputPath);
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(png!.buffer.asUint8List());
        for (final size in [48, 96]) {
          for (final mask in [
            PreviewMask.circle,
            PreviewMask.roundedSquare,
            PreviewMask.squircle
          ]) {
            final preview = await renderMaskPreview(
              image,
              size: size,
              mask: mask,
            );
            final file = File(
              '$previewDirectory/icon_${size}px_${_maskName(mask)}.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(preview);
          }
        }
      } finally {
        image.dispose();
      }
    } finally {
      scaled.dispose();
    }
  } finally {
    pictureInfo.picture.dispose();
  }
}

/// Validates rendered foreground geometry, throwing a descriptive
/// [StateError] for invalid geometry: nonsquare/empty renders, artwork
/// outside the 33dp safe circle, off-center or usefully-sized violations,
/// opaque canvas corners, or almost no visible artwork.
void assertForegroundGeometry(int width, int height, ByteData pixels) {
  Never invalid(String reason) => throw StateError(
        'Invalid adaptive foreground: $reason',
      );

  if (width <= 0 || height <= 0 || width != height) {
    invalid('render is ${width}x$height, expected a square foreground');
  }
  var maxRadius = 0.0;
  var xmin = width, xmax = -1, ymin = width, ymax = -1, visible = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels.getUint8((y * width + x) * 4 + 3) < 16) continue;
      visible++;
      if (x < xmin) xmin = x;
      if (x > xmax) xmax = x;
      if (y < ymin) ymin = y;
      if (y > ymax) ymax = y;
      final dx = ((x + 0.5) - width / 2) * _layerSize / width;
      final dy = ((y + 0.5) - height / 2) * _layerSize / height;
      maxRadius = math.max(maxRadius, math.sqrt(dx * dx + dy * dy));
    }
  }
  if (visible == 0) invalid('render contains no visible artwork');
  if (maxRadius > _safeRadius) {
    invalid('artwork radius ${maxRadius.toStringAsFixed(1)}dp exceeds '
        '${_safeRadius.toStringAsFixed(0)}dp safe circle');
  }
  final dpWidth = (xmax - xmin + 1) * _layerSize / width;
  final dpHeight = (ymax - ymin + 1) * _layerSize / height;
  if (dpWidth < _minArtworkDp ||
      dpWidth > _maxArtworkDp ||
      dpHeight < _minArtworkDp ||
      dpHeight > _maxArtworkDp) {
    invalid('artwork ${dpWidth.toStringAsFixed(1)}x${dpHeight.toStringAsFixed(1)}dp '
        'outside ${_minArtworkDp.toStringAsFixed(0)}-'
        '${_maxArtworkDp.toStringAsFixed(0)}dp band');
  }
  if ((((xmin + xmax + 1) / 2 - width / 2).abs() > 1.0) ||
      (((ymin + ymax + 1) / 2 - height / 2).abs() > 1.0)) {
    invalid('artwork bounding box is off-center');
  }
  for (final corner in [
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
  ]) {
    if (pixels.getUint8((corner.$2 * width + corner.$1) * 4 + 3) != 0) {
      invalid('opaque canvas corner at ${corner.$1},${corner.$2}');
    }
  }
  if (visible / (width * height) < 0.05) {
    invalid('almost no visible artwork');
  }
}

/// Renders [foreground] into the central 72dp viewport at [size] pixels,
/// clipped to [mask], with [background] painted inside the clip when
/// supplied. Returns the PNG bytes; no filesystem side effects. The
/// caller-owned [foreground] is never disposed here.
Future<Uint8List> renderMaskPreview(
  ui.Image foreground, {
  required int size,
  required PreviewMask mask,
  ui.Color? background = const ui.Color(0xFFF5F7EB),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();
  if (mask != PreviewMask.none) {
    canvas.clipPath(_maskPath(mask, size.toDouble()), doAntiAlias: true);
  }
  if (background != null) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..color = background,
    );
  }
  final sourceWidth = foreground.width.toDouble();
  final sourceHeight = foreground.height.toDouble();
  canvas.drawImageRect(
    foreground,
    ui.Rect.fromLTWH(
      sourceWidth / 6,
      sourceHeight / 6,
      sourceWidth * 2 / 3,
      sourceHeight * 2 / 3,
    ),
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(size, size);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

String _maskName(PreviewMask mask) => switch (mask) {
      PreviewMask.circle => 'circle',
      PreviewMask.roundedSquare => 'rounded-square',
      PreviewMask.squircle => 'squircle',
      PreviewMask.none => 'none',
    };

ui.Path _maskPath(PreviewMask mask, double size) {
  switch (mask) {
    case PreviewMask.circle:
      return ui.Path()
        ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(size / 2, size / 2),
          radius: size / 2,
        ));
    case PreviewMask.roundedSquare:
      return ui.Path()
        ..addRRect(ui.RRect.fromLTRBR(
          0,
          0,
          size,
          size,
          ui.Radius.circular(size / 4),
        ));
    case PreviewMask.squircle:
      const steps = 64;
      const exponent = 4.0;
      final path = ui.Path();
      for (var i = 0; i <= steps; i++) {
        final t = 2 * math.pi * i / steps;
        final c = math.cos(t);
        final s = math.sin(t);
        final x = size / 2 + (size / 2) * c.sign * math.pow(c.abs(), 2 / exponent);
        final y = size / 2 + (size / 2) * s.sign * math.pow(s.abs(), 2 / exponent);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    case PreviewMask.none:
      return ui.Path()
        ..addRect(ui.Rect.fromLTWH(0, 0, size, size));
  }
}
