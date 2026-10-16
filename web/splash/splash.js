/**
 * Removes the pre-Flutter web splash.
 *
 * The overlay is plain markup in index.html, painted behind Flutter's canvas,
 * so nothing in the widget tree can remove it. `app_runner_web.dart` calls this
 * from a post-frame callback once Flutter has painted its first frame.
 *
 * The element id is pinned by test/branding/web_splash_contract_test.dart,
 * which fails if this function and index.html ever disagree again.
 */
function removeSplashFromWeb() {
  document.getElementById("splash-brand")?.remove();
  document.body.style.background = "transparent";
}
