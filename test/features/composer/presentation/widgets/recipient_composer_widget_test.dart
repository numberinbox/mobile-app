import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/email/prefix_email_address.dart';
import 'package:super_tag_editor/tag_editor.dart';
import 'package:tmail_ui_user/features/composer/presentation/model/prefix_recipient_state.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/recipient_composer_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

class _FakeResponsiveUtils extends Fake implements ResponsiveUtils {
  @override
  bool isMobile(BuildContext context) => true;
}

void main() {
  late ResponsiveUtils responsiveUtils;

  setUp(() {
    Get.testMode = true;
    responsiveUtils = _FakeResponsiveUtils();
    Get.put<ResponsiveUtils>(responsiveUtils);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpRow(
    WidgetTester tester, {
    required PrefixEmailAddress prefix,
    PrefixRecipientState toState = PrefixRecipientState.disabled,
    PrefixRecipientState ccState = PrefixRecipientState.disabled,
    PrefixRecipientState bccState = PrefixRecipientState.disabled,
    OnOpenContactPickerAction? onOpenContactPickerAction,
    List<EmailAddress> recipients = const [],
    double? width,
    double textScale = 1.0,
    bool rtl = false,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue);
    Widget row = RecipientComposerWidget(
      prefix: prefix,
      listEmailAddress: recipients,
      imagePaths: ImagePaths(),
      maxWidth: width ?? 400,
      toState: toState,
      ccState: ccState,
      bccState: bccState,
      onOpenContactPickerAction: onOpenContactPickerAction,
    );
    if (width != null) {
      row = Center(child: SizedBox(width: width, child: row));
    }
    if (rtl) {
      row = Directionality(textDirection: TextDirection.rtl, child: row);
    }
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(body: row),
    ));
    await tester.pumpAndSettle();
  }

  group('RecipientComposerWidget contact button', () {
    testWidgets('To row shows contact button when To is enabled', (tester) async {
      await pumpRow(
        tester,
        prefix: PrefixEmailAddress.to,
        toState: PrefixRecipientState.enabled,
      );

      expect(
        find.byKey(const Key('prefix_to_recipient_contact_button')),
        findsOneWidget,
      );
    });

    testWidgets('CC row shows contact button when CC is enabled', (tester) async {
      await pumpRow(
        tester,
        prefix: PrefixEmailAddress.cc,
        toState: PrefixRecipientState.enabled,
        ccState: PrefixRecipientState.enabled,
      );

      expect(
        find.byKey(const Key('prefix_cc_recipient_contact_button')),
        findsOneWidget,
      );
    });

    testWidgets('BCC row shows contact button when BCC is enabled', (tester) async {
      await pumpRow(
        tester,
        prefix: PrefixEmailAddress.bcc,
        toState: PrefixRecipientState.enabled,
        bccState: PrefixRecipientState.enabled,
      );

      expect(
        find.byKey(const Key('prefix_bcc_recipient_contact_button')),
        findsOneWidget,
      );
    });

    testWidgets('disabled row shows no contact button', (tester) async {
      await pumpRow(
        tester,
        prefix: PrefixEmailAddress.cc,
        toState: PrefixRecipientState.enabled,
        ccState: PrefixRecipientState.disabled,
      );

      expect(
        find.byKey(const Key('prefix_cc_recipient_contact_button')),
        findsNothing,
      );
    });

    testWidgets('tapping contact button opens picker for that prefix', (tester) async {
      PrefixEmailAddress? openedFor;
      await pumpRow(
        tester,
        prefix: PrefixEmailAddress.cc,
        toState: PrefixRecipientState.enabled,
        ccState: PrefixRecipientState.enabled,
        onOpenContactPickerAction: (prefix) => openedFor = prefix,
      );

      await tester.tap(find.byKey(const Key('prefix_cc_recipient_contact_button')));
      await tester.pumpAndSettle();

      expect(openedFor, PrefixEmailAddress.cc);
    });
  });

  group('RecipientComposerWidget layout constraints', () {
    Finder editorFinder() => find.byWidgetPredicate((w) => w is TagEditor);

    Future<void> pumpToRow(
      WidgetTester tester, {
      List<EmailAddress> recipients = const [],
      double? width,
      double textScale = 1.0,
      bool rtl = false,
    }) =>
        pumpRow(
          tester,
          prefix: PrefixEmailAddress.to,
          toState: PrefixRecipientState.enabled,
          recipients: recipients,
          width: width,
          textScale: textScale,
          rtl: rtl,
        );

    Rect actionRowRect(WidgetTester tester) {
      final contact =
          tester.getRect(find.byKey(const Key('prefix_to_recipient_contact_button')));
      final expand =
          tester.getRect(find.byKey(const Key('prefix_to_recipient_expand_button')));
      final left = contact.left < expand.left ? contact.left : expand.left;
      final right =
          contact.right > expand.right ? contact.right : expand.right;
      final top = contact.top < expand.top ? contact.top : expand.top;
      final bottom =
          contact.bottom > expand.bottom ? contact.bottom : expand.bottom;
      return Rect.fromLTRB(left, top, right, bottom);
    }

    testWidgets('editor keeps 8px gap before the action row', (tester) async {
      await pumpToRow(tester, width: 400);

      final editor = tester.getRect(editorFinder());
      final actions = actionRowRect(tester);
      expect(actions.left - editor.right, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editor, chips and actions do not overlap', (tester) async {
      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress('Ms Somluck', 'ms.somluck@example.com'),
      ]);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final editor = tester.getRect(editorFinder());
      final actions = actionRowRect(tester);
      expect(editor.overlaps(actions), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('actions have 48x48 minimum tap targets', (tester) async {
      await pumpToRow(tester, width: 400);

      final contact = tester
          .getRect(find.byKey(const Key('prefix_to_recipient_contact_button')));
      final expand = tester
          .getRect(find.byKey(const Key('prefix_to_recipient_expand_button')));
      expect(contact.width, greaterThanOrEqualTo(48));
      expect(contact.height, greaterThanOrEqualTo(48));
      expect(expand.width, greaterThanOrEqualTo(48));
      expect(expand.height, greaterThanOrEqualTo(48));
    });

    testWidgets('chip appears after list update without extra taps',
        (tester) async {
      Future<void> pumpList(List<EmailAddress> recipients) =>
          tester.pumpWidget(MaterialApp(
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.supportedLocales,
            home: Scaffold(
              body: RecipientComposerWidget(
                prefix: PrefixEmailAddress.to,
                listEmailAddress: recipients,
                imagePaths: ImagePaths(),
                maxWidth: 400,
                toState: PrefixRecipientState.enabled,
              ),
            ),
          ));

      await pumpList(const []);
      await tester.pump();
      await pumpList([
        EmailAddress('Ms Somluck', 'ms.somluck@example.com'),
      ]);
      await tester.pump();

      expect(find.text('Ms Somluck'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow and tablet widths do not overflow', (tester) async {
      final recipients = [
        EmailAddress('Ms Somluck', 'ms.somluck@example.com'),
        EmailAddress('Karrakad', '+66842327391@numberinbox.com'),
        EmailAddress('Jamie', 'jamie@example.com'),
      ];
      for (final width in [320.0, 360.0, 400.0, 800.0]) {
        await pumpToRow(tester, width: width, recipients: recipients);
        expect(tester.takeException(), isNull,
            reason: 'overflow at width $width');
        final editor = tester.getRect(editorFinder());
        final actions = actionRowRect(tester);
        expect(actions.left - editor.right, greaterThanOrEqualTo(8),
            reason: 'gap at width $width');
      }
    });

    testWidgets('long names wrap without overflow', (tester) async {
      await pumpToRow(tester, width: 360, recipients: [
        EmailAddress(
          'A very long display name that should wrap or ellipsize gracefully',
          'very.long.address.that.keeps.going@example.com',
        ),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('large text scales without overflow', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await pumpToRow(
          tester,
          width: 360,
          textScale: scale,
          recipients: [
            EmailAddress('Ms Somluck', 'ms.somluck@example.com'),
          ],
        );
        expect(tester.takeException(), isNull,
            reason: 'overflow at text scale $scale');
      }
    });

    testWidgets('rtl keeps actions separated from the editor',
        (tester) async {
      await pumpToRow(tester, width: 400, rtl: true);

      final editor = tester.getRect(editorFinder());
      final actions = actionRowRect(tester);
      expect(editor.overlaps(actions), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
