// Private CI supplies the disposable runtime inputs for this NumberInbox test.

import 'package:core/presentation/views/floating_button/scrolling_floating_button_animated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

void main() {
  patrolTest('opens the mailbox without a phone or OTP prompt', ($) async {
    // Native automation does not show the app on its own: the driver must
    // boot it explicitly. The boot resumes the stored session, so the mailbox
    // appears directly; a boot that instead lands back on the welcome fields
    // is exactly the regression this stage exists to catch.
    await runTmail();
    await $(find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    )).waitUntilVisible(timeout: const Duration(seconds: 30));

    // The welcome screen must not reappear on top of the resumed session. Its
    // fields are the unmistakable signal that the stored session was lost.
    expect($(#otp_phone_field), findsNothing);
    expect($(#otp_code_field), findsNothing);
    expect($(#otp_send_cta), findsNothing);
  });
}
