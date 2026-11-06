import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationConfig {
  static const String NOTIFICATION_CHANNEL = 'New Email';

  static DarwinInitializationSettings get iosInitializationSettings {
    final strings = AppLocalizations();
    return DarwinInitializationSettings(notificationCategories: [DarwinNotificationCategory(
      NumberInboxNotificationTarget.category, actions: [
        for (final entry in <NumberInboxMailAction, String>{
          NumberInboxMailAction.markRead: strings.mark_as_read,
          NumberInboxMailAction.archive: strings.archiveMessage,
          NumberInboxMailAction.reply: strings.reply,
        }.entries)
          DarwinNotificationAction.plain(entry.key.id, entry.value,
            options: {DarwinNotificationActionOption.foreground, DarwinNotificationActionOption.authenticationRequired}),
      ])]);
  }
  static const androidInitializationSettings = AndroidInitializationSettings('notification_icon');

  LocalNotificationConfig._internal();

  static final LocalNotificationConfig _instance = LocalNotificationConfig._internal();

  static LocalNotificationConfig get instance => _instance;

  NotificationDetails generateNotificationDetails({
    StyleInformation? styleInformation,
    bool setAsGroup = false,
    bool silent = false,
    String? groupId,
    AndroidBitmap<Object>? largeIcon = const DrawableResourceAndroidBitmap('ic_large_notification'),
    List<AndroidNotificationAction>? actions,
    String? categoryIdentifier,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        NOTIFICATION_CHANNEL,
        NOTIFICATION_CHANNEL,
        icon: 'notification_icon',
        groupKey: groupId,
        // Email subject, sender and preview are attacker-controlled and
        // confidential: honour the "hide sensitive content" lock screen
        // setting instead of forcing full display.
        visibility: NotificationVisibility.private,
        importance: Importance.max,
        priority: Priority.high,
        setAsGroupSummary: setAsGroup,
        styleInformation: styleInformation,
        silent: silent,
        groupAlertBehavior: setAsGroup
          ? GroupAlertBehavior.summary
          : GroupAlertBehavior.all,
        channelShowBadge: true,
        showWhen: true,
        largeIcon: largeIcon,
        actions: actions
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: categoryIdentifier,
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
        threadIdentifier: NOTIFICATION_CHANNEL
      ),
    );
  }
}