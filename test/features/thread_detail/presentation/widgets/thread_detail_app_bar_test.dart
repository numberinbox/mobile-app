// Tests for the real mail-reader back control (M2 release-gate ticket):
// the Android phone thread-detail route must expose `UiKeys.emailReaderBackButton`
// as the ONLY reader navigation selector so the platform smoke can open and
// leave a real reader without borrowing the composer close key.
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/email/presentation/widgets/email_view_back_button.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/widgets/thread_detail_app_bar.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

Widget _phoneApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: LocalizationService.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: child,
      ),
      body: const SizedBox.expand(),
    ),
  );
}

Future<void> _pumpPhoneViewport(WidgetTester tester, Widget child) async {
  // Pixel-like phone portrait: logical width < minTabletWidth (600).
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = const Size(1080, 2340);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_phoneApp(child));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('thread detail reader back (M2)', () {
    testWidgets(
        'WHEN the Android mail-reader is opened\n'
        'THEN exactly one emailReaderBackButton selector controls returning '
        'to the mailbox view', (tester) async {
      var backTaps = 0;
      await _pumpPhoneViewport(
        tester,
        ThreadDetailAppBar(
          responsiveUtils: ResponsiveUtils(),
          imagePaths: ImagePaths(),
          isSearchRunning: false,
          closeThreadDetailAction: () => backTaps++,
          threadActionReady: true,
          threadDetailIsStarred: false,
          isThreadDetailEnabled: true,
          threadDetailCanPermanentlyDelete: false,
          backButtonLabel: 'INBOX',
        ),
      );

      final back = find.byKey(const Key(UiKeys.emailReaderBackButton));
      expect(back, findsOneWidget,
          reason: 'the platform smoke keys the reader back by this selector');

      // The composer close selector must not be reused for reader navigation.
      expect(find.byKey(const Key(UiKeys.closeComposerButton)), findsNothing,
          reason: 'closeComposerButton must stay composer-only');

      await tester.tap(back);
      await tester.pump();
      expect(backTaps, 1,
          reason: 'tapping the reader back navigates out of the reader');
    });

    testWidgets(
        'WHEN the search-filtered reader view is shown\n'
        'THEN the same emailReaderBackButton selector is the back control',
        (tester) async {
      var backTaps = 0;
      await _pumpPhoneViewport(
        tester,
        ThreadDetailAppBar(
          responsiveUtils: ResponsiveUtils(),
          imagePaths: ImagePaths(),
          isSearchRunning: true,
          closeThreadDetailAction: () => backTaps++,
          threadActionReady: true,
          threadDetailIsStarred: false,
          isThreadDetailEnabled: true,
          threadDetailCanPermanentlyDelete: false,
          backButtonLabel: 'SEARCH RESULTS',
        ),
      );

      final back = find.byKey(const Key(UiKeys.emailReaderBackButton));
      expect(back, findsOneWidget,
          reason: 'reader-back coverage must include the thread reader route');

      await tester.tap(back);
      await tester.pump();
      expect(backTaps, 1);
    });

    testWidgets(
        'WHEN the phone email-view reader (non-thread route) is opened\n'
        'THEN its back control also carries emailReaderBackButton',
        (tester) async {
      var backTaps = 0;
      await _pumpPhoneViewport(
        tester,
        EmailViewBackButton(
          imagePaths: ImagePaths(),
          onBackAction: () => backTaps++,
          isSearchActivated: false,
          maxWidth: 300,
          backButtonLabel: 'INBOX',
        ),
      );

      final back = find.byKey(const Key(UiKeys.emailReaderBackButton));
      expect(back, findsOneWidget,
          reason: 'every phone reader route needs the same selector');

      await tester.tap(back);
      await tester.pump();
      expect(backTaps, 1);
    });

    testWidgets(
        'WHEN the composer is opened on the phone\n'
        'THEN open/close/send keys stay intact for the platform smoke',
        (tester) async {
      expect(UiKeys.composeEmailButton, 'composeEmailButton');
      expect(UiKeys.closeComposerButton, 'closeComposerButton');
      expect(UiKeys.sendEmailButton, 'sendEmailButton');
      // Reader navigation must remain distinct from composer close.
      expect(UiKeys.emailReaderBackButton, isNot(equals(UiKeys.closeComposerButton)));
    });
  });
}
