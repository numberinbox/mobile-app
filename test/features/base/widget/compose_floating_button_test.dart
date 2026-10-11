import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/floating_button/scrolling_floating_button_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:tmail_ui_user/features/base/widget/compose_floating_button.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

void main() {
  testWidgets('uses the NumberInbox primary action green in light mode',
      _testLightModeUsesBrandGreen);

  testWidgets('keeps the expanded geometry and a single tap callback',
      _testKeepsGeometryAndTap);

  testWidgets('keeps the brand green when collapsed after scrolling',
      _testKeepsBrandGreenWhenCollapsed);

  testWidgets('keeps the prior blue in dark mode', _testDarkModeKeepsBlue);
}

Future<void> _testLightModeUsesBrandGreen(WidgetTester tester) async {
  await _pumpComposeFloatingButton(tester);

  final button = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(
    button.color,
    AppColor.colorComposeButton,
    reason: 'the mobile Compose action must use the light brand green',
  );
  expect(button.color, isNot(AppColor.blue700));
}

Future<void> _testKeepsGeometryAndTap(WidgetTester tester) async {
  var taps = 0;
  await _pumpComposeFloatingButton(
    tester,
    onTap: () => taps++,
  );

  final button = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(button.width, 154);
  expect(button.height, 60);

  final label = tester.widget<Text>(find.text('Compose'));
  expect(label.style?.color, Colors.white);

  await tester.tap(find.byType(ScrollingFloatingButtonAnimated));
  await tester.pump();
  expect(taps, 1);
}

Future<void> _testKeepsBrandGreenWhenCollapsed(WidgetTester tester) async {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);

  await _pumpComposeFloatingButton(
    tester,
    scrollController: scrollController,
    bottom: 400,
  );

  expect(
    tester
        .widget<ScrollingFloatingButtonAnimated>(
          find.byType(ScrollingFloatingButtonAnimated),
        )
        .color,
    AppColor.colorComposeButton,
  );

  scrollController.jumpTo(300);
  await tester.pumpAndSettle();

  final collapsed = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(
    collapsed.color,
    AppColor.colorComposeButton,
    reason: 'the color must not change when the button collapses while scrolling',
  );
}

Future<void> _testDarkModeKeepsBlue(WidgetTester tester) async {
  Get.testMode = true;
  Get.reset();
  Get.put(ImagePaths(), permanent: true);
  final controller = ScrollController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (_, index) => SizedBox(height: 80, child: Text('row $index')),
            ),
            Positioned(
              right: 16,
              bottom: 0,
              child: ComposeFloatingButton(
                scrollController: controller,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();

  final button = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(
    button.color,
    AppColor.blue700,
    reason: 'the dark-theme floating button keeps its existing blue; the brand '
        'green is a light-mode change only',
  );
  expect(button.color, isNot(AppColor.colorComposeButton));
}

Future<void> _pumpComposeFloatingButton(
  WidgetTester tester, {
  VoidCallback? onTap,
  ScrollController? scrollController,
  double bottom = 0,
}) async {
  Get.testMode = true;
  Get.reset();
  Get.put(ImagePaths(), permanent: true);
  final controller = scrollController ?? ScrollController();
  addTearDown(() {
    if (scrollController == null) controller.dispose();
  });

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => Theme(
        data: ThemeUtils.buildAppTheme(context),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (_, index) => SizedBox(height: 80, child: Text('row $index')),
            ),
            Positioned(
              right: 16,
              bottom: bottom,
              child: ComposeFloatingButton(
                scrollController: controller,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}