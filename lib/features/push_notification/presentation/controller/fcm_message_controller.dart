import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/platform_info.dart';
import 'package:core/utils/sentry/sentry_config.dart';
import 'package:core/utils/sentry/sentry_manager.dart';
import 'package:fcm/model/type_name.dart';
import 'package:flutter/foundation.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/push/state_change.dart';
import 'package:model/model.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tmail_ui_user/features/caching/config/hive_cache_config.dart';
import 'package:tmail_ui_user/features/caching/entries/sentry_configuration_cache.dart';
import 'package:tmail_ui_user/features/caching/extensions/sentry_cache_extensions.dart';
import 'package:tmail_ui_user/features/caching/manager/sentry_configuration_cache_manager.dart';
import 'package:tmail_ui_user/features/home/domain/extensions/session_extensions.dart';
import 'package:tmail_ui_user/features/home/domain/state/get_session_state.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/home/presentation/home_bindings.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/state/get_credential_state.dart';
import 'package:tmail_ui_user/features/login/domain/state/get_authenticated_account_state.dart';
import 'package:tmail_ui_user/features/login/domain/state/get_stored_token_oidc_state.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/bindings/mailbox_dashboard_bindings.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/numberinbox_push_message.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/bindings/fcm_interactor_bindings.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/fcm_token_controller.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/push_base_controller.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/extensions/state_change_extension.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/listener/email_change_listener.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/listener/label_change_listener.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/listener/mailbox_change_listener.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/services/fcm_service.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/utils/fcm_utils.dart';
import 'package:tmail_ui_user/main/bindings/main_bindings.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class FcmSentryRuntime {
  const FcmSentryRuntime();

  bool get isAvailable => SentryManager.instance.isSentryAvailable;

  Future<void> setReportingConsent(bool? consent) async {
    SentryManager.instance.setSentryReportingConsent(consent);
    await SentryManager.instance.pendingLifecycleTransition;
  }

  Future<void> initialize(SentryConfig sentryConfig) {
    return SentryManager.instance.initializeWithSentryConfig(sentryConfig);
  }

  void setUser(SentryUser user) {
    SentryManager.instance.setUser(user);
  }

  void clearUser() {
    SentryManager.instance.clearUser();
  }
}

class FcmSentrySetupCancellation {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}

class FcmMessageController extends PushBaseController {
  GetAuthenticatedAccountInteractor? _getAuthenticatedAccountInteractor;
  DynamicUrlInterceptors? _dynamicUrlInterceptors;
  AuthorizationInterceptors? _authorizationInterceptors;
  GetSessionInteractor? _getSessionInteractor;
  SentryConfigurationCache? _appliedSentryConfiguration;

  NumberInboxPushMessage? _pendingPlatformPushMessage;
  bool _isForegroundPlatformPush = false;

  FcmMessageController._internal();

  static final FcmMessageController _instance = FcmMessageController._internal();

  static FcmMessageController get instance => _instance;

  @override
  void initialize({AccountId? accountId, Session? session}) {
    try {
      super.initialize(accountId: accountId, session: session);

      _listenTokenStream();
      _listenBackgroundMessageStream();
      _listenForegroundMessageStream();
    } catch (e, st) {
      logError(
        'FcmMessageController::initialize: throw exception',
        exception: e,
        stackTrace: st,
      );
    }
  }

  void _listenForegroundMessageStream() {
    FcmService.instance.foregroundMessageStreamController?.stream.listen(
      (messageData) => handlePushPayload(messageData, isForeground: true),
      onError: (e, st) {
        logError(
          'FcmMessageController::_listenForegroundMessageStream',
          exception: e,
          stackTrace: st,
        );
      },
    );
  }

  void _listenBackgroundMessageStream() {
    final backgroundMessageStream = FcmService.instance.backgroundMessageStreamController?.stream;
    if (backgroundMessageStream == null) return;

    // NumberInbox platform pushes must be handled immediately: the background
    // FCM callback returns as soon as the message is queued, so a debounce
    // timer may never fire before the isolate is torn down.
    backgroundMessageStream
        .where((messageData) => NumberInboxPushMessage.tryParseFromFcmData(messageData) != null)
        .listen(
          handlePushPayload,
          onError: (e, st) {
            logError(
              'FcmMessageController::_listenBackgroundMessageStream',
              exception: e,
              stackTrace: st,
            );
          },
        );

    // Legacy Twake JMAP pushes keep the debounce that coalesces bursts of
    // state-change messages.
    backgroundMessageStream
        .where((messageData) => NumberInboxPushMessage.tryParseFromFcmData(messageData) == null)
        .debounceTime(const Duration(
          milliseconds: FcmUtils.durationBackgroundMessageComing,
        ))
        .listen(
          _handleBackgroundMessageAction,
          onError: (e, st) {
            logError(
              'FcmMessageController::_listenBackgroundMessageStream',
              exception: e,
              stackTrace: st,
            );
          },
        );
  }

