// Explicitly invoked Android adaptive-icon foreground generation.
//
// This file is NOT part of the normal test suite: `flutter test` only runs
// `test/`, so everyday verification never rewrites branding assets.
//
// Usage (from the package root):
//   flutter test --no-pub tool/branding/render_adaptive_foreground.dart --reporter expanded
//
// Optional environment overrides (development-tool configuration, not app
// configuration); all handling follows the supplied paths, never hardcoded
// repository destinations:
//   NUMBERINBOX_ICON_SOURCE       default assets/brand/source/adaptive-foreground.svg
//   NUMBERINBOX_ICON_OUTPUT       default assets/icons/icon_ni_foreground.png
//   NUMBERINBOX_ICON_PREVIEW_DIR  default /tmp/icon_review
//
// A single registered test means a successful render exits 0, while a
// validation failure throws StateError (nonzero exit) without writing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'adaptive_foreground_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render Android adaptive foreground', () async {
    final environment = Platform.environment;
    await renderAdaptiveForeground(
      sourcePath: environment['NUMBERINBOX_ICON_SOURCE'] ??
          'assets/brand/source/adaptive-foreground.svg',
      outputPath: environment['NUMBERINBOX_ICON_OUTPUT'] ??
          'assets/icons/icon_ni_foreground.png',
      previewDirectory: environment['NUMBERINBOX_ICON_PREVIEW_DIR'] ??
          '/tmp/icon_review',
    );
  });
}
