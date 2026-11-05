import 'dart:ui' as ui;
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/views/button/icon_button_web.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:core/presentation/views/dialog/confirm_dialog_button.dart';
import 'package:core/presentation/views/dialog/color_picker_dialog_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fixtures/brand_widget_test_support.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'confirm gradient retains shape, foreground, keyboard and focus',
    (tester) async {
      var calls = 0;
      await pumpAction(
        tester,
        (_) => SizedBox(
          width: 160,
          height: 48,
          child: ConfirmDialogButton(
            label: 'Continue',
            radius: 12,
            backgroundGradient: NumberInboxPalette.primaryActionGradient,
            onTapAction: () => calls++,
          ),
        ),
      );
      expect(primaryFill, findsOneWidget);
      expect(tester.getSize(primaryFill), const Size(160, 48));
      final decoration =
          tester.widget<DecoratedBox>(primaryFill).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(
        tester.widget<Text>(find.text('Continue')).style?.color,
        Colors.white,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
      await tester.tap(find.text('Continue'));
      expect(calls, 2);
    },
  );

  for (final fixedWidth in [false, true]) {
    testWidgets('TMail preserves border geometry with fixedWidth=$fixedWidth', (
      tester,
    ) async {
      await pumpAction(
        tester,
        (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TMailButtonWidget.fromText(
              key: const Key('solid-bordered'),
              text: 'Solid',
              width: fixedWidth ? 160 : null,
              minWidth: fixedWidth ? 0 : 160,
              height: 48,
              padding: const EdgeInsets.all(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            TMailButtonWidget.fromText(
              key: const Key('gradient-bordered'),
              text: 'Gradient',
              width: fixedWidth ? 160 : null,
              minWidth: fixedWidth ? 0 : 160,
              height: 48,
              padding: const EdgeInsets.all(8),
              border: Border.all(color: Colors.black, width: 2),
              backgroundGradient: NumberInboxPalette.primaryActionGradient,
            ),
          ],
        ),
      );
      final solidButton = tester.getRect(
        find.byKey(const Key('solid-bordered')),
      );
      final gradientButton = tester.getRect(
        find.byKey(const Key('gradient-bordered')),
      );
      expect(gradientButton.size, solidButton.size);
      final solid = tester.getRect(find.text('Solid'));
      final gradient = tester.getRect(find.text('Gradient'));
      expect(gradient.size, solid.size);
      expect(
        gradient.topLeft - gradientButton.topLeft,
        solid.topLeft - solidButton.topLeft,
      );
    });
  }

  testWidgets('solid outlined and unavailable confirm styles keep precedence', (
    tester,
  ) async {
    await pumpAction(
      tester,
      (_) => const ConfirmDialogButton(
        label: 'Cancel',
        backgroundColor: Colors.grey,
        borderColor: Colors.red,
      ),
    );
    expect(primaryFill, findsNothing);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
    expect(button.style!.backgroundColor!.resolve({}), Colors.grey);
    final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(shape.side.color, Colors.red);
  });

  testWidgets('outlined gradient confirms paint a translucent border once', (
    tester,
  ) async {
    final key = GlobalKey();
    const border = Color(0x80FF0000);
    await pumpAction(
      tester,
      (_) => RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 160,
          height: 48,
          child: ConfirmDialogButton(
            label: 'Continue',
            radius: 0,
            borderColor: border,
            backgroundGradient: const LinearGradient(
              colors: [Colors.blue, Colors.blue],
            ),
            onTapAction: () {},
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    final expected = Color.alphaBlend(border, Colors.blue);
    final expectedChannels = [expected.r, expected.g, expected.b];
    for (var c = 0; c < 3; c++) {
      expect(
        pixels!.getUint8((20 * 160) * 4 + c),
        closeTo(expectedChannels[c] * 255, 2),
      );
    }
  });

  testWidgets('TMail paints the gradient without the legacy translucent tint', (
    tester,
  ) async {
    final key = GlobalKey();
    await pumpAction(
      tester,
      (_) => RepaintBoundary(
        key: key,
        child: TMailButtonWidget.fromText(
          text: 'Apply',
          backgroundColor: Colors.transparent,
          width: 160,
          height: 48,
          borderRadius: 10,
          backgroundGradient: NumberInboxPalette.primaryActionGradient,
          onTapActionCallback: () {},
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    final stops = NumberInboxPalette.primaryActionGradient.colors;
    for (final x in [40, 80, 120]) {
      final position = (x + 0.5) / 80;
      final segment = position < 1 ? 0 : 1;
      final expected = Color.lerp(
        stops[segment],
        stops[segment + 1],
        position - segment,
      )!;
      final actual = [
        for (var c = 0; c < 3; c++) pixels!.getUint8((8 * 160 + x) * 4 + c),
      ];
      final channels = [expected.r, expected.g, expected.b];
      for (var c = 0; c < 3; c++) {
        expect(
          actual[c],
          closeTo(channels[c] * 255, 2),
          reason: 'gradient channel $c at x=$x',
        );
      }
    }
  });

  testWidgets('TMail gradient retains tooltip, tap feedback and geometry', (
    tester,
  ) async {
    var taps = 0;
    await pumpAction(
      tester,
      (_) => TMailButtonWidget.fromText(
        text: 'Apply',
        width: 160,
        height: 48,
        borderRadius: 10,
        backgroundGradient: NumberInboxPalette.primaryActionGradient,
        tooltipMessage: 'Apply changes',
        onTapActionCallback: () => taps++,
      ),
    );
    expect(tester.getSize(primaryFill), const Size(160, 48));
    expect(find.byTooltip('Apply changes'), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Apply')),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(primaryFill, findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  for (final useWrap in [false, true]) {
    testWidgets(
      'legacy web helper gradient keeps keyboard and callback ($useWrap)',
      (tester) async {
        var taps = 0;
        await pumpAction(
          tester,
          (_) => useWrap
              ? buildButtonWrapText(
                  'Apply',
                  height: 40,
                  radius: 5,
                  backgroundGradient: NumberInboxPalette.primaryActionGradient,
                  onTap: () => taps++,
                )
              : buildTextButton(
                  'Apply',
                  width: 160,
                  height: 40,
                  radius: 5,
                  backgroundGradient: NumberInboxPalette.primaryActionGradient,
                  onTap: () => taps++,
                ),
        );
        expect(primaryFill, findsOneWidget);
        expect(tester.getSize(primaryFill).height, 40);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, 1);
      },
    );
  }

  testWidgets('color picker applies gradient only to its positive action', (
    tester,
  ) async {
    final current = ValueNotifier(Colors.black);
    addTearDown(current.dispose);
    var calls = 0;
    await pumpAction(
      tester,
      (_) => TextButton(
        onPressed: () {
          ColorPickerDialogBuilder(
            current,
            textActionSetColor: 'Apply',
            textActionCancel: 'Cancel',
            textActionResetDefault: 'Reset',
            setColorActionCallback: (_) => calls++,
          ).show();
        },
        child: const Text('Choose color'),
      ),
      size: const Size(1024, 900),
    );
    await tester.tap(find.text('Choose color'));
    await tester.pumpAndSettle();
    expect(primaryFill, findsOneWidget);
    expect(
      find.ancestor(of: find.text('Apply'), matching: primaryFill),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Cancel'), matching: primaryFill),
      findsNothing,
    );
    await tester.tap(find.text('Apply'));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
