import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';

class HomeView extends GetWidget<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeUtils.setSystemLightUIStyle();
    return const ColoredBox(
      color: NumberInboxPalette.navy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/images/numberinbox_mark.png'),
              width: 120,
              height: 120,
            ),
            SizedBox(height: 22),
            Image(
              image: AssetImage('assets/images/numberinbox_wordmark_dark.png'),
              width: 234,
            ),
            SizedBox(height: 32),
            CupertinoActivityIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
