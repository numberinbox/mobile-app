import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/main/utils/ios_notification_manager.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('notification_interaction_channel');
  test(
    'old iOS reply actions are refused',
    () async {
      final manager = IOSNotificationManager();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'get_pending_numberinbox_notification_action') {
              return {
                'niVersion': 1,
                'niAccountId': 'account',
                'emailId': 'email',
                'actionId': 'reply',
              };
            }
            return null;
          });
      manager.listenClickNotification();
      await pumpEventQueue();
      final response = manager.pendingNumberInboxResponse.value;
      expect(response, isNull);
      manager.clearPendingNumberInboxResponse();
      expect(manager.pendingNumberInboxResponse.value, isNull);
      manager.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test(
    'body taps remain buffered until session ready',
    () async {
      final manager = IOSNotificationManager();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'get_pending_numberinbox_notification_action') {
              return {
                'niVersion': 1,
                'niAccountId': 'account',
                'emailId': 'email',
                'actionId': '',
              };
            }
            return null;
          });
      manager.listenClickNotification();
      await pumpEventQueue();
      final response = manager.pendingNumberInboxResponse.value;
      expect(response?.notificationResponseType, NotificationResponseType.selectedNotification);
      expect(NumberInboxNotificationTarget.decode(response?.payload)?.accountId, 'account');
      manager.clearPendingNumberInboxResponse();
      expect(manager.pendingNumberInboxResponse.value, isNull);
      manager.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('malformed native actions never become a body tap', () async {
    final manager = IOSNotificationManager();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'get_pending_numberinbox_notification_action'
              ? {
                  'niVersion': 1,
                  'niAccountId': 'account',
                  'emailId': 'email',
                  'actionId': 'delete',
                }
              : null,
        );
    manager.listenClickNotification();
    await pumpEventQueue();
    expect(manager.pendingNumberInboxResponse.value, isNull);
    manager.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
