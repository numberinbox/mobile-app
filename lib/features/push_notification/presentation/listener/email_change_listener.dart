import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/platform_info.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/email/email_property.dart';
import 'package:model/email/presentation_email.dart';
import 'package:model/extensions/list_presentation_email_extension.dart';
import 'package:model/extensions/list_presentation_mailbox_extension.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:model/notification/notification_payload.dart';
import 'package:tmail_ui_user/features/base/action/ui_action.dart';
import 'package:tmail_ui_user/features/email/domain/model/detailed_email.dart';
import 'package:tmail_ui_user/features/email/domain/state/get_detailed_email_by_id_state.dart';
import 'package:tmail_ui_user/features/email/domain/state/get_stored_state_email_state.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/get_list_detailed_email_by_id_interator.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/get_stored_email_state_interactor.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/store_list_new_email_interator.dart';
import 'package:tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:tmail_ui_user/features/email/presentation/utils/email_utils.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/fcm_exception.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_remove_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_mailboxes_not_put_notifications_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_new_receive_email_from_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_stored_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_remove_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_mailboxes_not_put_notifications_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_new_receive_email_from_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/action/push_notification_state_change_action.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/listener/change_listener.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/local_notification_manager.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/utils/fcm_utils.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class EmailChangeListener extends ChangeListener {

  MailboxDashBoardController? _dashBoardController;
  GetStoredEmailDeliveryStateInteractor? _getStoredEmailDeliveryStateInteractor;
  StoreEmailDeliveryStateInteractor? _storeEmailDeliveryStateInteractor;
  GetEmailChangesToPushNotificationInteractor? _getEmailChangesToPushNotificationInteractor;
  GetStoredEmailStateInteractor? _getStoredEmailStateInteractor;
  GetMailboxesNotPutNotificationsInteractor? _getMailboxesNotPutNotificationsInteractor;
  GetEmailChangesToRemoveNotificationInteractor? _getEmailChangesToRemoveNotificationInteractor;
  GetNewReceiveEmailFromNotificationInteractor? _getNewReceiveEmailFromNotificationInteractor;
  GetListDetailedEmailByIdInteractor? _getListDetailedEmailByIdInteractor;
  DynamicUrlInterceptors? _dynamicUrlInterceptors;
  StoreListNewEmailInteractor? _storeListNewEmailInteractor;

  jmap.State? _newStateEmailDelivery;
  AccountId? _accountId;
  Session? _session;
  UserName? _userName;
  List<PresentationEmail> _emailsAvailablePushNotification = [];

  EmailChangeListener._internal() {
    try {
      _dashBoardController = getBinding<MailboxDashBoardController>();
      _getStoredEmailStateInteractor = getBinding<GetStoredEmailStateInteractor>();
      _getStoredEmailDeliveryStateInteractor = getBinding<GetStoredEmailDeliveryStateInteractor>();
      _storeEmailDeliveryStateInteractor = getBinding<StoreEmailDeliveryStateInteractor>();
      _getEmailChangesToPushNotificationInteractor = getBinding<GetEmailChangesToPushNotificationInteractor>();
      _getMailboxesNotPutNotificationsInteractor = getBinding<GetMailboxesNotPutNotificationsInteractor>();
      _getEmailChangesToRemoveNotificationInteractor = getBinding<GetEmailChangesToRemoveNotificationInteractor>();
      _getNewReceiveEmailFromNotificationInteractor = getBinding<GetNewReceiveEmailFromNotificationInteractor>();
      _getListDetailedEmailByIdInteractor = getBinding<GetListDetailedEmailByIdInteractor>();
      _dynamicUrlInterceptors = getBinding<DynamicUrlInterceptors>();
      _storeListNewEmailInteractor = getBinding<StoreListNewEmailInteractor>();
    } catch (e) {
      logWarning('EmailChangeListener::_internal(): IS NOT REGISTERED: ${e.toString()}');
    }
  }

  static final EmailChangeListener _instance = EmailChangeListener._internal();

  static EmailChangeListener get instance => _instance;

  @visibleForTesting
  void setStoredEmailDeliveryStateInteractorForTesting(
    GetStoredEmailDeliveryStateInteractor interactor,
  ) {
    _getStoredEmailDeliveryStateInteractor = interactor;
  }

  @override
  void dispatchActions(List<Action> actions) {
    log('EmailChangeListener::dispatchActions():actions: $actions');
    for (var action in actions) {
      if (action is SynchronizeEmailOnForegroundAction) {
        _onSynchronizeEmailOnForeground(action);
      } else if (action is PushNotificationAction) {
        _onPushNotification(action);
      } else if (action is StoreEmailStateToRefreshAction) {
        if (PlatformInfo.isAndroid) {
          _handleRemoveNotificationWhenEmailMarkAsRead(action.newState, action.accountId, action.session);
        }
      }
    }
  }

  void _onSynchronizeEmailOnForeground(SynchronizeEmailOnForegroundAction action) {
    final userName = action.session?.username;
    if (userName == null) {
      _synchronizeEmailOnForegroundAction(action.newState);
      return;
    }
    unawaited(processForegroundPlatformPushNotification(
      newState: action.newState,
      accountId: action.accountId,
      userName: userName,
      session: action.session,
    ));
  }

  /// Foreground platform push: syncs the UI and returns true only once the
  /// new-email fetch and, on Android, the delivery-cursor write have finished.
  /// The controller records the delivery as processed on that result, so an
  /// incomplete pipeline stays retriable.
  Future<bool> processForegroundPlatformPushNotification({
    required jmap.State newState,
    required AccountId accountId,
    required UserName userName,
    required Session? session,
  }) async {
    _newStateEmailDelivery = newState;
    _accountId = accountId;
    _session = session;
    _userName = userName;

    if (PlatformInfo.isAndroid) {
      _handleRemoveNotificationWhenEmailMarkAsRead(newState, accountId, session);
    }
    _synchronizeEmailOnForegroundAction(newState);

    var completed = true;
    if (PlatformInfo.isMobile) {
      completed = await _getNewReceiveEmailFromNotificationAction(
        session,
        accountId,
        newState,
      );
    }
    if (PlatformInfo.isAndroid) {
      // On Android, foreground sync must persist the new delivery state so the
      // next background FCM push does not replay already-seen email changes.
      final persisted = await _storeEmailDeliveryStateAction(
        accountId,
        userName,
        newState,
      );
      completed = persisted && completed;
    }
    return completed;
  }

  /// Awaits every state emitted by the interactor stream, including the
  /// handlers' own downstream work, and reports whether the whole chain
  /// completed. The websocket paths fire-and-forget this future; the FCM
  /// paths await it so an incomplete pipeline is never marked as processed.
  Future<bool> _consumeStateAndWait(Stream<Either<Failure, Success>> newStateStream) async {
    var completed = true;
    try {
      await for (final viewState in newStateStream) {
        final succeeded = await viewState.fold(
          (failure) => handleFailureViewState(failure),
          (success) => handleSuccessViewState(success),
        );
        completed = completed && succeeded;
      }
    } catch (e, st) {
      logError(
        'EmailChangeListener::_consumeStateAndWait: throw exception',
        exception: e,
        stackTrace: st,
      );
      return false;
    }
    return completed;
  }

  /// Background platform push: runs the delivery notification pipeline and
  /// completes only once the JMAP fetch, the delivery-cursor update and the
  /// local notification work have finished.
  /// Serializes background platform pushes: the per-call shared session
  /// fields would otherwise be overwritten while a previous push is still
  /// running its stored-state lookup and Email/changes fetch, so a second
  /// push would fetch mail for the wrong account. Each push is awaited to
  /// completion (including its delivery-cursor write) before the next one
  /// starts.
  Future<void> _platformPushChain = Future<void>(() {});

  /// True while a NumberInbox platform push is being processed on
  /// [_platformPushChain]. Android has already displayed the system
  /// notification for a platform push, so the listener must not post any
  /// app-generated local notification of its own.
  bool _isProcessingPlatformPush = false;

  Future<bool> processPlatformPushNotification({
    required jmap.State newState,
    required AccountId accountId,
    required UserName userName,
    required Session? session,
  }) {
    final processFuture = _processPlatformPushOnChain(
      newState: newState,
      accountId: accountId,
      userName: userName,
      session: session);
    // A failed push must not poison the queue, otherwise the next pushes
    // would never run.
    _platformPushChain = processFuture.then<void>((_) {}, onError: (e, st) {
      logError(
        'EmailChangeListener::processPlatformPushNotification: platform push processing failed, continue with the next queued push',
        exception: e,
        stackTrace: st,
      );
    });
    return processFuture;
  }

  Future<bool> _processPlatformPushOnChain({
    required jmap.State newState,
    required AccountId accountId,
    required UserName userName,
    required Session? session,
  }) async {
    // Await the previous push so its per-call handlers finish before this
    // push overwrites the shared listener fields.
    await _platformPushChain;
    _isProcessingPlatformPush = true;
    try {
      _newStateEmailDelivery = newState;
      _accountId = accountId;
      _session = session;
      _userName = userName;
      log('EmailChangeListener::processPlatformPushNotification():newState: $newState');

      if (PlatformInfo.isWeb || PlatformInfo.isIOS) {
        return await _storeEmailDeliveryStateAction(accountId, userName, newState);
      } else if (PlatformInfo.isAndroid) {
        return await _getStoredEmailDeliveryState(accountId, userName);
      }
      return true;
    } finally {
      _isProcessingPlatformPush = false;
    }
  }

  void _onPushNotification(PushNotificationAction action) {
    _pushNotificationAction(action.newState, action.accountId, action.userName, action.session);
    if (PlatformInfo.isAndroid) {
      unawaited(_getNewReceiveEmailFromNotificationAction(
        action.session,
        action.accountId,
        action.newState,
      ));
    }
  }

  void _synchronizeEmailOnForegroundAction(jmap.State newState) {
    log('EmailChangeListener::_synchronizeEmailAction():newState: $newState');
    _dashBoardController?.dispatchEmailUIAction(RefreshChangeEmailAction(
      newState: newState,
    ));
  }

  void _pushNotificationAction(jmap.State newState, AccountId accountId, UserName userName, Session? session) {
    _newStateEmailDelivery = newState;
    _accountId = accountId;
    _session = session;
    _userName = userName;
    log('EmailChangeListener::_pushNotificationAction():newState: $newState');

    if (PlatformInfo.isWeb) {
      unawaited(_storeEmailDeliveryStateAction(accountId, userName, _newStateEmailDelivery!));
    } else if (PlatformInfo.isIOS) {
      unawaited(_storeEmailDeliveryStateAction(accountId, userName, _newStateEmailDelivery!));
    } else if (PlatformInfo.isAndroid) {
      unawaited(_getStoredEmailDeliveryState(accountId, userName));
    }
  }

  Future<bool> _getStoredEmailDeliveryState(AccountId accountId, UserName userName) async {
    if (_getStoredEmailDeliveryStateInteractor == null) return true;
    return _consumeStateAndWait(
        _getStoredEmailDeliveryStateInteractor!.execute(accountId, userName));
  }

  Future<bool> _getStoredEmailState() async {
    final canExecute = _getStoredEmailStateInteractor != null
        && _session != null
        && _accountId != null;
    if (!canExecute) return true;
    return _consumeStateAndWait(
      _getStoredEmailStateInteractor!.execute(_session!, _accountId!));
  }

  Future<bool> _getEmailChangesAction(jmap.State state) async {
    if (FcmUtils.isPlatformPushState(state)) {
      logTrace('EmailChangeListener::_getEmailChangesAction: skip a non-server platform push state: $state');
      return true;
    }
    final canExecute = _getEmailChangesToPushNotificationInteractor != null
        && _accountId != null
        && _session != null
        && _userName != null;
    if (!canExecute) return true;
    return _consumeStateAndWait(_getEmailChangesToPushNotificationInteractor!.execute(
      _session!,
      _accountId!,
      _userName!,
      state,
      propertiesCreated: EmailUtils.getPropertiesForEmailGetMethod(
        _session!,
        _accountId!,
      ),
    ));
  }

  /// Awaits the delivery-cursor write. The Android background FCM path
  /// awaits this so the OS cannot tear the isolate down before the new
  /// state is persisted; a premature callback return would let a later
  /// push replay the same email changes.
  Future<bool> _storeEmailDeliveryStateAction(AccountId accountId, UserName userName, jmap.State state) async {
    if (FcmUtils.isPlatformPushState(state)) {
      logTrace('EmailChangeListener::_storeEmailDeliveryStateAction: skip persisting a non-server platform push state: $state');
      return true;
    }
    if (_storeEmailDeliveryStateInteractor == null) return true;
    return _consumeStateAndWait(
      _storeEmailDeliveryStateInteractor!.execute(accountId, userName, state));
  }

  Future<void> _showLocalNotification({
    required UserName userName,
    required PresentationEmail presentationEmail,
    bool silent = false,
  }) async {
    return await LocalNotificationManager.instance.showPushNotification(
      id: presentationEmail.id?.id.value ?? '',
      title: presentationEmail.subject ?? '',
      message: presentationEmail.preview,
      emailAddress: presentationEmail.firstFromAddress,
      payload: NotificationPayload(emailId: presentationEmail.id).encodeToString,
      groupId: userName.value,
      silent: silent
    );
  }

  @override
  Future<bool> handleFailureViewState(Failure failure) async {
    log('EmailChangeListener::_handleFailureViewState(): $failure');
    if (failure is GetStoredEmailDeliveryStateFailure &&
        failure.exception is NotFoundEmailDeliveryStateException) {
      return _getStoredEmailState();
    } else if (failure is GetNewReceiveEmailFromNotificationFailure &&
        failure.exception is EmailStateNoChangeException) {
      return true;
    } else if (failure is GetMailboxesNotPutNotificationsFailure) {
      final listEmails = _emailsAvailablePushNotification.toEmailsAvailablePushNotification();
      await _handleLocalPushNotification(
        userName: failure.userName,
        emailList: listEmails
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> handleSuccessViewState(Success success) async {
    log('EmailChangeListener::_handleSuccessViewState(): $success');
    if (success is GetStoredEmailDeliveryStateSuccess) {
      return _handleGetStoredEmailDeliveryStateSuccess(success);
    } else if (success is GetStoredEmailStateSuccess) {
      return _getEmailChangesAction(success.state);
    } else if (success is GetEmailChangesToPushNotificationSuccess) {
      return _handleGetEmailChangesToPushNotificationSuccess(success);
    } else if (success is GetMailboxesNotPutNotificationsSuccess) {
      final listEmails = _emailsAvailablePushNotification.toEmailsAvailablePushNotification(
        mailboxIdsNotPutNotifications: success.mailboxes.mailboxIds);
      await _handleLocalPushNotification(
        userName: success.userName,
        emailList: listEmails
      );
      return true;
    } else if (success is GetEmailChangesToRemoveNotificationSuccess) {
      await _handleRemoveLocalNotification(
        userName: success.userName,
        emailIds: success.emailIds
      );
      return true;
    } else if (success is GetNewReceiveEmailFromNotificationSuccess) {
      return _getListDetailedEmailByIdAction(success.session, success.accountId, success.emailIds);
    } else if (success is GetDetailedEmailByIdSuccess) {
      return _storeNewEmailAction(
        success.session,
        success.accountId,
        success.mapDetailedEmail);
    }
    return true;
  }

  Future<bool> _handleGetStoredEmailDeliveryStateSuccess(GetStoredEmailDeliveryStateSuccess success) async {
    if (_newStateEmailDelivery != success.state) {
      return _getEmailChangesAction(success.state);
    }
    return true;
  }

  Future<bool> _handleGetEmailChangesToPushNotificationSuccess(GetEmailChangesToPushNotificationSuccess success) async {
    if (_newStateEmailDelivery == null) return true;

    var completed = true;
    // Advance the delivery cursor to the real state the JMAP Email/changes
    // response returned. The push state is not a server state and would
    // otherwise leave the cursor stale - repeating notifications and
    // eventually failing with an expired since-state.
    final realNewState = success.newState;
    if (realNewState != null) {
      completed = await _storeEmailDeliveryStateAction(success.accountId, success.userName, realNewState);
    } else {
      logTrace('EmailChangeListener::_handleGetEmailChangesToPushNotificationSuccess: no new state returned, keep the current delivery state');
    }

    if (PlatformInfo.isAndroid) {
      if (_isProcessingPlatformPush) {
        // Android already displayed the system notification for the
        // platform push; posting the rich app notification would duplicate
        // it and leak subject, preview and sender on the lock screen.
        logTrace('EmailChangeListener::_handleGetEmailChangesToPushNotificationSuccess: skip the local notification display for a platform push, Android already displayed the system notification');
        _emailsAvailablePushNotification = [];
        return completed;
      }
      await _handleListEmailToPushNotification(
        userName: success.userName,
        emailList: success.emailList,
      );
    }
    return completed;
  }

  Future<void> _handleListEmailToPushNotification({
    required UserName userName,
    required List<PresentationEmail> emailList
  }) async {
    _emailsAvailablePushNotification = emailList;
    final canFilterByMailbox = _getMailboxesNotPutNotificationsInteractor != null
        && _accountId != null
        && _session != null;
    if (canFilterByMailbox) {
      await _consumeStateAndWait(
        _getMailboxesNotPutNotificationsInteractor!.execute(_session!, _accountId!));
    } else {
      final listEmails = _emailsAvailablePushNotification.toEmailsAvailablePushNotification();
      await _handleLocalPushNotification(
        userName: userName,
        emailList: listEmails,
      );
    }
  }

  Future<void> _handleLocalPushNotification({
    required UserName userName,
    required List<PresentationEmail> emailList
  }) async {
    log('EmailChangeListener::_handleLocalPushNotification(): EMAIL_LENGTH = ${emailList.length}');
    if (emailList.isEmpty) {
      _emailsAvailablePushNotification = [];
      return;
    }

    final selectedEmails = emailList.selectEmailsForNotification();
    log('EmailChangeListener::_handleLocalPushNotification(): SELECTED = ${selectedEmails.length}');

    for (var presentationEmail in selectedEmails) {
      await _showLocalNotification(
        userName: userName,
        presentationEmail: presentationEmail,
        silent: PlatformInfo.isAndroid
      );
    }

    if (PlatformInfo.isAndroid) {
      final countNotifications = await LocalNotificationManager.instance
        .getCountActiveNotificationByGroupOnAndroid(groupId: userName.value);

      await LocalNotificationManager.instance.groupPushNotificationOnAndroid(
        groupId: userName.value,
        countNotifications: countNotifications);
    }

    _emailsAvailablePushNotification = [];
  }

  void _handleRemoveNotificationWhenEmailMarkAsRead(jmap.State newState, AccountId accountId, Session? session) {
    if (FcmUtils.isPlatformPushState(newState)) {
      logTrace('EmailChangeListener::_handleRemoveNotificationWhenEmailMarkAsRead: skip a non-server platform push state: $newState');
      return;
    }
    if (_getEmailChangesToRemoveNotificationInteractor != null && session != null) {
      consumeState(_getEmailChangesToRemoveNotificationInteractor!.execute(
        session,
        accountId,
        newState,
        propertiesUpdated: Properties({EmailProperty.keywords}),
      ));
    }
  }

  Future<void> _handleRemoveLocalNotification({
    required UserName userName,
    required List<EmailId> emailIds
  }) async {
    log('EmailChangeListener::_handleRemoveLocalNotification():emailIds: $emailIds');
    await Future.wait(emailIds.map((emailId) => LocalNotificationManager.instance.removeNotification(emailId.id.value)));
    await LocalNotificationManager.instance.removeGroupPushNotification(userName.value);
  }

  Future<bool> _getNewReceiveEmailFromNotificationAction(Session? session, AccountId accountId, jmap.State newState) {
    if (_getNewReceiveEmailFromNotificationInteractor == null || session == null) {
      return Future.value(true);
    }
    return _consumeStateAndWait(
      _getNewReceiveEmailFromNotificationInteractor!.execute(
        session: session,
        accountId: accountId,
        userName: session.username,
        newState: newState
      ));
  }

  Future<bool> _getListDetailedEmailByIdAction(Session? session, AccountId accountId, List<EmailId> emailIds) async {
    log('EmailChangeListener::_getListDetailedEmailByIdAction():emailIds: $emailIds');
    final canExecute = _getListDetailedEmailByIdInteractor != null
        && _dynamicUrlInterceptors != null
        && session != null;
    if (!canExecute) return true;
    try {
      final baseDownloadUrl = session.getDownloadUrl(jmapUrl: _dynamicUrlInterceptors!.jmapUrl);
      return await _consumeStateAndWait(_getListDetailedEmailByIdInteractor!.execute(
        session,
        accountId,
        emailIds,
        baseDownloadUrl,
      ));
    } catch (e) {
      logWarning('EmailChangeListener::_getListDetailedEmailByIdAction(): $e');
      return _consumeStateAndWait(Stream.value(Left(GetDetailedEmailByIdFailure(e))));
    }
  }

  Future<bool> _storeNewEmailAction(
    Session session,
    AccountId accountId,
    Map<Email, DetailedEmail> mapDetailedEmails
  ) {
    log('EmailChangeListener::_storeNewEmailAction():mapDetailedEmails: ${mapDetailedEmails.length}');
    if (_storeListNewEmailInteractor == null) return Future.value(true);
    return _consumeStateAndWait(_storeListNewEmailInteractor!.execute(
      session,
      accountId,
      mapDetailedEmails
    ));
  }
}