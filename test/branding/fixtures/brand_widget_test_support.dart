import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';

final primaryFill = find.byWidgetPredicate((widget) {
  final decoration = switch (widget) {
    Ink() => widget.decoration,
    DecoratedBox() => widget.decoration,
    _ => null,
  };
  return decoration is BoxDecoration &&
      decoration.gradient == NumberInboxPalette.primaryActionGradient;
});

Future<void> pumpAction(
  WidgetTester tester,
  WidgetBuilder builder, {
  Size size = const Size(800, 600),
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    GetMaterialApp(
      theme: ThemeUtils.buildAppTheme(),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
