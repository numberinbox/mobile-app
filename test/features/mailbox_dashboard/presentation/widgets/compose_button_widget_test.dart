import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/widgets/compose_button_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

void main() {
  testWidgets('paints the shared gradient behind the light-mode sidebar button',
      _testLightModeGradientBehindButton);

  testWidgets('uses the resolved horizontal padding for the default width',
      _testDefaultWidthUsesResolvedPadding);

  testWidgets('keeps the design-system primary action color in dark mode',
      _testKeepsDesignSystemColorInDarkMode);

  testWidgets('clamps the default width when horizontal padding is too large',
      _testClampsDefaultWidthWithOversizedPadding);
}

/// The gradient [DecoratedBox] the light-mode sidebar Compose pill is painted on.
BoxDecoration lightGradientDecoration(WidgetTester tester) {
  final decorationFinder = find.ancestor(
    of: find.byKey(const Key(UiKeys.composeEmailPrimaryAction)),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox && widget.decoration is BoxDecoration,
    ),
  );
  for (final box in tester.widgetList<DecoratedBox>(decorationFinder)) {
    final decoration = box.decoration as BoxDecoration;
    if (decoration.gradient != null) return decoration;
  }
  throw StateError('no gradient DecoratedBox found above the Compose button');
}

Future<void> _testLightModeGradientBehindButton(WidgetTester tester) async {
  var composeCalls = 0;

  await _pumpComposeButton(
    tester,
    onTapAction: () => composeCalls++,
  );

  final decoration = lightGradientDecoration(tester);
  expect(
    decoration.gradient,
    NumberInboxPalette.primaryActionGradient,
    reason: 'the sidebar Compose action must paint the shared palette token '
        'behind the pill',
  );
  expect(
    (decoration.borderRadius! as BorderRadius).topLeft.x,
    greaterThanOrEqualTo(20),
    reason: 'the gradient pill is stadium-shaped (fully rounded ends)',
  );

  final buttonFinder = find.byKey(const Key(UiKeys.composeEmailPrimaryAction));
  final button = tester.widget<FilledButton>(buttonFinder);
  expect(
    button.style?.backgroundColor?.resolve({}),
    Colors.transparent,
    reason: 'the button surface must let the gradient show through',
  );
  expect(
    button.style?.backgroundColor?.resolve({WidgetState.hovered}),
    Colors.transparent,
    reason: 'hover must not cover the gradient with an opaque container',
  );
  expect(
    button.style?.backgroundColor?.resolve({WidgetState.focused}),
    Colors.transparent,
    reason: 'focus must not cover the gradient with an opaque container',
  );
  expect(
    button.style?.backgroundColor?.resolve({WidgetState.pressed}),
    Colors.transparent,
    reason: 'press must not cover the gradient with an opaque container',
  );
  expect(
    button.style?.backgroundColor?.resolve({WidgetState.disabled}),
    Colors.transparent,
    reason: 'the disabled state also stays transparent on the gradient',
  );

  final hoverOverlay =
      button.style?.overlayColor?.resolve({WidgetState.hovered});
  expect(hoverOverlay, isNotNull);
  expect(
    hoverOverlay!.a,
    greaterThan(0),
    reason: 'a translucent state layer keeps hover and focus visible',
  );

  expect(button.style?.foregroundColor?.resolve({}), NumberInboxPalette.primaryActionForeground);
  expect(button.style?.minimumSize?.resolve({}), const Size(0, 40));
  expect(
    tester.getSize(find.byType(FilledButton)),
    const Size(ResponsiveUtils.sidebarMenuWidth - 32, 40),
  );

  // The gradient covers only the interactive pill, not the outer padding.
  expect(
    tester.getSize(
      find.ancestor(
        of: buttonFinder,
        matching: find.byType(DecoratedBox),
      ).first,
    ),
    tester.getSize(buttonFinder),
    reason: 'the gradient pill hugs the button and excludes the padding',
  );

  final icon = tester.widget<SvgPicture>(find.byType(SvgPicture));
  expect(
    icon.colorFilter,
    button.style?.foregroundColor?.resolve({})?.asFilter(),
  );
  expect(tester.getSize(find.byType(SvgPicture)), const Size(12, 12));

  await tester.tap(buttonFinder);
  expect(composeCalls, 1);
}

Future<void> _testDefaultWidthUsesResolvedPadding(WidgetTester tester) async {
  const padding = EdgeInsetsDirectional.only(
    start: 12,
    end: 28,
    top: 16,
    bottom: 8,
  );

  await _pumpComposeButton(tester, padding: padding);

  expect(
    tester.getSize(find.byType(FilledButton)),
    const Size(ResponsiveUtils.sidebarMenuWidth - 40, 40),
  );
}

Future<void> _testKeepsDesignSystemColorInDarkMode(
  WidgetTester tester,
) async {
  await _pumpComposeButton(tester, brightness: Brightness.dark);

  final buttonFinder = find.byKey(
    const Key(UiKeys.composeEmailPrimaryAction),
  );
  final button = tester.widget<FilledButton>(buttonFinder);
  final expectedStyle = LinagoraSidebarButtonStyles.primaryAction(
    tester.element(buttonFinder),
  );

  expect(
    button.style?.backgroundColor?.resolve({}),
    expectedStyle.backgroundColor?.resolve({}),
  );
}

Future<void> _testClampsDefaultWidthWithOversizedPadding(
  WidgetTester tester,
) async {
  const padding = EdgeInsetsDirectional.only(
    start: ResponsiveUtils.sidebarMenuWidth,
    end: 1,
  );

  await _pumpComposeButton(tester, padding: padding);

  expect(
    tester.widget<LinagoraSidebarPrimaryAction>(
      find.byType(LinagoraSidebarPrimaryAction),
    ).width,
    0,
  );
}

Future<void> _pumpComposeButton(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  EdgeInsetsGeometry? padding,
  VoidCallback? onTapAction,
}) async {
  await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Theme(
        data: ThemeUtils.buildAppTheme(context).copyWith(
          brightness: brightness,
          visualDensity: VisualDensity.compact,
        ),
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
        body: ComposeButtonWidget(
          imagePaths: ImagePaths(),
          onTapAction: onTapAction ?? () {},
          padding: padding,
        ),
      ),
    ));
  await tester.pump();
}
