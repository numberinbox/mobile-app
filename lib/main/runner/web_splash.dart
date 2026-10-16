import 'dart:js_interop';

/// The global defined by `web/splash/splash.js`.
///
/// A classic (non-module) script tag puts the function on `window`, so a
/// top-level external binding resolves to it. Declaring the name here is
/// deliberate: if the script is renamed or stops defining this symbol, the web
/// build fails to compile instead of silently never removing the overlay.
@JS('removeSplashFromWeb')
external void _removeSplashFromWeb();

/// Removes the pre-Flutter splash overlay from the document.
///
/// The overlay lives in index.html and is painted behind Flutter's canvas, so
/// no widget can remove it. This is called from a post-frame callback in
/// [runAppWithMonitoring] once Flutter has painted, so the user never sees a
/// flash of the raw markup.
///
/// The element id is pinned by `test/branding/web_splash_contract_test.dart`,
/// which fails if this function and the markup ever disagree.
void removeWebSplashAfterFirstFrame() {
  _removeSplashFromWeb();
}
