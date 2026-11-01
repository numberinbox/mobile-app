// Private CI supplies the disposable runtime inputs for this NumberInbox test.

import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/views/floating_button/scrolling_floating_button_animated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model/email/prefix_email_address.dart';
import 'package:patrol/patrol.dart';
import 'package:tmail_ui_user/features/composer/presentation/composer_view.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/recipient_tag_item_widget.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

import '../robots/composer_recipient_robot.dart';
import '../robots/composer_robot.dart';
import '../robots/thread_robot.dart';

const testNumber = String.fromEnvironment('SMOKE_TEST_NUMBER');
const subject = 'Phone recipient smoke';

void main() {
  patrolTest('a phone number becomes a NumberInbox recipient and sends', ($) async {
    // Runs on the session the relaunch stage preserved: the boot resumes the
    // mailbox directly, so no phone or OTP prompt is involved here.
    await runTmail();
    final composeButton = find.byWidgetPredicate(
      (w) => w is ScrollingFloatingButtonAnimated,
      description: 'scrolling compose button',
    );
    await $(composeButton).waitUntilVisible(timeout: const Duration(seconds: 60));

    await ThreadRobot($).openComposer();
    await $(ComposerView).waitUntilVisible(timeout: const Duration(seconds: 30));

    final composer = ComposerRobot($);
    await composer.grantContactPermission();

    // A full international number resolves without asking for a country; a
    // local-format number would open the country picker instead. The chip must
    // carry the canonical address, not the raw digits.
    await ComposerRecipientRobot($).enterRecipient(PrefixEmailAddress.to, testNumber);
    const resolved = '$testNumber@numberinbox.com';
    await $(RecipientTagItemWidget)
        .which<RecipientTagItemWidget>(
          (chip) => chip.currentEmailAddress.email == resolved,
        )
        .waitUntilVisible(timeout: const Duration(seconds: 15));

    await composer.addSubject(subject);
    await composer.sendEmail(ImagePaths());
    await $.pumpAndSettle();

    // The disposable stack only hosts numberinbox.test, so the message cannot
    // land in this mailbox: the proof is that the composer accepted the
    // recipient and closed back to the inbox with no unresolved-number prompt.
    await $(composeButton).waitUntilVisible(timeout: const Duration(seconds: 60));
    expect($(ComposerView), findsNothing);
    expect($(#country_search), findsNothing);
  });
}
