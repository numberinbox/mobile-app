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
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_target.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/utils/fcm_utils.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';
import 'package:tmail_ui_user/main/utils/ios_sharing_manager.dart';

typedef PresentLocalPushEmails = Future<void> Function({
  required UserName userName,
  required List<PresentationEmail> emailList,
});

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
  final PresentLocalPushEmails? _presentLocalPush;

  final Map<String, jmap.State> _newStateEmailDeliveryByAccount = {};
  final Map<String, Session?> _sessionByAccount = {};
  final Map<String, List<PresentationEmail>> _emailsAvailablePushNotificationByAccount = {};
  AccountId? _accountId;
  Session? _session;

  String _accountKey(AccountId accountId) => accountId.id.value;

  EmailChangeListener._internal()
      : _presentLocalPush = null {
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

  @visibleForTesting
  EmailChangeListener.forTesting({
    required GetStoredEmailDeliveryStateInteractor
        getStoredEmailDeliveryStateInteractor,
    required StoreEmailDeliveryStateInteractor storeEmailDeliveryStateInteractor,
    required GetEmailChangesToPushNotificationInteractor
        getEmailChangesToPushNotificationInteractor,
    required GetMailboxesNotPutNotificationsInteractor
        getMailboxesNotPutNotificationsInteractor,
    required PresentLocalPushEmails presentLocalPush,
    MailboxDashBoardController? dashBoardController,
  })  : _presentLocalPush = presentLocalPush,
        _dashBoardController = dashBoardController,
        _getStoredEmailDeliveryStateInteractor =
            getStoredEmailDeliveryStateInteractor,
        _storeEmailDeliveryStateInteractor = storeEmailDeliveryStateInteractor,
        _getEmailChangesToPushNotificationInteractor =
            getEmailChangesToPushNotificationInteractor,
        _getMailboxesNotPutNotificationsInteractor =
            getMailboxesNotPutNotificationsInteractor;

  static final EmailChangeListener _instance = EmailChangeListener._internal();

  static EmailChangeListener get instance => _instance;

  @visibleForTesting
  void setStoredEmailDeliveryStateInteractorForTesting(
    GetStoredEmailDeliveryStateInteractor interactor, {
    GetEmailChangesToPushNotificationInteractor? changes,
    StoreEmailDeliveryStateInteractor? store,
  }) {
    _getStoredEmailDeliveryStateInteractor = interactor;
    if (changes != null) _getEmailChangesToPushNotificationInteractor = changes;
    if (store != null) _storeEmailDeliveryStateInteractor = store;
  }

  static Future<void> _presentWithSystemNotifications({
    required UserName userName,
    required List<PresentationEmail> emailList,
    required AccountId accountId,
    Future<bool> Function()? canDisplay,
  }) async {
    if (emailList.isEmpty) return;
    final selectedEmails = emailList.selectEmailsForNotification();
    log('EmailChangeListener::_presentWithSystemNotifications(): SELECTED = ${selectedEmails.length}');

    for (var presentationEmail in selectedEmails) {
      await LocalNotificationManager.instance.showPushNotification(
        id: presentationEmail.id?.id.value ?? '',
        title: presentationEmail.subject ?? '',
        message: presentationEmail.preview,
        emailAddress: presentationEmail.firstFromAddress,
        payload: presentationEmail.id == null
            ? NotificationPayload(emailId: presentationEmail.id).encodeToString
            : NumberInboxNotificationTarget(
                accountId: accountId.id.value,
                emailId: presentationEmail.id!.id.value,
              ).encode(),
        canDisplay: canDisplay,
        groupId: userName.value,
        silent: PlatformInfo.isAndroid,
      );
    }

    if (PlatformInfo.isAndroid && (canDisplay == null || await canDisplay())) {
      final countNotifications = await LocalNotificationManager.instance
          .getCountActiveNotificationByGroupOnAndroid(groupId: userName.value);

      await LocalNotificationManager.instance.groupPushNotificationOnAndroid(
        groupId: userName.value,
        countNotifications: countNotifications,
      );
    }
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
    if (action.updateDeliveryAndNotifications) {
      _updateDeliveryAndNotificationsOnForeground(action);
    }
    if (action.refreshView) {
      _synchronizeEmailOnForegroundAction(action.newState);
    }
    if (action.storeOfflineBodies && PlatformInfo.isMobile) {
      _getNewReceiveEmailFromNotificationAction(action.session, action.accountId, action.newState);
    }
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
    if (FcmUtils.isPlatformPushState(newState)) {
      // Refresh a real cursor even though the UI uses a synthetic refresh token.
      // Failure is best effort: the foreground UI has already synchronized.
      try {
        final persisted = await processPlatformPushNotification(
          newState: newState, accountId: accountId, userName: userName,
          session: session, displayNotification: false);
        if (!persisted) logWarning('Foreground platform delivery cursor not updated');
      } catch (_) {
        logWarning('Foreground platform delivery cursor not updated');
      }
    } else if (PlatformInfo.isAndroid) {
      completed = await _storeEmailDeliveryStateAction(accountId, userName, newState) && completed;
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

  Future<void> _platformPushChain = Future<void>.value();

  Future<bool> processPlatformPushNotification({
    required jmap.State newState,
    required AccountId accountId,
    required UserName userName,
    required Session? session,
    bool displayNotification = true,
    Future<bool> Function()? isAccountStillActive,
  }) {
    final result = _platformPushChain.then((_) async {
      try {
        if (PlatformInfo.isWeb ||
            (PlatformInfo.isIOS && !FcmUtils.isPlatformPushState(newState))) {
          return await _storeEmailDeliveryStateAction(accountId, userName, newState);
        }
        if (session == null) return false;
        final changes = _getEmailChangesToPushNotificationInteractor;
        if (changes == null) return false;

        final sharing = PlatformInfo.isIOS ? getBinding<IOSSharingManager>() : null;
        jmap.State? storedState;
        if (PlatformInfo.isIOS) {
          final stored = await sharing?.getKeychainSharingSession(accountId);
          final value = stored?.emailDeliveryState ?? stored?.emailState;
          storedState = value == null ? null : jmap.State(value);
        } else {
          final lookup = _getStoredEmailDeliveryStateInteractor;
          if (lookup == null) return false;
          final result = await lookup.execute(accountId, userName).last;
          storedState = await result.fold<Future<jmap.State?>>(
            (failure) async {
              final fallback = _getStoredEmailStateInteractor;
              if (failure is! GetStoredEmailDeliveryStateFailure ||
                  failure.exception is! NotFoundEmailDeliveryStateException ||
                  fallback == null) return null;
              return (await fallback.execute(session, accountId).last).fold(
                (_) => null,
                (success) => success is GetStoredEmailStateSuccess ? success.state : null,
              );
            },
            (success) async => success is GetStoredEmailDeliveryStateSuccess ? success.state : null,
          );
        }
        if (storedState == null) return false;
        if (storedState == newState) return true;

        Future<bool> persist(jmap.State state) async {
          if (isAccountStillActive != null && !await isAccountStillActive()) return false;
          if (sharing != null) {
            await sharing.updateEmailDeliveryStateInKeyChain(accountId, state.value);
            return true;
          }
          return _storeEmailDeliveryStateAction(accountId, userName, state);
        }

        final result = await changes.execute(
          session,
          accountId,
          userName,
          storedState,
          propertiesCreated: EmailUtils.getPropertiesForEmailGetMethod(session, accountId),
        ).last;
        return await result.fold<Future<bool>>(
          (failure) async {
            if (failure is GetEmailChangesToPushNotificationFailure && failure.recoveredState != null) {
              await persist(failure.recoveredState!);
            }
            // A recovered cursor is useful for the next push. This one still
            // needs the generic fallback because it could not show its mail.
            return false;
          },
          (success) async {
            if (success is! GetEmailChangesToPushNotificationSuccess ||
                success.accountId != accountId || success.userName != userName) {
              return false;
            }
            if (isAccountStillActive != null && !await isAccountStillActive()) return false;
            if (PlatformInfo.isAndroid && displayNotification) {
              final filter = _getMailboxesNotPutNotificationsInteractor;
              final filterResult = await filter?.execute(session, accountId).last;
              final excluded = filterResult?.fold(
                (_) => null,
                (success) => success is GetMailboxesNotPutNotificationsSuccess
                    ? success.mailboxes.mailboxIds
                    : null,
              );
              await _presentWithSystemNotifications(
                accountId: accountId,
                userName: userName,
                emailList: success.emailList.toEmailsAvailablePushNotification(
                  mailboxIdsNotPutNotifications: excluded,
                ),
                canDisplay: isAccountStillActive,
              );
            }
            // Persist only after notification display has finished.
            final realState = success.newState;
            return realState != null && await persist(realState);
          },
        );
      } catch (error, stackTrace) {
        logError(
          'EmailChangeListener::processPlatformPushNotification: push processing failed',
          exception: error,
          stackTrace: stackTrace,
        );
        return false;
      }
    });
    _platformPushChain = result.then<void>((_) {});
    return result;
  }

  void _updateDeliveryAndNotificationsOnForeground(SynchronizeEmailOnForegroundAction action) {
    if (!PlatformInfo.isAndroid) return;
    _handleRemoveNotificationWhenEmailMarkAsRead(action.newState, action.accountId, action.session);
    // Persist delivery state so the next background FCM push does not replay already-seen changes.
    final userName = action.session?.username;
    if (userName != null) {
      _storeEmailDeliveryStateAction(action.accountId, userName, action.newState);
    }
  }

  void _onPushNotification(PushNotificationAction action) {
    if (FcmUtils.isPlatformPushState(action.newState)) {
      unawaited(processPlatformPushNotification(
        newState: action.newState,
        accountId: action.accountId,
        userName: action.userName,
        session: action.session,
      ));
      return;
    }
    _pushNotificationAction(action.newState, action.accountId, action.userName, action.session);
    if (PlatformInfo.isAndroid && action.storeOfflineBodies) {
      _getNewReceiveEmailFromNotificationAction(action.session, action.accountId, action.newState);
    }
  }

  void _synchronizeEmailOnForegroundAction(jmap.State newState) {
    log('EmailChangeListener::_synchronizeEmailAction():newState: $newState');
    _dashBoardController?.dispatchEmailUIAction(RefreshChangeEmailAction(
      newState: newState,
    ));
  }

  void _pushNotificationAction(jmap.State newState, AccountId accountId, UserName userName, Session? session) {
    final key = _accountKey(accountId);
    _newStateEmailDeliveryByAccount[key] = newState;
    _sessionByAccount[key] = session;
    _accountId = accountId;
    _session = session;
    log('EmailChangeListener::_pushNotificationAction():newState: $newState');

    if (PlatformInfo.isWeb) {
      _storeEmailDeliveryStateAction(accountId, userName, newState);
    } else if (PlatformInfo.isIOS) {
      _storeEmailDeliveryStateAction(accountId, userName, newState);
    } else if (PlatformInfo.isAndroid) {
      _getStoredEmailDeliveryState(accountId, userName);
    }
  }

  void _getStoredEmailDeliveryState(AccountId accountId, UserName userName) {
    if (_getStoredEmailDeliveryStateInteractor != null) {
      consumeState(_getStoredEmailDeliveryStateInteractor!.execute(accountId, userName));
    }
  }

  void _getStoredEmailState(AccountId accountId, Session session) {
    if (_getStoredEmailStateInteractor == null) return;
    consumeState(_getStoredEmailStateInteractor!.execute(session, accountId));
  }

  void _getEmailChangesAction(
    jmap.State state,
    AccountId? accountId,
    Session? session,
    UserName? userName, {
    jmap.State? deliveryState,
  }) {
    final interactor = _getEmailChangesToPushNotificationInteractor;
    if (interactor == null || accountId == null || session == null || userName == null) {
      return;
    }
    consumeState(interactor.execute(
      session,
      accountId,
      userName,
      state,
      propertiesCreated: EmailUtils.getPropertiesForEmailGetMethod(
        session,
        accountId,
      ),
      deliveryState: deliveryState,
    ));
  }

  Future<bool> _storeEmailDeliveryStateAction(AccountId accountId, UserName userName, jmap.State state) async {
    if (FcmUtils.isPlatformPushState(state)) return true;
    final interactor = _storeEmailDeliveryStateInteractor;
    if (interactor == null) return false;
    return _consumeStateAndWait(interactor.execute(accountId, userName, state));
  }

  @override
  Future<bool> handleFailureViewState(Failure failure) async {
    log('EmailChangeListener::_handleFailureViewState(): $failure');
    if (failure is GetNewReceiveEmailFromNotificationFailure &&
        failure.exception is EmailStateNoChangeException) {
      return true;
    }
    if (failure is GetStoredEmailDeliveryStateFailure &&
        failure.exception is NotFoundEmailDeliveryStateException) {
      final accountId = failure.accountId ?? _accountId;
      final session = accountId == null
          ? _session
          : _sessionByAccount[_accountKey(accountId)] ?? _session;
      if (accountId != null && session != null) {
        _getStoredEmailState(accountId, session);
      }
    } else if (failure is GetMailboxesNotPutNotificationsFailure) {
      final key = _accountKey(failure.accountId);
      final pending = _emailsAvailablePushNotificationByAccount.remove(key) ?? const [];
      await _handleLocalPushNotification(
        accountId: failure.accountId,
        userName: failure.userName,
        emailList: pending.toEmailsAvailablePushNotification(),
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> handleSuccessViewState(Success success) async {
    log('EmailChangeListener::_handleSuccessViewState(): $success');
    if (success is GetStoredEmailDeliveryStateSuccess) {
      _handleGetStoredEmailDeliveryStateSuccess(success);
    } else if (success is GetStoredEmailStateSuccess) {
      _getEmailChangesAction(
        success.state,
        success.accountId,
        _sessionByAccount[_accountKey(success.accountId)] ?? _session,
        success.userName,
        deliveryState: _newStateEmailDeliveryByAccount[_accountKey(success.accountId)],
      );
    } else if (success is GetEmailChangesToPushNotificationSuccess) {
      _handleGetEmailChangesToPushNotificationSuccess(success);
    } else if (success is GetMailboxesNotPutNotificationsSuccess) {
      final key = _accountKey(success.accountId);
      final pending = _emailsAvailablePushNotificationByAccount.remove(key) ?? const [];
      await _handleLocalPushNotification(
        accountId: success.accountId,
        userName: success.userName,
        emailList: pending.toEmailsAvailablePushNotification(
          mailboxIdsNotPutNotifications: success.mailboxes.mailboxIds,
        ),
      );
    } else if (success is GetEmailChangesToRemoveNotificationSuccess) {
      _handleRemoveLocalNotification(
        userName: success.userName,
        emailIds: success.emailIds
      );
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

  void _handleGetStoredEmailDeliveryStateSuccess(GetStoredEmailDeliveryStateSuccess success) {
    final key = _accountKey(success.accountId);
    final newState = _newStateEmailDeliveryByAccount[key];
    if (newState == null || newState == success.state) return;
    _getEmailChangesAction(
      success.state,
      success.accountId,
      _sessionByAccount[key] ?? _session,
      success.userName,
      deliveryState: newState,
    );
  }

  void _handleGetEmailChangesToPushNotificationSuccess(GetEmailChangesToPushNotificationSuccess success) {
    final key = _accountKey(success.accountId);
    final latest = _newStateEmailDeliveryByAccount[key];
    final reached = success.deliveryState ?? latest;
    if (reached == null) return;

    final newerPushOwnsCursor = success.deliveryState != null &&
        latest != null &&
        success.deliveryState != latest;
    if (!newerPushOwnsCursor) {
      _storeEmailDeliveryStateAction(
        success.accountId,
        success.userName,
        reached,
      );
    }

    if (PlatformInfo.isAndroid) {
      _handleListEmailToPushNotification(
        accountId: success.accountId,
        userName: success.userName,
        emailList: success.emailList,
      );
    }
  }

  void _rememberEmailsAwaitingMailboxFilter(
    String key,
    List<PresentationEmail> emailList,
  ) {
    final existing = _emailsAvailablePushNotificationByAccount[key];
    if (existing == null) {
      _emailsAvailablePushNotificationByAccount[key] = List.of(emailList);
      return;
    }
    final knownIds = existing.map((email) => email.id).whereType<EmailId>().toSet();
    for (final email in emailList) {
      final id = email.id;
      if (id != null && !knownIds.add(id)) continue;
      existing.add(email);
    }
  }

  void _handleListEmailToPushNotification({
    required AccountId accountId,
    required UserName userName,
    required List<PresentationEmail> emailList,
  }) {
    final key = _accountKey(accountId);
    _rememberEmailsAwaitingMailboxFilter(key, emailList);
    final session = _sessionByAccount[key] ?? _session;
    final interactor = _getMailboxesNotPutNotificationsInteractor;
    if (interactor != null && session != null) {
      consumeState(interactor.execute(session, accountId));
    } else {
      final pending = _emailsAvailablePushNotificationByAccount.remove(key) ?? const [];
      _handleLocalPushNotification(
        accountId: accountId,
        userName: userName,
        emailList: pending.toEmailsAvailablePushNotification(),
      );
    }
  }

  Future<void> _handleLocalPushNotification({
    required AccountId accountId,
    required UserName userName,
    required List<PresentationEmail> emailList
  }) async {
    log('EmailChangeListener::_handleLocalPushNotification(): EMAIL_LENGTH = ${emailList.length}');
    if (emailList.isEmpty) {
      return;
    }
    final present = _presentLocalPush;
    if (present == null) {
      await _presentWithSystemNotifications(accountId: accountId, userName: userName, emailList: emailList);
    } else {
      await present(userName: userName, emailList: emailList);
    }
  }

  void _handleRemoveNotificationWhenEmailMarkAsRead(jmap.State newState, AccountId accountId, Session? session) {
    if (FcmUtils.isPlatformPushState(newState)) return;
    if (_getEmailChangesToRemoveNotificationInteractor != null && session != null) {
      consumeState(_getEmailChangesToRemoveNotificationInteractor!.execute(
        session,
        accountId,
        newState,
        propertiesUpdated: Properties({EmailProperty.keywords}),
      ));
    }
  }

  void _handleRemoveLocalNotification({
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