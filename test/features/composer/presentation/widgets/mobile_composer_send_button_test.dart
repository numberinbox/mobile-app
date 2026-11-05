import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/mobile/app_bar_composer_widget.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/mobile/landscape_app_bar_composer_widget.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/mobile/tablet_bottom_bar_composer_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/web/mobile_responsive_app_bar_composer_widget.dart';

void main() {
  final imagePaths = ImagePaths();
  final send = find.byKey(const ValueKey(UiKeys.sendEmailButton));
  final gradient = find.byWidgetPredicate((widget) {
    final decoration = switch (widget) {
      Ink() => widget.decoration,
      DecoratedBox() => widget.decoration,
      _ => null,
    };
    return decoration is BoxDecoration &&
        decoration.gradient == NumberInboxPalette.primaryActionGradient;
  });

  Future<void> pumpBar(WidgetTester tester, Widget bar, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProviderScope(
          child: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: bar),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final landscape in [false, true]) {
    final layout = landscape ? 'landscape' : 'portrait';
    Widget phoneBar(bool enabled, VoidCallback onSend) => landscape
        ? LandscapeAppBarComposerWidget(
            imagePaths: imagePaths,
            isSendButtonEnabled: enabled,
            onCloseViewAction: () {},
            sendMessageAction: onSend,
            openContextMenuAction: (_) {},
            openRichToolbarAction: () {},
          )
        : AppBarComposerWidget(
            imagePaths: imagePaths,
            isSendButtonEnabled: enabled,
            onCloseViewAction: () {},
            sendMessageAction: onSend,
            openContextMenuAction: (_) {},
            openRichToolbarAction: () {},
          );
    final size = landscape ? const Size(640, 320) : const Size(320, 640);

    for (final enabled in [true, false]) {
      testWidgets('$layout Send preserves behavior when enabled=$enabled', (
        tester,
      ) async {
        var taps = 0;
        await pumpBar(tester, phoneBar(enabled, () => taps++), size);

        expect(
          find.descendant(of: send, matching: find.byTooltip('Send')),
          findsOneWidget,
        );
        expect(tester.getSize(send), const Size(36, 36));
        final icon = tester.widget<SvgPicture>(
          find.descendant(of: send, matching: find.byType(SvgPicture)),
        );
        final fill = find.descendant(of: send, matching: gradient);
        if (enabled) {
          expect(fill, findsOneWidget);
          expect(tester.getSize(fill), const Size(27, 27));
          expect(
            icon.colorFilter,
            const ColorFilter.mode(
              NumberInboxPalette.primaryActionForeground,
              BlendMode.srcIn,
            ),
          );
        } else {
          expect(fill, findsNothing);
          expect(
            (icon.bytesLoader as SvgAssetLoader).assetName,
            imagePaths.icSendDisable,
          );
        }
        await tester.tap(send);
        expect(taps, 1);
      });
    }
  }

  for (final enabled in [false, true]) {
    testWidgets('responsive web Send shares the primary treatment ($enabled)', (
      tester,
    ) async {
      var taps = 0;
      final menu = CustomPopupMenuController();
      addTearDown(menu.dispose);
      await pumpBar(
        tester,
        MobileResponsiveAppBarComposerWidget(
          imagePaths: imagePaths,
          isCodeViewEnabled: false,
          isFormattingOptionsEnabled: false,
          isSendButtonEnabled: enabled,
          hasRequestReadReceipt: false,
          isMarkAsImportant: false,
          isEmailChanged: false,
          menuMoreOptionController: menu,
          openRichToolbarAction: () {},
          onCloseViewAction: () {},
          attachFileAction: () {},
          insertImageAction: () {},
          sendMessageAction: () => taps++,
          toggleCodeViewAction: () {},
          toggleRequestReadReceiptAction: () {},
          printDraftAction: () {},
          saveToDraftsAction: () {},
          saveToTemplateAction: () {},
          deleteComposerAction: () {},
          toggleMarkAsImportantAction: () {},
        ),
        const Size(480, 640),
      );
      expect(
        find.descendant(of: send, matching: gradient),
        enabled ? findsOneWidget : findsNothing,
      );
      expect(tester.getSize(send), const Size(36, 36));
      await tester.tap(send);
      expect(taps, 1);
    });
  }

  testWidgets('tablet Send uses the gradient and invokes Send once', (
    tester,
  ) async {
    var taps = 0;
    await pumpBar(
      tester,
      TabletBottomBarComposerWidget(
        imagePaths: imagePaths,
        hasReadReceipt: false,
        isMarkAsImportant: false,
        deleteComposerAction: () {},
        saveToDraftAction: () {},
        sendMessageAction: () => taps++,
        requestReadReceiptAction: () {},
        toggleMarkAsImportantAction: () {},
      ),
      const Size(1024, 768),
    );

    expect(find.descendant(of: send, matching: gradient), findsOneWidget);
    final label = tester.widget<Text>(
      find.descendant(of: send, matching: find.text('Send')),
    );
    expect(label.style?.color, NumberInboxPalette.primaryActionForeground);
    await tester.tap(send);
    expect(taps, 1);
  });
}
