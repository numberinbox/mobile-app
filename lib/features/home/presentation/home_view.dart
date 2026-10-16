import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';

class HomeView extends GetWidget<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  static const double _markSize = 120;

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
                constraints.maxHeight / 2 + _markSize / 2 + 22;
            return Stack(
              children: [
                const Center(
                  child: Image(
                    image: AssetImage('assets/images/numberinbox_mark.png'),
                    width: _markSize,
                    height: _markSize,
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
