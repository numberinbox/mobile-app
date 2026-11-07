import 'package:core/presentation/extensions/color_extension.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/views/toast/tmail_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';

class MockResponsiveUtils extends Mock implements ResponsiveUtils {
  @override
  double getMaxWidthToast(BuildContext context) => 300;
}

class ToastAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M2 12L9 19L22 3" stroke="white"/></svg>',
      ),
    ),
  );
}

void main() {
  group('success toast branding', () {
    late BuildContext toastContext;
    final appToast = AppToast();
    final toastFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(10),
    );

    setUp(() {
      Get.put<ResponsiveUtils>(MockResponsiveUtils());
      Get.put<ImagePaths>(ImagePaths());
    });
    tearDown(() async {
      await ToastView.dismiss();
      Get.reset();
    });

    Future<void> mount(WidgetTester tester) => tester.pumpWidget(
      DefaultAssetBundle(
        bundle: ToastAssetBundle(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                toastContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    testWidgets(
      'success paints shared gradient with white content and existing geometry',
      (tester) async {
        await mount(tester);
        appToast.showToastSuccessMessage(toastContext, 'Saved');
        await tester.pump();
        final container = tester.widget<Container>(toastFinder);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, NumberInboxPalette.primaryActionGradient);
        expect(decoration.color, isNull);
        expect(
          container.padding,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
        expect(container.constraints?.maxWidth, 300);
        expect(
          tester.widget<Text>(find.text('Saved')).style?.color,
          Colors.white,
        );
        expect(
          tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
        final positioned = tester.widget<Positioned>(
          find
              .ancestor(of: toastFinder, matching: find.byType(Positioned))
              .first,
        );
        expect(positioned.bottom, 80);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Saved'), findsNothing);
      },
    );
    testWidgets('solid, warning and error callers retain their backgrounds', (
      tester,
    ) async {
      await mount(tester);
      for (final entry in <(VoidCallback, Color)>[
        (
          () => appToast.showToastErrorMessage(toastContext, 'Error'),
          AppColor.toastErrorBackgroundColor,
        ),
        (
          () => appToast.showToastWarningMessage(toastContext, 'Warning'),
          AppColor.toastWarningBackgroundColor,
        ),
        (
          () => appToast.showToastMessage(
            toastContext,
            'Custom',
            backgroundColor: Colors.purple,
          ),
          Colors.purple,
        ),
        (
          () => appToast.showToastMessage(toastContext, 'Default'),
          Colors.white,
        ),
      ]) {
        entry.$1();
        await tester.pump();
        final decoration =
            tester.widget<Container>(toastFinder).decoration as BoxDecoration;
        expect(decoration.gradient, isNull);
        expect(decoration.color, entry.$2);
        await tester.pump(const Duration(seconds: 3));
      }
    });

    testWidgets(
      'gradient wins over color; Undo responds once to keyboard activation',
      (tester) async {
        await mount(tester);
        var calls = 0;
        appToast.showToastMessage(
          toastContext,
          'Moved',
          backgroundColor: Colors.red,
          backgroundGradient: NumberInboxPalette.primaryActionGradient,
          textColor: Colors.white,
          actionName: 'Undo',
          onActionClick: () => calls++,
        );
        await tester.pump();
        final decoration =
            tester.widget<Container>(toastFinder).decoration as BoxDecoration;
        expect(decoration.gradient, NumberInboxPalette.primaryActionGradient);
        expect(decoration.color, isNull);
        expect(
          tester.widget<Text>(find.text('Undo')).style?.color,
          Colors.white,
        );
        Focus.of(tester.element(find.text('Undo'))).requestFocus();
        await tester.pump();
        expect(Focus.of(tester.element(find.text('Undo'))).hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 1);
        expect(find.text('Moved'), findsNothing);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'multiple-action gradient keeps pointer callbacks and explicit dismissal',
      (tester) async {
        await mount(tester);
        var calls = 0;
        appToast.showToastMessageWithMultipleActions(
          toastContext,
          'Draft saved',
          backgroundGradient: NumberInboxPalette.primaryActionGradient,
          textColor: Colors.white,
          infinityToast: true,
          actions: [
            (
              actionName: 'Discard',
              onActionClick: () => calls++,
              actionIcon: null,
            ),
          ],
        );
        await tester.pump();
        expect(
          (tester.widget<Container>(toastFinder).decoration as BoxDecoration)
              .gradient,
          NumberInboxPalette.primaryActionGradient,
        );
        await tester.tap(find.text('Discard'));
        await tester.pump();
        expect(calls, 1);
        expect(find.text('Draft saved'), findsNothing);
        appToast.showToastMessage(toastContext, 'Another', infinityToast: true);
        await tester.pump();
        await ToastView.dismiss();
        await tester.pump();
        expect(find.text('Another'), findsNothing);
      },
    );

    for (final width in [320.0, 900.0]) {
      testWidgets('long RTL toast fits at width $width and large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester);
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: ToastAssetBundle(),
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    toastContext = context;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        appToast.showToastSuccessMessage(
          toastContext,
          'تم حفظ الرسالة بنجاح. This longer message should wrap.',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final decoration =
            tester.widget<Container>(toastFinder).decoration as BoxDecoration;
        final gradient = decoration.gradient as LinearGradient;
        expect(
          gradient.begin.resolve(TextDirection.rtl),
          Alignment.centerRight,
        );
        expect(
          tester.getSize(toastFinder).width,
          lessThanOrEqualTo(width - 36),
        );
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('replacing a visible toast retains only the new message', (
      tester,
    ) async {
      await mount(tester);
      appToast.showToastMessage(toastContext, 'Old', infinityToast: true);
      await tester.pump();
      appToast.showToastSuccessMessage(toastContext, 'New');
      await tester.pump();
      expect(find.text('Old'), findsNothing);
      expect(find.text('New'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('AppToast - showToastMessageWithMultipleActions', () {
    late AppToast appToast;
    late MockResponsiveUtils mockResponsiveUtils;

    setUp(() {
      appToast = AppToast();
      mockResponsiveUtils = MockResponsiveUtils();
      Get.put<ResponsiveUtils>(mockResponsiveUtils);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('should show action button '
        'when actionName is provided and trigger callback when tapped', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        var callbackTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      appToast.showToastMessageWithMultipleActions(
                        context,
                        'Test message',
                        actions: [
                          (
                            actionName: 'Retry',
                            onActionClick: () {
                              callbackTriggered = true;
                            },
                            actionIcon: null,
                          ),
                        ],
                      );
                    },
                    child: const Text('Show toast'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show toast'));
        await tester.pump();

        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(callbackTriggered, true);
      });
    });
  });
}
