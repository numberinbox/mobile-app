import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

/// Drives the app on the device so the host can capture store screenshots.
///
/// This test runs *on* the device, so it cannot read the repository working
/// copy or launch host binaries. Screenshots are therefore taken by the host
/// (see `docs/store/screenshots/capture-ios.sh` and `capture-android.sh`) once
/// this test has driven the app into the target state. Test inputs arrive as
/// environment variables forwarded to the device test run; no credential file
/// is read from device-side code.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 5]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (tester.any(finder)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }
  return tester.any(finder);
}

String _requiredEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError(
      '$key is not set. Forward it to the device test run; see '
      'docs/store/screenshot-capture-plan.md.',
    );
  }
  return value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store capture: reviewer login and inbox', (tester) async {
    await runTmail();
    final l10n = AppLocalizations();

    final welcomeFinder = find.byType(TwakeWelcomeView);
    final dashboardFinder = find.byKey(const Key(UiKeys.composeEmailButton));
    final onWelcome =
        await _waitFor(tester, welcomeFinder, timeout: const Duration(seconds: 25));
    await _waitFor(tester, dashboardFinder, timeout: const Duration(seconds: 5));

    if (tester.any(dashboardFinder)) {
      // A session from earlier manual testing is still active: sign out first
      // so the reviewer account is the one captured.
      await tester.tap(find.byKey(const Key(UiKeys.mobileMailboxMenuButton)));
      await _pumpFrames(tester, 10);
      await tester.tap(find.byKey(const Key(UiKeys.userAvatar)));
      await _pumpFrames(tester, 10);
      final signOutFinder = find.text(l10n.sign_out);
      if (!tester.any(signOutFinder)) {
        await tester.scrollUntilVisible(signOutFinder, 300);
      }
      await tester.tap(signOutFinder);
      await _pumpFrames(tester, 10);
      await tester.tap(find.text(l10n.yesLogout));
      if (!await _waitFor(tester, welcomeFinder, timeout: const Duration(seconds: 20))) {
        fail('sign-out did not return to the welcome screen');
      }
    } else if (!onWelcome) {
      fail('neither the welcome screen nor the dashboard appeared');
    }

    final phone = _requiredEnv('STORE_CAPTURE_PHONE');
    final otp = _requiredEnv('STORE_CAPTURE_OTP');

    await tester.tap(find.byKey(const Key('otp_country_picker')));
    await _pumpFrames(tester, 15);
    await tester.enterText(find.byKey(const Key('country_search')), 'United States');
    await _pumpFrames(tester, 15);
    await tester.tap(find.byKey(const Key('country_US')));
    await _pumpFrames(tester, 15);

    await tester.tap(find.byKey(const Key('otp_phone_field')));
    await tester.enterText(find.byKey(const Key('otp_phone_field')), phone);
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('otp_send_cta')));

    if (!await _waitFor(tester, find.byKey(const Key('otp_code_field')),
        timeout: const Duration(seconds: 20))) {
      final detail = tester.any(find.byKey(const Key('otp_error')))
          ? tester.widget<Text>(find.byKey(const Key('otp_error'))).data
          : 'no code field and no otp_error';
      fail('verification code screen did not appear: $detail');
    }

    await tester.enterText(find.byKey(const Key('otp_code_field')), otp);
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('otp_verify_cta')));

    if (!await _waitFor(tester, dashboardFinder, timeout: const Duration(seconds: 45))) {
      final detail = tester.any(find.byKey(const Key('otp_error')))
          ? tester.widget<Text>(find.byKey(const Key('otp_error'))).data
          : 'no otp_error shown';
      fail('dashboard did not appear after verify: $detail');
    }

    // Settle before the host captures: app bars, the FAB animation and the
    // message list all need a few frames to reach their final state.
    await _pumpFrames(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });
}
