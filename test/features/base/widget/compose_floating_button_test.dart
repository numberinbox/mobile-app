import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
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
  testWidgets('light mode paints the shared primary action gradient',
      _testLightModeUsesSharedGradient);

  testWidgets('keeps the expanded geometry and a single tap callback',
      _testKeepsGeometryAndTap);

  testWidgets('keeps the shared gradient when collapsed after scrolling',
      _testKeepsSharedGradientWhenCollapsed);

  testWidgets('keeps the prior blue in dark mode', _testDarkModeKeepsBlue);

  testWidgets('a color-only caller still paints its solid color',
      _testColorOnlyCallerPaintsSolidColor);
}

Future<void> _testLightModeUsesSharedGradient(WidgetTester tester) async {
  await _pumpComposeFloatingButton(tester);

  final button = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(
    button.gradient,
    NumberInboxPalette.primaryActionGradient,
    reason: 'the mobile Compose action must paint the shared palette token '
        'instead of a solid green copy',
  );
  expect(button.color, isNull, reason: 'a gradient button must not also set '
      'a solid fill, which BoxDecoration rejects');

  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byType(ScrollingFloatingButtonAnimated),
      matching: find.byType(Ink),
    ),
  );
  final decoration = ink.decoration! as BoxDecoration;
  expect(decoration.gradient, NumberInboxPalette.primaryActionGradient);
  expect(decoration.color, isNull);
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

  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byType(ScrollingFloatingButtonAnimated),
      matching: find.byType(Ink),
    ),
  );
  final radius = (ink.decoration! as BoxDecoration).borderRadius! as BorderRadius;
  expect(
    radius.topLeft.x,
    button.height! / 2,
    reason: 'the expanded button stays a pill',
  );

  final label = tester.widget<Text>(find.text('Compose'));
  expect(label.style?.color, Colors.white);

  await tester.tap(find.byType(ScrollingFloatingButtonAnimated));
  await tester.pump();
  expect(taps, 1);
}

Future<void> _testKeepsSharedGradientWhenCollapsed(WidgetTester tester) async {
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
        .gradient,
    NumberInboxPalette.primaryActionGradient,
  );

  scrollController.jumpTo(300);
  await tester.pumpAndSettle();

  final collapsed = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(
    collapsed.gradient,
    NumberInboxPalette.primaryActionGradient,
    reason: 'the gradient must not change when the button collapses while '
        'scrolling',
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
        'gradient is a light-mode change only',
  );
  expect(button.color, isNot(AppColor.colorComposeButton));
  expect(button.gradient, isNull);
}

Future<void> _testColorOnlyCallerPaintsSolidColor(WidgetTester tester) async {
  const solidRed = Color(0xFFE11D48);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ScrollingFloatingButtonAnimated(
            icon: const Icon(Icons.edit, color: Colors.white),
            text: const Text('Label', style: TextStyle(color: Colors.white)),
            onPress: () {},
            scrollController: ScrollController(),
            color: solidRed,
            width: 154,
            height: 60,
            animateIcon: false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final button = tester.widget<ScrollingFloatingButtonAnimated>(
    find.byType(ScrollingFloatingButtonAnimated),
  );
  expect(button.gradient, isNull, reason: 'old color-only callers keep their '
      'API: no gradient parameter is required');

  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byType(ScrollingFloatingButtonAnimated),
      matching: find.byType(Ink),
    ),
  );
  final decoration = ink.decoration! as BoxDecoration;
  expect(decoration.color, solidRed);
  expect(decoration.gradient, isNull);
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
