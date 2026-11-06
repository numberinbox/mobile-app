import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';

import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/model.dart';
import 'package:rxdart/rxdart.dart';

class IOSNotificationManager {

  static const _notificationInteractionChannel = MethodChannel('notification_interaction_channel');

  static const String CURRENT_EMAIL_ID_IN_NOTIFICATION_CLICK_WHEN_APP_FOREGROUND_OR_BACKGROUND = 'current_email_id_in_notification_click_when_app_foreground_or_background';
  static const String CURRENT_EMAIL_ID_IN_NOTIFICATION_CLICK_WHEN_APP_TERMINATED = 'current_email_id_in_notification_click_when_app_terminated';

  BehaviorSubject<EmailId?> _pendingCurrentEmailIdInNotification = BehaviorSubject.seeded(null);
  BehaviorSubject<EmailId?> get pendingCurrentEmailIdInNotification => _pendingCurrentEmailIdInNotification;

  StreamSubscription<EmailId?>? _getCurrentEmailIdStreamSubscription;
  BehaviorSubject<NotificationResponse?> pendingNumberInboxResponse = BehaviorSubject.seeded(null);
  void clearPendingNumberInboxResponse() { if (!pendingNumberInboxResponse.isClosed) pendingNumberInboxResponse.add(null); }

  void _acceptNumberInboxInteraction(dynamic arguments) {
    if (arguments is! Map || pendingNumberInboxResponse.isClosed) return;
    final action = arguments['actionId'];
    if (action is! String || (action.isNotEmpty && NumberInboxMailAction.fromId(action) == null)) return;
    final payload = jsonEncode({'niVersion': arguments['niVersion'], 'niAccountId': arguments['niAccountId'], 'emailId': arguments['emailId']});
    if (NumberInboxNotificationTarget.decode(payload) == null) return;
    pendingNumberInboxResponse.add(NotificationResponse(
      notificationResponseType: action.isEmpty ? NotificationResponseType.selectedNotification : NotificationResponseType.selectedNotificationAction,
      actionId: action, payload: payload));
  }


  void listenClickNotification() {
    if (pendingNumberInboxResponse.isClosed) pendingNumberInboxResponse = BehaviorSubject.seeded(null);
    try {
      _notificationInteractionChannel.setMethodCallHandler((methodCall) async {
        if (methodCall.method == 'numberinbox_notification_action') {
          _acceptNumberInboxInteraction(methodCall.arguments);
          return true;
        }
        if (methodCall.method == CURRENT_EMAIL_ID_IN_NOTIFICATION_CLICK_WHEN_APP_FOREGROUND_OR_BACKGROUND
            && methodCall.arguments != null) {
          final emailId = EmailId(Id(methodCall.arguments));
          setPendingCurrentEmailId(emailId);
        }
      });

      unawaited(_notificationInteractionChannel.invokeMethod<dynamic>('get_pending_numberinbox_notification_action')
        .then(_acceptNumberInboxInteraction).catchError((_) {}));
      _getCurrentEmailIdStreamSubscription = Stream.fromFuture(_getCurrentEmailIdInNotificationClick()).listen((emailId) {
        log('IOSNotificationManager::listenClickNotification:_getCurrentEmailIdInNotificationClick:EmailId = ${emailId?.asString}');
        if (emailId != null) {
          setPendingCurrentEmailId(emailId);
        }
      });
    } catch (e) {
      logWarning('IOSNotificationManager::listenClickNotification:Exception = $e');
    }
  }

  Future<EmailId?> _getCurrentEmailIdInNotificationClick() async {
    try {
      log('IOSNotificationManager::_getCurrentEmailIdInNotificationClick: START');
      final emailId = await _notificationInteractionChannel.invokeMethod<String?>(CURRENT_EMAIL_ID_IN_NOTIFICATION_CLICK_WHEN_APP_TERMINATED);
      log('IOSNotificationManager::_getCurrentEmailIdInNotificationClick: END');
      if (emailId?.isNotEmpty == true) {
        return EmailId(Id(emailId!));
      } else {
        return null;
      }
    } catch (e) {
      logWarning('IOSNotificationManager::getCurrentEmailIdInNotificationClick:Exception = $e');
      return null;
    }
  }

  void setPendingCurrentEmailId(EmailId emailId) async {
    clearPendingCurrentEmailId();
    _pendingCurrentEmailIdInNotification.add(emailId);
  }

  void clearPendingCurrentEmailId() {
    if(_pendingCurrentEmailIdInNotification.isClosed) {
      _pendingCurrentEmailIdInNotification = BehaviorSubject.seeded(null);
    } else {
      _pendingCurrentEmailIdInNotification.add(null);
    }
  }

  Future<void> removeMailNotification(String accountId, String emailId) =>
    _notificationInteractionChannel.invokeMethod<void>('remove_numberinbox_mail_notification',
      {'niAccountId': accountId, 'emailId': emailId});

  void dispose() {
    pendingNumberInboxResponse.close();
    _pendingCurrentEmailIdInNotification.close();
    _getCurrentEmailIdStreamSubscription?.cancel();
    _getCurrentEmailIdStreamSubscription = null;
  }
}