  void _listenTokenStream() {
    FcmService.instance.fcmTokenStreamController
      ?.stream
      .debounceTime(const Duration(milliseconds: FcmUtils.durationRefreshToken))
      .listen(
        FcmTokenController.instance.onFcmTokenChanged,
        onError: (e, st) {
          logError(
            'FcmMessageController::_listenTokenStream',
            exception: e,
            stackTrace: st,
          );
        },
      );
  }

  void _handleBackgroundMessageAction(Map<String, dynamic> payloadData) async {
    logTrace('FcmMessageController::_handleBackgroundMessageAction():payloadData keys: ${payloadData.keys.toList()}');
    final stateChange = FcmUtils.instance.convertFirebaseDataMessageToStateChange(payloadData);
    if (stateChange == null) {
      logTrace('FcmMessageController::_handleBackgroundMessageAction(): stateChange is null');
      return;
    } else {
      logTrace('FcmMessageController::_handleBackgroundMessageAction(): stateChange: ${stateChange.toString()}');
    }
    _getAuthenticatedAccount(stateChange: stateChange);
  }

  Future<void> initialAppConfig() async {
    try {
      await MainBindings().dependencies();
      await HiveCacheConfig.instance.setUp();

      HomeBindings().dependencies();
      MailboxDashBoardBindings().dependencies();
      FcmInteractorBindings().dependencies();

      _getInteractorBindings();
    } catch (e, st) {
      logError(
        'FcmMessageController::initialAppConfig: throw exception',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> setUpSentryConfiguration({
    SentryConfigurationCacheManager? cacheManager,
    FcmSentryRuntime sentryRuntime = const FcmSentryRuntime(),
    FcmSentrySetupCancellation? cancellation,
  }) async {
    final cancellationToken = cancellation ?? FcmSentrySetupCancellation();
    try {
      await _runSentrySetup(
        cacheManager: cacheManager ??
            getBinding<SentryConfigurationCacheManager>(),
        sentryRuntime: sentryRuntime,
        cancellation: cancellationToken,
      );
    } catch (e, st) {
      await _handleSentrySetupFailure(
        e,
        st,
        cancellationToken,
        sentryRuntime,
      );
    }
  }

  Future<void> _runSentrySetup({
    required SentryConfigurationCacheManager? cacheManager,
    required FcmSentryRuntime sentryRuntime,
    required FcmSentrySetupCancellation cancellation,
  }) async {
    if (await _invalidateSentrySetupIfCancelled(
      cancellation,
      sentryRuntime,
    )) {
      return;
    }
    if (cacheManager == null) {
      logWarning('FcmMessageController::setUpSentryConfiguration: SentryConfigurationCacheManager is null');
      await invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
      return;
    }

    final configCache = await _loadAllowedSentryConfiguration(cacheManager);
    if (configCache == null || cancellation.isCancelled) {
      await invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
      return;
    }

    final canReuseSentryRuntime = sentryRuntime.isAvailable &&
        _appliedSentryConfiguration == configCache;
    if (canReuseSentryRuntime) {
      await _refreshRunningSentrySetup(
        cacheManager,
        configCache,
        sentryRuntime,
        cancellation,
      );
      return;
    }

    await _applySentryConfiguration(
      cacheManager,
      configCache,
      sentryRuntime,
      cancellation,
    );
  }

  Future<void> _refreshRunningSentrySetup(
    SentryConfigurationCacheManager cacheManager,
    SentryConfigurationCache configCache,
    FcmSentryRuntime sentryRuntime,
    FcmSentrySetupCancellation cancellation,
  ) async {
    await _restoreSentryUser(cacheManager, sentryRuntime, cancellation);
    if (!await _isSentryConfigurationStillAllowed(
      cacheManager,
      configCache,
      cancellation,
    )) {
      await invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
    }
  }

  Future<void> _applySentryConfiguration(
    SentryConfigurationCacheManager cacheManager,
    SentryConfigurationCache configCache,
    FcmSentryRuntime sentryRuntime,
    FcmSentrySetupCancellation cancellation,
  ) async {
    await sentryRuntime.setReportingConsent(false);
    _appliedSentryConfiguration = null;
    if (await _invalidateSentrySetupIfCancelled(
      cancellation,
      sentryRuntime,
    )) {
      return;
    }

    await _restoreSentryUser(cacheManager, sentryRuntime, cancellation);
    if (await _invalidateSentrySetupIfCancelled(
      cancellation,
      sentryRuntime,
    )) {
      return;
    }

    await sentryRuntime.initialize(configCache.toSentryConfig());
    if (!await _isSentryConfigurationStillAllowed(
      cacheManager,
      configCache,
      cancellation,
    )) {
      await invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
      return;
    }

    await sentryRuntime.setReportingConsent(true);
    if (await _invalidateSentrySetupIfCancelled(
      cancellation,
      sentryRuntime,
    )) {
      return;
    }
    if (sentryRuntime.isAvailable) {
      _appliedSentryConfiguration = configCache;
    }
  }

  Future<bool> _invalidateSentrySetupIfCancelled(
    FcmSentrySetupCancellation cancellation,
    FcmSentryRuntime sentryRuntime,
  ) async {
    if (!cancellation.isCancelled) return false;
    await invalidateSentrySetup(
      cancellation,
      sentryRuntime: sentryRuntime,
    );
    return true;
  }

  Future<SentryConfigurationCache?> _loadAllowedSentryConfiguration(
    SentryConfigurationCacheManager cacheManager,
  ) async {
    final SentryConfigurationCache configCache;
    try {
      configCache = await cacheManager.getSentryConfiguration();
    } catch (e) {
      logWarning('FcmMessageController::setUpSentryConfiguration: SentryConfiguration not cached: $e');
      return null;
    }

    if (!configCache.isAvailable) {
      logWarning('FcmMessageController::setUpSentryConfiguration: SentryConfiguration is not available');
      return null;
    }
    if (!configCache.isReportingAllowed) {
      logTrace('FcmMessageController::setUpSentryConfiguration: Sentry reporting is not allowed');
      return null;
    }
    return configCache;
  }

  Future<void> _restoreSentryUser(
    SentryConfigurationCacheManager cacheManager,
    FcmSentryRuntime sentryRuntime,
    FcmSentrySetupCancellation cancellation,
  ) async {
    sentryRuntime.clearUser();
    try {
      final userCache = await cacheManager.getSentryUser();
      if (!cancellation.isCancelled) {
        sentryRuntime.setUser(userCache.toSentryUser());
      }
    } catch (e) {
      logTrace('FcmMessageController::setUpSentryConfiguration: Sentry user not cached: $e');
      // Acceptable — Sentry will start without user context
    }
  }

  Future<bool> _isSentryConfigurationStillAllowed(
    SentryConfigurationCacheManager cacheManager,
    SentryConfigurationCache expectedConfig,
    FcmSentrySetupCancellation cancellation,
  ) async {
    if (cancellation.isCancelled) return false;
    final latestConfig = await cacheManager.getSentryConfiguration();
    if (cancellation.isCancelled) return false;
    if (!latestConfig.isAvailable) return false;
    if (!latestConfig.isReportingAllowed) return false;
    return latestConfig == expectedConfig;
  }

  Future<void> _handleSentrySetupFailure(
    Object error,
    StackTrace stackTrace,
    FcmSentrySetupCancellation cancellation,
    FcmSentryRuntime sentryRuntime,
  ) async {
    try {
      await invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
    } catch (invalidationError, invalidationStackTrace) {
      logError(
        'FcmMessageController::setUpSentryConfiguration: Cannot invalidate failed setup',
        exception: invalidationError,
        stackTrace: invalidationStackTrace,
      );
    }
    logError(
      'FcmMessageController::setUpSentryConfiguration: throw exception',
      exception: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> invalidateSentrySetup(
    FcmSentrySetupCancellation cancellation, {
    FcmSentryRuntime sentryRuntime = const FcmSentryRuntime(),
  }) {
    cancellation.cancel();
    _appliedSentryConfiguration = null;
    sentryRuntime.clearUser();
    return sentryRuntime.setReportingConsent(false);
  }

  void _getInteractorBindings() {
    _getAuthenticatedAccountInteractor = getBinding<GetAuthenticatedAccountInteractor>();
    _dynamicUrlInterceptors = getBinding<DynamicUrlInterceptors>();
    _authorizationInterceptors = getBinding<AuthorizationInterceptors>();
    _getSessionInteractor = getBinding<GetSessionInteractor>();

    FcmTokenController.instance.initialBindingInteractor();
  }

  void _getAuthenticatedAccount({required StateChange stateChange}) {
    if (_getAuthenticatedAccountInteractor != null) {
      consumeState(_getAuthenticatedAccountInteractor!.execute(stateChange: stateChange));
    } else {
      logTrace(
        'GetAuthenticatedAccountInteractor is null',
      );
    }
  }

  /// Entry point for pushes produced by the NumberInbox platform API
  /// (FCM `data` fields: schemaVersion, eventType, deliveryId,
  /// stalwartAccountId, emailId).
  ///
  /// The payload has no JMAP state string, so after the authenticated account
  /// is resolved the push is dispatched as a synthesized state change built by
  /// [mapTypeStateForPlatformPush]; authoritative state is then fetched from
  /// the server through the existing change listeners.
  ///
  /// The returned future completes once the account, the session and the
  /// dispatch have been processed: the Android background callback awaits it
  /// because the OS may tear the isolate down as soon as the callback returns.
  Future<void> handlePushPayload(Map<String, dynamic> payloadData, {bool isForeground = false}) async {
    try {
      final pushMessage = NumberInboxPushMessage.tryParseFromFcmData(payloadData);
      if (pushMessage == null) {
        logTrace('FcmMessageController::handlePushPayload(): payload is not a NumberInbox push: ${payloadData.keys.toList()}');
        return;
      }
      logTrace('FcmMessageController::handlePushPayload(): pushMessage: $pushMessage');

      _getInteractorBindings();
      if (_getAuthenticatedAccountInteractor == null) {
        logTrace('FcmMessageController::handlePushPayload(): GetAuthenticatedAccountInteractor is null');
        return;
      }

      _pendingPlatformPushMessage = pushMessage;
      _isForegroundPlatformPush = isForeground;
      await _resolvePlatformPushAccountAndDispatch(
        pushMessage: pushMessage,
        isForeground: isForeground);
    } catch (e, st) {
      _dropPendingPlatformPush();
      logError(
        'FcmMessageController::handlePushPayload: throw exception',
        exception: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _resolvePlatformPushAccountAndDispatch({
    required NumberInboxPushMessage pushMessage,
    required bool isForeground
  }) async {
    final accountViewState = await _getAuthenticatedAccountInteractor!.execute().last;
    await accountViewState.fold(
      (failure) async => handleFailureViewState(failure),
      (success) async {
        if (success is GetCredentialViewState) {
          await _handleGetAccountByBasicAuthSuccess(
            success,
            pushMessage: pushMessage,
            isForeground: isForeground);
        } else if (success is GetStoredTokenOidcSuccess) {
          await _handleGetAccountByOidcSuccess(
            success,
            pushMessage: pushMessage,
            isForeground: isForeground);
        } else {
          logTrace('FcmMessageController::_resolvePlatformPushAccountAndDispatch: no authenticated account found');
          _dropPendingPlatformPush();
        }
      },
    );
  }

  /// Maps a parsed platform push onto the same `{TypeName: state}` shape the
  /// JMAP websocket flow dispatches through, so a foreground push refreshes
  /// the mailbox (Email) and a background push feeds the notification
  /// pipeline (EmailDelivery).
  ///
  /// [stateToken] must be a non-server token created by
  /// [FcmUtils.createPlatformPushState]: the pushed email id is not a state
  /// token, and the cached/displayed state would make the pipeline skip its
  /// work on a state comparison.
  @visibleForTesting
  static Map<String, dynamic> mapTypeStateForPlatformPush(
    NumberInboxPushMessage pushMessage,
    {required String stateToken, required bool isForeground}
  ) {
    final typeName = isForeground ? TypeName.emailType : TypeName.emailDelivery;
    return <String, dynamic>{typeName.value: stateToken};
  }

  @visibleForTesting
  void resetPendingPlatformPushForTesting() {
    _pendingPlatformPushMessage = null;
    _isForegroundPlatformPush = false;
  }

  void _dropPendingPlatformPush() {
    _pendingPlatformPushMessage = null;
    _isForegroundPlatformPush = false;
  }

  bool _isPlatformPushForAccount(NumberInboxPushMessage pushMessage, AccountId accountId) {
    final matches = accountId.id.value == pushMessage.stalwartAccountId;
    if (!matches) {
      logTrace('FcmMessageController::_isPlatformPushForAccount: the platform push belongs to another account (${pushMessage.stalwartAccountId} != ${accountId.id.value}), drop it');
    }
    return matches;
  }

  /// Re-resolves the active authenticated account and checks that the
  /// platform push still belongs to it. Returns false when the credentials
  /// are gone (signed out) or the active account no longer matches the push.
  Future<bool> _isPushAccountStillActive(NumberInboxPushMessage pushMessage) async {
    final getAuthenticatedAccountInteractor = _getAuthenticatedAccountInteractor;
    if (getAuthenticatedAccountInteractor == null) {
      logTrace('FcmMessageController::_isPushAccountStillActive: GetAuthenticatedAccountInteractor is null, drop the pending platform push');
      return false;
    }
    try {
      final accountViewState = await getAuthenticatedAccountInteractor.execute().last;
      return await accountViewState.fold(
        (failure) async {
          logTrace('FcmMessageController::_isPushAccountStillActive: the push account is no longer authenticated (${failure.runtimeType}), drop the pending platform push');
          return false;
        },
        (success) async {
          if (success is GetCredentialViewState) {
            final accountId = success.personalAccount.accountId;
            return accountId != null &&
                _isPlatformPushForAccount(pushMessage, accountId);
          } else if (success is GetStoredTokenOidcSuccess) {
            final accountId = success.personalAccount.accountId;
            return accountId != null &&
                _isPlatformPushForAccount(pushMessage, accountId);
          }
          logTrace('FcmMessageController::_isPushAccountStillActive: no authenticated account found, drop the pending platform push');
          return false;
        },
      );
    } catch (e) {
      logTrace('FcmMessageController::_isPushAccountStillActive: re-check failed: $e, drop the pending platform push');
      return false;
    }
  }

  Future<void> _dispatchPlatformPushAction({
    required NumberInboxPushMessage pushMessage,
    required String apiUrl,
    required AccountId accountId,
    required UserName userName,
    required bool isForeground,
    required Session session,
  }) async {
    _dropPendingPlatformPush();
    _dynamicUrlInterceptors?.changeBaseUrl(apiUrl);
    final pushState = FcmUtils.createPlatformPushState();

    if (!isForeground) {
      // Background pushes are awaited end to end: the Android background
      // isolate may be torn down as soon as the FCM callback returns, so the
      // JMAP fetch and the notification work must have completed by then.
      await EmailChangeListener.instance.processPlatformPushNotification(
        newState: pushState,
        accountId: accountId,
        userName: userName,
        session: session);
      return;
    }

    final mapTypeState = mapTypeStateForPlatformPush(
      pushMessage,
      stateToken: pushState.value,
      isForeground: isForeground,
    );
    logTrace('FcmMessageController::_dispatchPlatformPushAction: Mapping platform push to action ${mapTypeState.toString()}');
    mappingTypeStateToAction(
      mapTypeState,
      accountId,
      userName,
      emailChangeListener: EmailChangeListener.instance,
      mailboxChangeListener: MailboxChangeListener.instance,
      labelChangeListener: LabelChangeListener.instance,
      isForeground: isForeground,
      session: session);
  }

  Future<void> _handleGetAccountByOidcSuccess(
    GetStoredTokenOidcSuccess storedTokenOidcSuccess,
    {
      NumberInboxPushMessage? pushMessage,
      bool isForeground = false
    }
  ) async {
    _dynamicUrlInterceptors?.setJmapUrl(storedTokenOidcSuccess.baseUrl.toString());
    _authorizationInterceptors?.setTokenAndAuthorityOidc(
      newToken: storedTokenOidcSuccess.tokenOidc,
      newConfig: storedTokenOidcSuccess.oidcConfiguration,
    );
    if (PlatformInfo.isAndroid) {
      _dynamicUrlInterceptors?.changeBaseUrl(storedTokenOidcSuccess.baseUrl.toString());
      if (pushMessage != null) {
        await _getSessionActionAndWait(
          stateChange: null,
          pushMessage: pushMessage,
          isForeground: isForeground);
      } else {
        _getSessionAction(stateChange: storedTokenOidcSuccess.stateChange);
      }
    } else {
      await _dispatchPushOnNonAndroid(
        apiUrl: storedTokenOidcSuccess.personalAccount.apiUrl,
        accountId: storedTokenOidcSuccess.personalAccount.accountId,
        username: storedTokenOidcSuccess.personalAccount.userName,
        stateChange: storedTokenOidcSuccess.stateChange,
        pushMessage: pushMessage,
        isForeground: isForeground,
      );
    }
  }

  Future<void> _handleGetAccountByBasicAuthSuccess(
    GetCredentialViewState credentialViewState,
    {
      NumberInboxPushMessage? pushMessage,
      bool isForeground = false
    }
  ) async {
    _dynamicUrlInterceptors?.setJmapUrl(credentialViewState.baseUrl.toString());
    _authorizationInterceptors?.setBasicAuthorization(
      credentialViewState.userName,
      credentialViewState.password,
    );
    if (PlatformInfo.isAndroid) {
      _dynamicUrlInterceptors?.changeBaseUrl(credentialViewState.baseUrl.toString());
      if (pushMessage != null) {
        await _getSessionActionAndWait(
          stateChange: null,
          pushMessage: pushMessage,
          isForeground: isForeground);
      } else {
        _getSessionAction(stateChange: credentialViewState.stateChange);
      }
    } else {
      await _dispatchPushOnNonAndroid(
        apiUrl: credentialViewState.personalAccount.apiUrl,
        accountId: credentialViewState.personalAccount.accountId,
        username: credentialViewState.personalAccount.userName,
        stateChange: credentialViewState.stateChange,
        pushMessage: pushMessage,
        isForeground: isForeground,
      );
    }
  }

  Future<void> _dispatchPushOnNonAndroid({
    required String? apiUrl,
    required AccountId? accountId,
    required UserName? username,
    required StateChange? stateChange,
    NumberInboxPushMessage? pushMessage,
    bool isForeground = false,
  }) async {
    final platformPushMessage = pushMessage;
    if (platformPushMessage != null) {
      if (accountId == null || username == null) {
        logTrace('FcmMessageController::_dispatchPushOnNonAndroid: account id or username is null, drop the platform push');
        return;
      }
      if (!_isPlatformPushForAccount(platformPushMessage, accountId)) {
        return;
      }
      // Route the platform push through the session funnel (Android and
      // desktop) so the dispatch always has the resolved JMAP session.
      if (apiUrl != null) {
        _dynamicUrlInterceptors?.changeBaseUrl(apiUrl);
      }
      await _getSessionActionAndWait(
        stateChange: null,
        pushMessage: platformPushMessage,
        isForeground: isForeground);
      return;
    }
    _dynamicUrlInterceptors?.changeBaseUrl(apiUrl);
    final canPush = accountId != null && username != null && stateChange != null;
    if (!canPush) {
      logTrace('FcmMessageController::_dispatchPushOnNonAndroid: accountId or username or stateChange is null');
      return;
    }
    _pushActionFromRemoteMessageBackground(
      accountId: accountId,
      userName: username,
      stateChange: stateChange,
    );
  }

  /// Resolves the JMAP session and dispatches the platform push, completing
  /// only after the dispatch has run.
  Future<void> _getSessionActionAndWait({
    StateChange? stateChange,
    required NumberInboxPushMessage pushMessage,
    bool isForeground = false,
  }) async {
    final getSessionInteractor = _getSessionInteractor;
    if (getSessionInteractor == null) {
      logTrace('FcmMessageController::_getSessionActionAndWait: GetSessionInteractor is null');
      _dropPendingPlatformPush();
      return;
    }
    final sessionViewState = await getSessionInteractor.execute(stateChange: stateChange).last;
    await sessionViewState.fold(
      (failure) async => handleFailureViewState(failure),
      (success) async {
        if (success is GetSessionSuccess) {
          await _handleGetSessionSuccess(
            success,
            pushMessage: pushMessage,
            isForeground: isForeground);
        } else {
          _dropPendingPlatformPush();
        }
      },
    );
  }

  void _getSessionAction({StateChange? stateChange}) {
    if (_getSessionInteractor != null) {
      consumeState(_getSessionInteractor!.execute(stateChange: stateChange));
    } else {
      logTrace('FcmMessageController::_getSessionAction: _getSessionInteractor is null');
    }
  }

  Future<void> _handleGetSessionSuccess(
    GetSessionSuccess success,
    {
      NumberInboxPushMessage? pushMessage,
      bool isForeground = false
    }
  ) async {
    try {
      final apiUrl = success.session.getQualifiedApiUrl(baseUrl: _dynamicUrlInterceptors?.jmapUrl);

      if (apiUrl.isEmpty) {
        logTrace(
          'FcmMessageController::_handleGetSessionSuccess: Api url is empty',
        );
        return;
      }

      // A platform push carries its own context end to end so overlapping
      // pushes for different accounts never overwrite each other's pending
      // work; only legacy flows still consult the shared pending fields.
      final platformPushMessage = pushMessage ?? _pendingPlatformPushMessage;
      final isForegroundPlatformPush = pushMessage != null
          ? isForeground
          : _isForegroundPlatformPush;
      if (platformPushMessage != null) {
        final accountId = success.session.accountId;
        if (!_isPlatformPushForAccount(platformPushMessage, accountId)) {
          _dropPendingPlatformPush();
          return;
        }
        // The session fetch is asynchronous: a sign-out or an account switch
        // can complete while it is in flight. Re-verify that the active
        // account is still the account the push belongs to before spending
        // any mail fetch or notification work on it.
        final isActiveAccountUnchanged =
            await _isPushAccountStillActive(platformPushMessage);
        if (!isActiveAccountUnchanged) {
          _dropPendingPlatformPush();
          return;
        }
        await _dispatchPlatformPushAction(
          pushMessage: platformPushMessage,
          apiUrl: apiUrl,
          accountId: accountId,
          userName: success.session.username,
          isForeground: isForegroundPlatformPush,
          session: success.session);
        return;
      }

      final stateChange = success.stateChange;

      if (stateChange != null) {
        _dynamicUrlInterceptors?.changeBaseUrl(apiUrl);

        _pushActionFromRemoteMessageBackground(
          accountId: success.session.accountId,
          userName: success.session.username,
          stateChange: stateChange,
          session: success.session);
      } else {
        logTrace(
          'FcmMessageController::_handleGetSessionSuccess: state change is null',
        );
      }
    } catch (e, st) {
      _dropPendingPlatformPush();
      logError(
        'FcmMessageController::_handleGetSessionSuccess:',
        exception: e,
        stackTrace: st,
      );
    }
  }

  void _pushActionFromRemoteMessageBackground({
    required AccountId accountId,
    required UserName userName,
    required StateChange stateChange,
    Session? session
  }) {
    final mapTypeState = stateChange.getMapTypeState(accountId);
    logTrace('FcmMessageController::_pushActionFromRemoteMessageBackground: Mapping type state to action ${mapTypeState.toString()}');
    mappingTypeStateToAction(
      mapTypeState,
      accountId,
      userName,
      emailChangeListener: EmailChangeListener.instance,
      mailboxChangeListener: MailboxChangeListener.instance,
      labelChangeListener: LabelChangeListener.instance,
      isForeground: false,
      session: session);
  }

  @override
  void handleFailureViewState(Failure failure) {
    log('FcmMessageController::_handleFailureViewState(): $failure');
    if (failure is GetStoredTokenOidcFailure) {
      logTrace('FcmMessageController::GetStoredTokenOidcFailure: Get stored token oidc is failed');
    } else if (failure is GetSessionFailure) {
      logTrace('FcmMessageController::GetSessionFailure: Get session is failed');
    } else if (failure is GetCredentialFailure || failure is GetAuthenticatedAccountFailure) {
      logTrace('FcmMessageController::GetCredential/GetAuthenticatedAccount Failure: an account is not authenticated, drop the pending platform push');
      _pendingPlatformPushMessage = null;
      _isForegroundPlatformPush = false;
    }
  }

  @override
  void handleSuccessViewState(Success success) {
    log('FcmMessageController::_handleSuccessViewState(): $success');
    if (success is GetSessionSuccess) {
      unawaited(_handleGetSessionSuccess(success));
    } else if (success is GetStoredTokenOidcSuccess) {
      unawaited(_handleGetAccountByOidcSuccess(success));
    } else if (success is GetCredentialViewState) {
      unawaited(_handleGetAccountByBasicAuthSuccess(success));
    }
  }
}
