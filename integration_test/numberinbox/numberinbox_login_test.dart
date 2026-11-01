// Private CI supplies the disposable runtime inputs for this NumberInbox test.

import 'dart:convert';
import 'dart:io';

import 'package:core/presentation/views/floating_button/scrolling_floating_button_animated.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

const otpHelperUrl = String.fromEnvironment('OTP_HELPER_URL');
const testNumber = String.fromEnvironment('SMOKE_TEST_NUMBER');
const wrongCode = '000000';
const seededSubject = 'Smoke seeded message';

/// The app's copy for a request that never reached the backend.
const refusedCopy = 'Could not send code. Please try again.';

/// How often a refused OTP request is repeated before the stage fails.
const maxSendAttempts = 5;

/// Fetches the issued code from the loopback-only helper.
///
/// Any failure returns null rather than an exception string: a helper error
/// must never put an OTP record or a response body into a test log.
Future<String?> fetchOtp(String e164) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('$otpHelperUrl/otp?e164=${Uri.encodeComponent(e164)}'))
        .timeout(const Duration(seconds: 90));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    final code = body['code'];
    return code is String && RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Picks Thailand in the country bottom sheet.
///
/// The picker is a sheet with its own search field, not an editable control
/// on the welcome screen itself.
Future<void> selectThailand(PatrolTester $) async {
  // First interaction of the first stage: it may race a cold-boot app whose
  // welcome screen only lands after initialization. A cold disposable stack
  // must not flake the run on patrol's default 10s step timeout, so wait
  // generously before the first tap; later steps fast-follow and stay tight.
  await $(#otp_country_picker).waitUntilVisible(timeout: const Duration(seconds: 60));
  final thailand = find.descendant(
    of: find.byKey(const Key('otp_country_picker')),
    matching: find.text('+66'),
  );
  for (var attempt = 0; attempt < 3; attempt++) {
    await $(#otp_country_picker).tap();
    await $(#country_search).enterText('Thailand');
    await $(#country_TH).tap();
    try {
      await $(thailand).waitUntilVisible(timeout: const Duration(seconds: 10));
      return;
    } catch (_) {
      // The sheet was dismissed without selecting: the tap missed the row
      // while the sheet was still settling.
    }
  }
  fail('could not select Thailand in the country picker');
}

/// Waits for the OTP code screen, retrying a refused request.
///
/// The emulator's route to the host (10.0.2.2) intermittently refuses
/// connections while the machine is under load, and the app reports that as
/// "Could not send code. Please try again." Repeating the request is safe -
/// it issues a fresh code - so a refused transport is retried. Every other
/// error (a number that is invalid for the selected country, a rate limit) is
/// a real failure and is reported as is.
Future<void> waitForOtpCodeScreen(PatrolTester $, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  var attempts = 0;
  var lastError = '';
  while (DateTime.now().isBefore(deadline)) {
    if (find.byKey(const Key('otp_code_field')).evaluate().isNotEmpty) return;
    if (find.byKey(const Key('otp_error')).evaluate().isNotEmpty) {
      lastError = otpErrorText($);
      final refused = lastError.isEmpty || lastError == refusedCopy;
      if (!refused || attempts >= maxSendAttempts) {
        fail('the OTP request was refused');
      }
      attempts++;
      // The transport recovers after a few seconds, so the resend is spaced
      // out instead of burning every attempt inside the same stall.
      await Future<void>.delayed(const Duration(seconds: 3));
      await $(#otp_send_cta).tap();
      continue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('the OTP code screen did not appear within ${timeout.inSeconds}s');
}

/// The visible error copy, or an empty string when it carries none.
String otpErrorText(PatrolTester $) => $.tester
    .widgetList<Text>(find.byKey(const Key('otp_error')))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join(' ')
    .trim();

void main() {
  patrolTest('signs in with a real OTP and uses the mailbox', ($) async {
    // Native automation does not show the app on its own: the driver must
    // boot it explicitly, otherwise the tree stays empty and every selector
    // times out. runTmail() mounts /twake_welcome within ~15s on this build.
    await runTmail();
    await selectThailand($);

    await $(#otp_phone_field).enterText(testNumber.replaceFirst('+66', '0'));
    await $(#otp_send_cta).tap();
    // The code step replaces the phone step once the backend answers. Wait for
    // it explicitly: on a freshly installed app the first request can take
    // longer than the implicit visibility window, which made enterText fail
    // with a bare "0 widgets" timeout instead of a useful message.
    await waitForOtpCodeScreen($, const Duration(seconds: 60));

    // A wrong code must surface a visible error and must not sign anyone in.
    await $(#otp_code_field).enterText(wrongCode);
    await $(#otp_verify_cta).tap();
    await $(#otp_error).waitUntilVisible(timeout: const Duration(seconds: 30));

    final code = await fetchOtp(testNumber);
    expect(code, isNotNull, reason: 'the disposable backend never issued a code');

    await $(#otp_code_field).enterText(code!);
    await $(#otp_verify_cta).tap();
    await $.pumpAndSettle(duration: const Duration(seconds: 5));

    // Inbox readiness, then the seeded inbound message. The mobile dashboard
    // renders ThreadView, whose compose FAB carries this key.
    // Post-login mailbox readiness: the JMAP session fetch plus the mailbox
    // sync legitimately run longer than patrol's default timing on a cold
    // backend, and the compose FAB sits under the mailbox loading overlay
    // until those finish (found in the tree, not yet hit-testable).
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).waitUntilVisible(timeout: const Duration(seconds: 90));

    final seeded = find.textContaining(seededSubject);
    await $(seeded).waitUntilVisible(timeout: const Duration(seconds: 60));
    await $(seeded).tap();
    await $.pumpAndSettle();

    // The message body renders inside the HtmlContentViewer platform view
    // (an Android WebView), so its text is not in the Flutter widget tree and
    // no widget finder can reach it. Prove the reader opened on THIS message
    // through controls and header text that do live in the widget tree: the
    // reader's own back control and the subject header.
    await $(#email_reader_back_button).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    await $(find.textContaining(seededSubject)).waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    // Leave the reader through the real reader-back control that mobile M2
    // publishes. The previous driver tapped #closeComposerButton to get back
    // to the inbox, but that is a composer-only control and does not exist on
    // the reader route at all, so the smoke could never leave the reader and
    // every later step was dead. M2 has landed (UiKeys.emailReaderBackButton
    // ships in the app), so this selector resolves against a current checkout.
    await $(#email_reader_back_button).tap();
    await $.pumpAndSettle();

    // Back at the inbox: the compose FAB is the inbox-readiness signal.
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).waitUntilVisible(timeout: const Duration(seconds: 30));

    // Composing reuses the issued session; it must not ask for a second OTP.
    // This smoke proves composer access and its send control; inherited
    // regression scenarios cover the complete send interaction separately.
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).tap();
    await $.pumpAndSettle();
    expect($(#sendEmailButton), findsOneWidget);
    expect($(#closeComposerButton), findsOneWidget);
    await $(#closeComposerButton).tap();
    await $.pumpAndSettle();
    expect($(#otp_phone_field), findsNothing);
    expect($(#otp_code_field), findsNothing);
    expect($(#otp_verify_cta), findsNothing);
  });
}
