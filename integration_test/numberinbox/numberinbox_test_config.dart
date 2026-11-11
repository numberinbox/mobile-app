import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart' show find;
import 'package:patrol/patrol.dart' show PatrolIntegrationTester, IOSSelector;
import 'package:patrol_finders/patrol_finders.dart' show PatrolTesterConfig;
import 'package:tmail_ui_user/main/main_entry.dart';

/// Patrol's defaults wait 10 seconds for a widget to appear or the frames to
/// settle. These tests drive a real backend on a shared CI runner, where a
/// response can take longer; a slow answer must not fail a step that is only
/// waiting for it. Failures that are real still end the test at this limit.
const slowStackConfig = PatrolTesterConfig(
  printLogs: true,
  existsTimeout: Duration(seconds: 60),
  visibleTimeout: Duration(seconds: 60),
  settleTimeout: Duration(seconds: 60),
);

/// Starts the app with an empty, initialized environment.
///
/// Live push is now started for these sessions, and its connection handler
/// reads the environment (WS_ECHO_PING). The real runner loads env.file first,
/// but these tests deliberately run with no configured server: SERVER_URL would
/// change the start screen away from the OTP welcome. An empty environment makes
/// every such read fall back to its default instead of throwing NotInitializedError.
Future<void> startNumberInbox() async {
  dotenv.testLoad(mergeWith: const <String, String>{});
  await runTmail();
}

/// Answers the Contacts permission prompt if one appears.
///
/// Patrol's grantPermissionWhenInUse only knows the "While Using App" button.
/// iOS words this prompt differently by release ("Allow Full Access" on iOS 18,
/// "Continue" and then a second choice on iOS 26), so on iOS the visible
/// affirmative button is tapped instead, up to three prompts in a row.
Future<void> allowContactsIfAsked(PatrolIntegrationTester $) async {
  final native = $.platformAutomator.mobile;
  const wait = Duration(seconds: 5);
  if (!await native.isPermissionDialogVisible(timeout: wait)) return;
  if (!Platform.isIOS) {
    await native.grantPermissionWhenInUse();
    return;
  }
  for (var step = 0; step < 3; step++) {
    var tapped = false;
    for (final label in const ['Allow Full Access', 'Continue', 'Allow']) {
      try {
        // Permission prompts belong to SpringBoard, not to the app under test.
        await $.platformAutomator.ios.tap(
          IOSSelector(text: label),
          appId: 'com.apple.springboard',
          timeout: const Duration(seconds: 3),
        );
        tapped = true;
        break;
      } catch (_) {
        // This button is not on screen; try the next wording.
      }
    }
    if (!tapped) return;
    if (!await native.isPermissionDialogVisible(
      timeout: const Duration(seconds: 2),
    )) {
      return;
    }
  }
}

/// Waits until the composer's HTML editor has been created and had time to start.
///
/// The editor is a webview created after the composer route opens. Closing the
/// composer while it is still starting can dispose its controller twice, which
/// the webview plugin reports as "used after being disposed" and which fails the
/// test although every step succeeded. The type is matched by name because the
/// plugin is not a direct dependency of the application.
Future<void> waitForComposerEditor(PatrolIntegrationTester $) async {
  await $(find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'InAppWebView',
    description: 'composer editor webview',
  )).waitUntilVisible(timeout: const Duration(seconds: 30));
  await $.pump(const Duration(seconds: 3));
  await $.pumpAndSettle();
}
