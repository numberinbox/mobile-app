import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';

class HomeView extends GetWidget<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  static const double _markSize = 120;

  /// Light icons for the navy startup surface. `LightSystemUiRegion` wraps the
  /// whole app with dark icons for the light surfaces, and an app-wide region
  /// would otherwise win over [ThemeUtils.setSystemLightUIStyle] on the frame
  /// after this one. The innermost region covering the status bar takes
  /// precedence, so publishing one here keeps the icons readable on navy.
  static const SystemUiOverlayStyle _navyStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    ThemeUtils.setSystemLightUIStyle();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _navyStyle,
      child: ColoredBox(
        color: NumberInboxPalette.navy,
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
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image(
                        image: AssetImage(
                            'assets/images/numberinbox_wordmark_dark.png'),
                        width: 234,
                      ),
                      SizedBox(height: 32),
                      CupertinoActivityIndicator(color: Colors.white),
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
