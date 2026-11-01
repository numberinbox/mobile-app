// Private CI supplies the disposable runtime inputs for this NumberInbox test.

import 'dart:convert';
import 'dart:io';

import 'package:core/presentation/views/floating_button/scrolling_floating_button_animated.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

const otpHelperUrl = String.fromEnvironment('OTP_HELPER_URL');
const testNumber = String.fromEnvironment('SMOKE_TEST_NUMBER');

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
/// The sheet is a draggable sheet over a filtering list, so the tap can land
/// on the scrim while the sheet is still settling and dismiss it without
/// selecting anything. The app then validates the number against the
/// device-locale country (the emulator runs en-US) and never sends an OTP, so
/// the selection is verified against the picker's own dial code and retried.
///
/// After a deletion the app keeps the progress indicator of the deletion page
/// animating under the sign-in route, so "no scheduled frames" is never true
/// again and pumpAndSettle would time out. Verifying the dial code needs no
/// settling.
Future<void> selectThailand(PatrolTester $) async {
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
      // The sheet was dismissed without selecting: the tap missed the row.
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

/// Signs in with the number this stage's helper is serving.
Future<void> signIn(PatrolTester $, String e164) async {
  await selectThailand($);

  await $(#otp_phone_field).enterText(e164.replaceFirst('+66', '0'));
  await $(#otp_send_cta).tap();
  await waitForOtpCodeScreen($, const Duration(seconds: 60));

  final code = await fetchOtp(e164);
  expect(code, isNotNull, reason: 'the disposable backend never issued a code');

  await $(#otp_code_field).enterText(code!);
  await $(#otp_verify_cta).tap();
  await $(#mobileMailboxMenuButton).waitUntilVisible(timeout: const Duration(seconds: 60));
}

void main() {
  patrolTest('deletes the account and the next mailbox starts empty', ($) async {
    // Native automation does not show the app on its own: the driver must
    // boot it explicitly, otherwise the tree stays empty and every selector
    // times out. Stage three cleared app data, so the boot lands on welcome.
    await runTmail();
    await signIn($, testNumber);

    // A fresh, disposable account: this one has one message, delivered by the
    // runner immediately before this stage.
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(find.textContaining(seededSubject))
        .waitUntilVisible(timeout: const Duration(seconds: 60));

    // On mobile the avatar lives in the mailbox drawer's app bar, not on the
    // thread list screen, so open the drawer through its own control first.
    await $(#mobileMailboxMenuButton).tap();
    await $.pumpAndSettle();

    // Deletion runs through settings and must be confirmed. The page takes the
    // full E.164, so the country dropdown is deliberately left alone.
    await $(#userAvatar).tap();
    await $.pumpAndSettle();
    await $(#setting_delete_account).scrollTo();
    await $(#setting_delete_account).tap();
    await $.pumpAndSettle();

    await $(#deletion_phone_field).enterText(testNumber);
    await $(#deletion_submit).tap();
    await $.pumpAndSettle();
    await $(find.text('Delete permanently')).tap();

    // A pending or retryable deletion must not be read as completion, so this
    // waits for the phone screen itself rather than for an absence of widgets.
    await $(#otp_phone_field).waitUntilVisible(timeout: const Duration(seconds: 180));

    // Signing back in must issue a NEW code and yield a NEW mailbox.
    await signIn($, testNumber);
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).waitUntilVisible(timeout: const Duration(seconds: 30));

    // Wait for the freshly created mailbox to finish loading before asserting
    // absence: an empty-state widget proves the list resolved, so the missing
    // message is a real result and not a list that never arrived.
    await $(find.byKey(const Key(UiKeys.emptyThreadView))).waitUntilVisible(
      timeout: const Duration(seconds: 60),
    );

    expect(find.textContaining(seededSubject), findsNothing,
        reason: 'a recreated mailbox must not show earlier mail');
  });
}
