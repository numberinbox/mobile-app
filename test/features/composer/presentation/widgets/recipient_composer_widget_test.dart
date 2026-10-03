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
import 'package:tmail_ui_user/features/composer/presentation/model/suggestion_email_address.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/recipient_composer_widget.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/recipient_suggestion_item_widget.dart';
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
    OnUpdateListEmailAddressAction? onUpdateListEmailAddressAction,
    OnSuggestionEmailAddress? onSuggestionEmailAddress,
    OnResolvePhoneRecipientAction? onResolvePhoneRecipientAction,
    TextEditingController? textController,
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
      onUpdateListEmailAddressAction: onUpdateListEmailAddressAction,
      onSuggestionEmailAddress: onSuggestionEmailAddress,
      onResolvePhoneRecipientAction: onResolvePhoneRecipientAction,
      controller: textController,
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

    testWidgets('unresolved and resolved chips keep actions clear',
        (tester) async {
      final recipients = [
        EmailAddress('Somluck', '029009119'),
        EmailAddress('Jamie', '+66812345678@numberinbox.com'),
      ];
      for (final width in [320.0, 360.0, 400.0]) {
        await pumpToRow(tester, width: width, recipients: recipients);
        expect(tester.takeException(), isNull,
            reason: 'overflow at width $width');
        final editor = tester.getRect(editorFinder());
        final actions = actionRowRect(tester);
        expect(editor.overlaps(actions), isFalse,
            reason: 'overlap at width $width');
        expect(actions.left - editor.right, greaterThanOrEqualTo(8),
            reason: 'gap at width $width');
      }
    });

    testWidgets('unresolved chip without a name shows the raw number',
        (tester) async {
      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress(null, '029009119'),
      ]);

      expect(find.text('029009119'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('named unresolved chip visibly contains the raw number',
        (tester) async {
      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress('Somluck', '029009119'),
      ]);

      expect(find.text('029009119'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('named unresolved chip exposes name and number for assistive tech',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress('Somluck', '029009119'),
      ]);

      // The avatar label merges into the same node, so match by pattern.
      expect(
        find.bySemanticsLabel(RegExp('Somluck, 029009119')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Disposed explicitly: end-of-test verifications run before teardowns.
      semanticsHandle.dispose();
    });

    testWidgets('resolved named chip keeps its normal label', (tester) async {
      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress('Somluck', '+6629009119@numberinbox.com'),
      ]);

      expect(find.text('Somluck'), findsOneWidget);
      expect(find.textContaining('+6629009119'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unresolved chips keep invalid styling', (tester) async {
      BoxDecoration? decorationOf(String labelKeyPrefix, int index) {
        final label = find.byKey(
          Key('label_recipient_tag_item_to_$index'),
        );
        final container = find.ancestor(
          of: label,
          matching: find.byKey(Key('recipient_tag_item_to_$index')),
        );
        final widget = tester.widget<Container>(container);
        return widget.decoration as BoxDecoration?;
      }

      await pumpToRow(tester, width: 400, recipients: [
        EmailAddress('Somluck', '029009119'),
        EmailAddress('Jamie', 'jamie@example.com'),
      ]);

      final unresolvedDecoration = decorationOf('label', 0);
      final validDecoration = decorationOf('label', 1);
      expect(unresolvedDecoration, isNotNull);
      expect(validDecoration, isNotNull);
      expect(
        unresolvedDecoration!.color,
        isNot(validDecoration!.color),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text with unresolved chips does not overflow',
        (tester) async {
      await pumpToRow(tester, width: 360, textScale: 2.0, recipients: [
        EmailAddress('Somluck', '029009119'),
        EmailAddress('Jamie', '+66812345678@numberinbox.com'),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('rtl with unresolved chips keeps actions separated',
        (tester) async {
      await pumpToRow(tester, width: 400, rtl: true, recipients: [
        EmailAddress('Somluck', '029009119'),
      ]);

      final editor = tester.getRect(editorFinder());
      final actions = actionRowRect(tester);
      expect(editor.overlaps(actions), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('RecipientComposerWidget phone entry', () {
    final resolveCalls = <String>[];
    var committed = <EmailAddress>[];
    final textController = TextEditingController();

    Future<void> pumpPhoneRow(
      WidgetTester tester, {
      required PrefixEmailAddress prefix,
      List<EmailAddress> suggestions = const [],
    }) async {
      resolveCalls.clear();
      committed = [];
      textController.clear();
      await pumpRow(
        tester,
        prefix: prefix,
        toState: PrefixRecipientState.enabled,
        ccState: PrefixRecipientState.enabled,
        bccState: PrefixRecipientState.enabled,
        textController: textController,
        onUpdateListEmailAddressAction: (p, values) =>
            committed = List.of(values),
        onSuggestionEmailAddress: (word, {limit}) async => suggestions,
        onResolvePhoneRecipientAction: (p, recipient) async {
          resolveCalls.add('${p.name}:${recipient.email}');
        },
      );
    }

    TagEditor<SuggestionEmailAddress> editorOf(WidgetTester tester) =>
        tester.widget<TagEditor<SuggestionEmailAddress>>(
          find.byWidgetPredicate((w) => w is TagEditor),
        );

    Future<void> typeQuery(WidgetTester tester, String text) async {
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.enterText(text);
      await tester.pumpAndSettle();
    }

    testWidgets('pointer selection of a raw suggestion requests a country',
        (tester) async {
      await pumpPhoneRow(
        tester,
        prefix: PrefixEmailAddress.to,
        suggestions: [EmailAddress('Somluck', '029009119')],
      );
      await typeQuery(tester, 'somluck');

      // Invoke the exact closure a pointer tap calls (the overlay item is
      // positioned off-surface in this bare test scaffold, so framework
      // hit-testing cannot reach it; the branch, commit, and reset/close
      // below are the genuine pointer path).
      final item = tester.widget<RecipientSuggestionItemWidget>(
        find.byType(RecipientSuggestionItemWidget),
      );
      item.onSelectedAction?.call(item.emailAddress);
      await tester.pumpAndSettle();

      expect(committed.map((e) => e.email), ['029009119']);
      expect(
        committed.singleWhere((e) => e.email == '029009119').name,
        'Somluck',
      );
      expect(resolveCalls, ['to:029009119']);
      expect(find.text('029009119'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final prefix in [
      PrefixEmailAddress.to,
      PrefixEmailAddress.cc,
      PrefixEmailAddress.bcc,
    ]) {
      testWidgets('keyboard selection requests a country for ${prefix.name}',
          (tester) async {
        await pumpPhoneRow(tester, prefix: prefix);

        editorOf(tester).onSelectOptionAction!(SuggestionEmailAddress(
          EmailAddress('Somluck', '029009119'),
          state: SuggestionEmailState.invalidPhone,
          rawPhone: '029009119',
        ));
        await tester.pumpAndSettle();

        expect(committed.map((e) => e.email), ['029009119']);
        expect(resolveCalls, ['${prefix.name}:029009119']);
        expect(find.text('029009119'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('submitted explicit international commits canonical silently',
        (tester) async {
      await pumpPhoneRow(tester, prefix: PrefixEmailAddress.to);

      editorOf(tester).onSubmitted!('+66 29 009 119');
      await tester.pumpAndSettle();

      expect(
        committed.map((e) => e.email),
        ['+6629009119@numberinbox.com'],
      );
      expect(resolveCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitted local number commits one raw and requests a country',
        (tester) async {
      await pumpPhoneRow(tester, prefix: PrefixEmailAddress.to);

      editorOf(tester).onSubmitted!('02 900 9119');
      await tester.pumpAndSettle();

      expect(committed.map((e) => e.email), ['02 900 9119']);
      expect(resolveCalls, ['to:02 900 9119']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitted ordinary email list commits without a prompt',
        (tester) async {
      await pumpPhoneRow(tester, prefix: PrefixEmailAddress.to);

      editorOf(tester).onSubmitted!('a@x.com, b@y.com');
      await tester.pumpAndSettle();

      expect(
        committed.map((e) => e.email),
        ['a@x.com', 'b@y.com'],
      );
      expect(resolveCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('repeated phone commits do not duplicate', (tester) async {
      await pumpPhoneRow(tester, prefix: PrefixEmailAddress.to);

      editorOf(tester).onSubmitted!('029009119');
      await tester.pump();
      editorOf(tester).onSubmitted!('029-009-119');
      await tester.pumpAndSettle();

      expect(committed, hasLength(1));
      expect(resolveCalls, ['to:029009119', 'to:029-009-119']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitted phone clears the editor text', (tester) async {
      await pumpPhoneRow(tester, prefix: PrefixEmailAddress.to);
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.enterText('02 900 9119');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
      expect(committed.map((e) => e.email), ['02 900 9119']);
      expect(resolveCalls, ['to:02 900 9119']);
      expect(tester.takeException(), isNull);
    });
  });
}
