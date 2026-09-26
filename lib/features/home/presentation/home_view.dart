import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';

class HomeView extends GetWidget<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  static const double _markSize = 120;

  @override
  Widget build(BuildContext context) {
    ThemeUtils.setSystemLightUIStyle();
    return ColoredBox(
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
                  children: const [
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
    );
  }
}
