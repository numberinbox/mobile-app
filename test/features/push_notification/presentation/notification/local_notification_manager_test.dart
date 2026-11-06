import 'dart:convert';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:model/notification/notification_payload.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/local_notification_config.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/local_notification_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationManager.buildInboxStyleInformation', () {
    test('escapes an HTML payload in the title', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: '<img src=x onerror=alert(1)>',
      );

      expect(style.contentTitle, isNot(contains('<img')));
      expect(style.contentTitle, contains('&lt;img'));
    });

    test('escapes an HTML payload in the message', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        message: '<script>alert(1)</script>',
      );

      expect(style.lines.first, isNot(contains('<script>')));
      expect(style.lines.first, contains('&lt;script&gt;'));
    });

    test('shows the sender address before the unaltered display name', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress('IT department', 'attacker@evil.example'),
      );

      expect(style.summaryText, equals('<b>attacker@evil.example (IT department)</b>'));
    });

    test('keeps the sender address first with a long display name', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress(
          'IT Department - Password Reset Required For Your Account',
          'attacker@evil.example',
        ),
      );

      expect(
        style.summaryText,
        equals('<b>attacker@evil.example (IT Department - Password Reset Required For Your Account)</b>'),
      );
    });

    test('does not repeat a display name equal to the address', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress('bob@example.com', 'bob@example.com'),
      );

      expect(style.summaryText, equals('<b>bob@example.com</b>'));
    });

    test('shows the display name alone when there is no address', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress('Bob', null),
      );

      expect(style.summaryText, equals('<b>Bob</b>'));
    });

    test('shows the address alone when there is no display name', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress(null, 'bob@example.com'),
      );

      expect(style.summaryText, equals('<b>bob@example.com</b>'));
    });

    test('leaves the sender line empty without a sender', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
      );

      expect(style.summaryText, equals('<b></b>'));
    });

    test('escapes a spoofed display name', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
        emailAddress: EmailAddress('<img src=x onerror=alert(1)>', 'attacker@evil.example'),
      );

      expect(style.summaryText, isNot(contains('<img')));
      expect(style.summaryText, contains('&lt;img'));
    });

    test('escapes an ampersand in the title', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'R&D',
      );

      expect(style.contentTitle, equals('R&amp;D'));
    });

    test('gives an empty line without a message', () {
      final style = LocalNotificationManager.buildInboxStyleInformation(
        title: 'Subject',
      );

      expect(style.lines, equals(['']));
    });
  });

  group('LocalNotificationConfig.generateNotificationDetails', () {
    test('uses private lock-screen visibility on Android', () {
      expect(
        LocalNotificationConfig.instance.generateNotificationDetails().android?.visibility,
        NotificationVisibility.private,
      );
    });
  });

  group('LocalNotificationManager.showPushNotification', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('generic fallback uses fixed text, rich id and email tap payload with sound', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await LocalNotificationManager.instance.showGenericNewMailNotification(emailId: 'synthetic-e1');
        final args = calls.single.arguments as Map;
        expect(args['id'], 'synthetic-e1'.hashCode);
        expect(args['title'], 'NumberInbox');
        expect(args['body'], 'You have new mail');
        final android = args['platformSpecifics'] as Map;
        expect(android['silent'], isFalse);
        expect(NotificationPayload.fromJson(jsonDecode(args['payload'] as String) as Map<String, dynamic>).emailId?.id.value, 'synthetic-e1');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('cancelAll clears notifications and swallows platform errors', () async {
      await LocalNotificationManager.instance.cancelAll();
      expect(calls.single.method, 'cancelAll');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'failure'));
      await LocalNotificationManager.instance.cancelAll();
    });

    testWidgets('cancelAll has a deadline when the platform does not reply', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (_) => Completer<void>().future);
      var completed = false;
      final cleanup = LocalNotificationManager.instance.cancelAll().then((_) => completed = true);
      await tester.pump(const Duration(seconds: 2));
      await cleanup;
      expect(completed, isTrue);
    });

    test('recognized action responses reach the existing stream and unknown actions are ignored', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final manager = LocalNotificationManager.instance;
      final received = <NotificationResponse>[];
      final subscription = manager.localNotificationStream.listen(received.add);
      try {
        await manager.setUp(groupId: 'synthetic-group');
        for (final action in ['mark_read', 'archive', 'reply', 'delete']) {
          final completed = Completer<void>();
          ServicesBinding.instance.channelBuffers.push(
            channel.name, const StandardMethodCodec().encodeMethodCall(MethodCall('didReceiveNotificationResponse', {
              'notificationResponseType': NotificationResponseType.selectedNotificationAction.index,
              'id': 1, 'actionId': action,
              'payload': const NumberInboxNotificationTarget(accountId: 'a', emailId: 'e').encode(),
            })), (_) => completed.complete());
          await completed.future;
        }
        await pumpEventQueue();
        expect(received.map((response) => response.actionId), ['mark_read', 'archive', 'reply']);
      } finally { await subscription.cancel(); debugDefaultTargetPlatformOverride = null; }
    });

    test('group summary updates can be silent and have no sender image or actions', () async {
      await LocalNotificationManager.instance.groupPushNotificationOnAndroid(groupId: 'synthetic-group', countNotifications: 2, silent: true);
      final android = (calls.single.arguments as Map)['platformSpecifics'] as Map;
      expect(android['silent'], isTrue);
      expect(android['largeIcon'], isNull);
      expect(android['actions'], isNull);
    });

    test('posts an escaped, private notification', () async {
      await LocalNotificationManager.instance.showPushNotification(
        id: 'e1',
        title: 'R&D <b>',
        message: '<script>x</script>',
        emailAddress: EmailAddress('IT department', 'attacker@evil.example'),
      );

      final android = (calls.single.arguments as Map)['platformSpecifics'] as Map;
      final style = android['styleInformation'] as Map;
      expect(android['visibility'], NotificationVisibility.private.index);
      expect(style['contentTitle'], 'R&amp;D &lt;b&gt;');
      expect(style['lines'], ['<p style="color:#6D7885;">&lt;script&gt;x&lt;&#47;script&gt;</p>']);
      expect(style['summaryText'], '<b>attacker@evil.example (IT department)</b>');
    });
  });
}
