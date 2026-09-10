import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:model/email/prefix_email_address.dart';
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
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(
        body: RecipientComposerWidget(
          prefix: prefix,
          listEmailAddress: const [],
          imagePaths: ImagePaths(),
          maxWidth: 400,
          toState: toState,
          ccState: ccState,
          bccState: bccState,
          onOpenContactPickerAction: onOpenContactPickerAction,
        ),
      ),
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
}
