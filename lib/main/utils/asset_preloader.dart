import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:flutter/painting.dart';
import 'package:html_editor_enhanced/utils/html_editor_constants.dart';
import 'package:html_editor_enhanced/utils/html_editor_utils.dart';

class AssetPreloader {
  const AssetPreloader._();

  /// Keep the native splash visible until its Flutter replacement can paint.
  static Future<void> preloadSplashMark() async {
    final stream = const AssetImage(
      'assets/splash/numberinbox_splash_mark.png',
    ).resolve(const ImageConfiguration());
    final ready = Completer<void>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        stream.removeListener(listener);
        ready.complete();
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        logWarning('AssetPreloader::preloadSplashMark: $error');
        ready.complete();
      },
    );
    stream.addListener(listener);
    await ready.future;
  }

  static Future<void> preloadHtmlEditorAssets() async {
    try {
      await Future.wait([
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteHtmlAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.jqueryAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteCSSAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteJSAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteFontEOTAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteFontTTFAssetPath),
      ]);
    } catch (e) {
      logWarning('AssetPreloader::preloadHtmlEditorAssets:Exception = $e');
    }
  }
}
