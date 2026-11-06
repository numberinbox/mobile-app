import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_mail_presentation.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_sender_avatar.dart';
import 'dart:async';
import 'dart:convert';

import 'package:core/presentation/extensions/html_extension.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/platform_info.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:model/notification/notification_payload.dart';
import 'package:model/extensions/email_address_extension.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/local_notification_config.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class LocalNotificationManager {

  late StreamController<NotificationResponse> localNotificationsController;

  LocalNotificationManager._internal() {
    localNotificationsController = StreamController<NotificationResponse>.broadcast();
  }

  static final LocalNotificationManager _instance = LocalNotificationManager._internal();

  static LocalNotificationManager get instance => _instance;

  final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// The avatar is optional, so it never delays the notification for long, but
  /// a cold start needs more than a warm app to draw the first bitmap.
  static const _avatarBudget = Duration(milliseconds: 500);

  NotificationResponse? _pendingNumberInboxResponse;
  void holdNumberInboxResponse(NotificationResponse response) => _pendingNumberInboxResponse = response;
  NotificationResponse? takeNumberInboxResponse() {
    final response = _pendingNumberInboxResponse;
    _pendingNumberInboxResponse = null;
    return response;
  }

  bool _isNotificationClickedOnTerminate = false;

  Stream<NotificationResponse> get localNotificationStream => localNotificationsController.stream;

  NotificationAppLaunchDetails? _notificationAppLaunchDetails;

  Future<void> setUp({required String groupId}) async {
    try {
      final isInitialNotification = await _initLocalNotification();
      log('LocalNotificationManager::setUp:isInitialNotification: $isInitialNotification');
      await _checkLocalNotificationPermission();
      if (PlatformInfo.isAndroid) {
        await _createAndroidNotificationChannelGroup(groupId);
        await _createAndroidNotificationChannel(groupId);
      }
    } catch (e) {
      logWarning('LocalNotificationManager::setUp(): ERROR: ${e.toString()}');
    }
  }

  Future<NotificationResponse?> getCurrentNotificationResponse() async {
    try {
      _notificationAppLaunchDetails = await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      return _notificationAppLaunchDetails?.notificationResponse;
    } catch (e) {
      logWarning('LocalNotificationManager::getCurrentNotificationResponse(): ERROR: ${e.toString()}');
    }
    return null;
  }

  set activatedNotificationClickedOnTerminate(bool clicked) => _isNotificationClickedOnTerminate = clicked;

  bool get isNotificationClickedOnTerminate => _isNotificationClickedOnTerminate;

  Future<bool?> _initLocalNotification() async {
    return await _localNotificationsPlugin.initialize(
      InitializationSettings(
        android: LocalNotificationConfig.androidInitializationSettings,
        iOS: LocalNotificationConfig.iosInitializationSettings
      ),
      onDidReceiveNotificationResponse: _handleReceiveNotificationResponse
    );
  }

  void _handleReceiveNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType == NotificationResponseType.selectedNotification ||
        NumberInboxMailAction.fromId(response.actionId) != null) {
      if (!localNotificationsController.isClosed) {
        if (!localNotificationsController.hasListener && NumberInboxNotificationTarget.decode(response.payload) != null) {
          holdNumberInboxResponse(response);
        } else { localNotificationsController.add(response); }
      }
    }
  }

  Future<void> _checkLocalNotificationPermission() async {
    if (PlatformInfo.isAndroid) {
      final granted = await _isAndroidPermissionGranted();
      log('LocalNotificationManager::requestPermissionAndroid: _isAndroidPermissionGranted = $granted');
      if (!granted) {
        await _requestPermissions();
      }
    } else if (PlatformInfo.isIOS) {
      log('LocalNotificationManager::requestPermissionIOS');
      await _requestPermissions();
    }
  }

  Future<bool> _isAndroidPermissionGranted() async {
    return await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.areNotificationsEnabled() ?? false;
  }

  Future<bool> _requestPermissions() async {
    if (PlatformInfo.isAndroid) {
      return await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ?? false;
    } else if (PlatformInfo.isIOS) {
      return await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } else {
      return false;
    }
  }

  Future<void> _createAndroidNotificationChannel(String groupId) async {
    return await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(AndroidNotificationChannel(
          LocalNotificationConfig.NOTIFICATION_CHANNEL,
          LocalNotificationConfig.NOTIFICATION_CHANNEL,
          groupId: groupId,
      ));
  }

  Future<void> _createAndroidNotificationChannelGroup(String groupId) async {
    await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannelGroup(AndroidNotificationChannelGroup(
          groupId,
          groupId,
      ));
  }

  Future<void> showPushNotification({
    required String id,
    required String title,
    bool silent = false,
    String? message,
    EmailAddress? emailAddress,
    String? payload,
    String? groupId,
    bool numberInboxLayout = false,
    bool omitLargeIcon = false,
    NumberInboxNotificationTarget? mailTarget,
    Future<bool> Function()? canDisplay,
  }) async {
    final presentation = numberInboxLayout ? NumberInboxMailPresentation(subject: title, preview: message, sender: emailAddress) : null;
    final avatar = presentation == null ? null : await NumberInboxSenderAvatar.render(
      presentation.name.isNotEmpty ? presentation.name : presentation.address).timeout(_avatarBudget, onTimeout: () => null);
    if (canDisplay != null && !await canDisplay()) throw StateError('notification session ended');
    final strings = AppLocalizations();
    final actions = mailTarget == null ? null : <AndroidNotificationAction>[
      for (final entry in <NumberInboxMailAction, String>{
        NumberInboxMailAction.markRead: strings.mark_as_read,
        NumberInboxMailAction.archive: strings.archiveMessage,
        NumberInboxMailAction.reply: strings.reply,
      }.entries)
        AndroidNotificationAction(entry.key.id, entry.value, showsUserInterface: true, cancelNotification: false),
    ];
    final inboxStyleInformation = buildInboxStyleInformation(
      title: title,
      message: message,
      emailAddress: emailAddress,
    );

    await _localNotificationsPlugin.show(
      id.hashCode,
      presentation?.title ?? title,
      presentation?.collapsedText ?? message,
      LocalNotificationConfig.instance.generateNotificationDetails(
        styleInformation: presentation?.style ?? inboxStyleInformation,
        groupId: groupId,
        largeIcon: presentation != null ? (avatar == null ? null : ByteArrayAndroidBitmap(avatar)) :
          (omitLargeIcon ? null : const DrawableResourceAndroidBitmap('ic_large_notification')),
        actions: actions,
        categoryIdentifier: mailTarget == null ? null : NumberInboxNotificationTarget.category,
        silent: silent
      ),
      payload: payload);
  }

  /// Subject, preview and sender come from the received email: escape them
  /// before they are rendered as HTML, and show the sender address first so
  /// that a long or spoofed display name cannot hide it.
  static InboxStyleInformation buildInboxStyleInformation({
    required String title,
    String? message,
    EmailAddress? emailAddress,
  }) {
    const htmlEscape = HtmlEscape();
    return InboxStyleInformation(
      [message != null
          ? htmlEscape.convert(message).addBlockTag('p', attribute: 'style="color:#6D7885;"')
          : ''],
      htmlFormatLines: true,
      contentTitle: htmlEscape.convert(title),
      htmlFormatContentTitle: true,
      summaryText: htmlEscape.convert(_senderLine(emailAddress)).addBlockTag('b'),
      htmlFormatSummaryText: true);
  }

  static String _senderLine(EmailAddress? address) {
    final email = address?.emailAddress ?? '';
    final name = address?.displayName ?? '';
    if (name.isEmpty || name == email) return email;
    if (email.isEmpty) return name;
    return '$email ($name)';
  }

  Future<void> showGenericNewMailNotification({required String emailId}) {
    return showPushNotification(
      id: emailId,
      title: 'NumberInbox',
      omitLargeIcon: true,
      message: 'You have new mail',
      payload: NotificationPayload(emailId: EmailId(Id(emailId))).encodeToString,
    );
  }

  Future<void> cancelAll() async {
    _pendingNumberInboxResponse = null;
    try {
      await _localNotificationsPlugin.cancelAll().timeout(const Duration(seconds: 2));
    } catch (_) {
      logWarning('LocalNotificationManager::cancelAll: notification cleanup failed');
    }
  }

  Future<void> removeNotification(String id) async {
    try {
      await _localNotificationsPlugin.cancel(id.hashCode);
    } catch (e) {
      logWarning('LocalNotificationManager::removeNotification(): id = $id | ERROR: $e');
    }
  }

  Future<int> getCountActiveNotificationByGroupOnAndroid({required String groupId}) async {
    final activeNotifications = await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.getActiveNotifications() ?? [];

    final listActiveNotificationByGroup = activeNotifications
      .where((notification) => notification.groupKey == groupId && notification.id != groupId.hashCode)
      .toList();
    log('LocalNotificationManager::getCountActiveNotificationByGroupOnAndroid(): groupId = $groupId | activeNotifications = ${activeNotifications.length} | listActiveNotificationByGroup = ${listActiveNotificationByGroup.length}');
    return listActiveNotificationByGroup.length;
  }

  Future<void> groupPushNotificationOnAndroid({required String groupId, required int countNotifications, bool silent = false}) async {
    log('LocalNotificationManager::groupPushNotificationOnAndroid:groupId = $groupId');
    final inboxStyleInformation = InboxStyleInformation(
      [''],
      summaryText: currentContext != null
        ? AppLocalizations.of(currentContext!).totalNewMessagePushNotification(countNotifications).addBlockTag('b')
        : '$countNotifications new emails'.addBlockTag('b'),
      htmlFormatSummaryText: true,
    );

    await _localNotificationsPlugin.show(
      groupId.hashCode,
      null,
      null,
      LocalNotificationConfig.instance.generateNotificationDetails(
        setAsGroup: true,
        silent: silent,
        largeIcon: null,
        styleInformation: inboxStyleInformation,
        groupId: groupId
      ),
    );
  }

  Future<void> removeGroupPushNotification(String groupId) async {
    final activeNotifications = await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.getActiveNotifications() ?? [];

    final listActiveNotificationByGroup = activeNotifications
      .where((notification) => notification.groupKey == groupId)
      .toList();
    log('LocalNotificationManager::removeGroupPushNotification(): activeNotifications = ${activeNotifications.length} | listActiveNotificationByGroup = ${listActiveNotificationByGroup.length}');
    if (listActiveNotificationByGroup.length <= 1) {
      log('LocalNotificationManager::groupPushNotification():canceled');
      await removeNotification(groupId);
    }
  }

  Future<void> recreateStreamController() {
    if (localNotificationsController.isClosed) {
      localNotificationsController = StreamController<NotificationResponse>.broadcast();
    }
    return Future.value();
  }

  void closeStream() {
    localNotificationsController.close();
  }
}