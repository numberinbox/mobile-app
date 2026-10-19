import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';

class HomeView extends GetWidget<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  /// The same canvas the native splashes paint (256 dp at mdpi / iOS 1x),
  /// from the same artwork the launch screens use. Its mark occupies
  /// 400/1024 of the canvas, so the visible mark is 100 dp wide, centered
  /// like the native frame, and never rescales at the handoff.
  static const double _markCanvasSize = 256;

  /// Vertical extent below the viewport center that the visible mark spans
  /// (100/2 dp) plus the wordmark gap.
  static const double _belowMarkExtent = _markVisibleSize / 2 + 22;

  /// The artwork's opaque region inside the 1024 px canvas is 400 px wide.
  static const double _markVisibleSize = 100;

  /// Dark icons on a white surface, matching the native splash so the
  /// native-to-Flutter transition shows no colour change. Kept local to this
  /// loading screen; every other route is governed by `LightSystemUiRegion`.
  static const SystemUiOverlayStyle _whiteSplashStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _whiteSplashStyle,
      child: ColoredBox(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The mark itself stays at viewport center; the wordmark and
            // spinner flow below it as the second startup stage.
            final belowCenterTop =
                constraints.maxHeight / 2 + _belowMarkExtent;
            return Stack(
              children: [
                const Center(
                  child: Image(
                    image:
                        AssetImage('assets/splash/numberinbox_splash_mark.png'),
                    width: _markCanvasSize,
                    height: _markCanvasSize,
                  ),
                ),
                Positioned(
                  top: belowCenterTop,
                  left: 0,
                  right: 0,
                  // Not const: SvgPicture.asset is not a const constructor.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/images/numberinbox_wordmark.svg',
                        width: 234,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),
                      const CupertinoActivityIndicator(
                        color: NumberInboxPalette.actionGreen,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
