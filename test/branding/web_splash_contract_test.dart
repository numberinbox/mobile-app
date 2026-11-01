import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the hand-authored web splash.
///
/// The splash overlay is a plain `div` that Flutter's canvaskit renderer paints
/// behind. Nothing in the widget tree can remove it, so the handoff has to
/// happen in two places that can silently disagree: the markup that creates the
/// element, and the script that deletes it. These tests pin the two together.
void main() {
  late String indexHtml;
  late String splashJs;

  setUp(() {
    indexHtml = File('web/index.html').readAsStringSync();
    splashJs = File('web/splash/splash.js').readAsStringSync();
  });

  /// Ids the splash script claims to remove.
  Set<String> removedIds() => RegExp(r'getElementById\("([^"]+)"\)')
      .allMatches(splashJs)
      .map((m) => m.group(1)!)
      .toSet();

  Set<String> markupIds() =>
      RegExp(r'id="([^"]+)"').allMatches(indexHtml).map((m) => m.group(1)!).toSet();

  test('every id the splash script removes exists in the markup', () {
    // This is the regression that made the overlay unremovable: splash.js
    // removed #splash and #splash-branding while the markup only ever created
    // a .splash-brand class, so both calls were silent no-ops.
    final missing = removedIds().difference(markupIds());
    expect(
      missing,
      isEmpty,
      reason: 'splash.js removes ids that do not exist in index.html, so the '
          'overlay can never be cleaned up: $missing',
    );
  });

  test('the splash overlay is identifiable by id', () {
    expect(
      indexHtml,
      contains('class="splash-brand"'),
      reason: 'index.html must keep the splash-brand overlay',
    );
    expect(
      indexHtml,
      matches(RegExp(r'id="[^"]+"[^>]*class="splash-brand"')),
      reason: 'the overlay must carry an id that splash.js can remove; a class '
          'alone cannot be targeted with getElementById',
    );
  });

  test('installed iOS web app does not force a black status bar', () {
    expect(
      indexHtml,
      contains('name="apple-mobile-web-app-status-bar-style" content="default"'),
      reason: 'a white NumberInbox surface must not request a black PWA status bar',
    );
  });

  test('splash.js exposes a removal hook for Dart to call', () {
    expect(
      splashJs,
      contains('function removeSplashFromWeb('),
      reason: 'the web runner calls removeSplashFromWeb after the first frame',
    );
    expect(
      splashJs,
      contains('splash-brand'),
      reason: 'removal must target the element the markup actually creates',
    );
  });

  test('the web runner calls the hook after the first frame', () {
    // Guard against the hook being defined but never invoked, which is how the
    // overlay survived in the first place.
    final runner =
        File('lib/main/runner/app_runner_web.dart').readAsStringSync();
    expect(
      runner,
      contains('removeWebSplashAfterFirstFrame'),
      reason: 'the web runner must remove the splash once Flutter has painted',
    );
    expect(
      runner,
      contains('addPostFrameCallback'),
      reason: 'removal must wait for Flutter\'s first frame',
    );
  });

  test('the Dart helper reaches the JS function in splash.js', () {
    // The chain has three links; assert each one so a break anywhere is caught.
    final helper =
        File('lib/main/runner/web_splash.dart').readAsStringSync();
    expect(helper, contains('removeSplashFromWeb'),
        reason: 'the Dart helper must invoke the JS hook by name');
    expect(
      indexHtml,
      contains('splash/splash.js'),
      reason: 'index.html must load the script that defines the hook',
    );
  });

  test('removal is defensive so a missing element cannot throw', () {
    expect(
      splashJs,
      contains('?.remove()'),
      reason: 'use optional chaining; the overlay may already be gone',
    );
  });

  test('web splash paints the same visible mark size as Flutter and native',
      () async {
    final css = File('web/splash/style.css').readAsStringSync();
    final markStyle = RegExp(r'\.splash-mark\s*\{([^}]+)\}')
        .firstMatch(css)!.group(1)!;
    final canvasWidth = double.parse(
      RegExp(r'\bwidth:\s*([\d.]+)px').firstMatch(markStyle)!.group(1)!,
    );

    Future<double> visibleWidth(String path, double renderedWidth) async {
      final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var left = image.width, right = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (rgba.getUint8((y * image.width + x) * 4 + 3) <= 16) continue;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
      final visible = (right - left + 1) * renderedWidth / image.width;
      image.dispose();
      codec.dispose();
      return visible;
    }

    final flutterWidth = await visibleWidth(
      'assets/splash/numberinbox_splash_mark.png', 256,
    );
    final webWidth = await visibleWidth(
      'web/splash/img/numberinbox-mark.png', canvasWidth,
    );
    expect(webWidth, closeTo(flutterWidth, 1),
        reason: 'removing the web overlay must not resize the visible N');

    final wordmarkStyle = RegExp(r'\.splash-wordmark\s*\{([^}]+)\}')
        .firstMatch(css)!.group(1)!;
    final wordmarkOffset = double.parse(
      RegExp(r'top:\s*calc\(50%\s*\+\s*([\d.]+)px\)')
          .firstMatch(wordmarkStyle)!.group(1)!,
    );
    expect(wordmarkOffset, closeTo(flutterWidth / 2 + 22, 1),
        reason: 'the web wordmark must use the Flutter stage\'s 22px gap');
  });
}
