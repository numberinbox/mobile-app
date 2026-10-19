import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/sentry/sentry_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/account/authentication_type.dart';
import 'package:model/account/password.dart';
import 'package:model/account/personal_account.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tmail_ui_user/features/caching/entries/sentry_configuration_cache.dart';
import 'package:tmail_ui_user/features/caching/entries/sentry_user_cache.dart';
import 'package:tmail_ui_user/features/caching/manager/sentry_configuration_cache_manager.dart';
import 'package:tmail_ui_user/features/home/domain/state/get_session_state.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/state/get_credential_state.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/numberinbox_push_message.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/fcm_message_controller.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/services/fcm_service.dart';

import 'fcm_message_controller_test.mocks.dart';

import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/session_fixtures.dart';

class _FakeCacheManager implements SentryConfigurationCacheManager {
  _FakeCacheManager({
    this.configuration,
    this.user,
  });

  SentryConfigurationCache? configuration;
  SentryUserCache? user;
  int userReads = 0;

  @override
  Future<SentryConfigurationCache> getSentryConfiguration() async {
    if (configuration == null) throw StateError('config not found');
    return configuration!;
  }

  @override
  Future<SentryUserCache> getSentryUser() async {
    userReads++;
    if (user == null) throw StateError('user not found');
    return user!;
  }

  @override
  Future<void> saveSentryConfiguration(
    SentryConfigurationCache sentryConfigurationCache,
  ) async {}

  @override
  Future<void> saveSentryUser(SentryUserCache sentryUserCache) async {}

  @override
  Future<SentryConfigurationCache?> updateSentryReportingAllowed(
    bool isReportingAllowed,
  ) async =>
      null;

  @override
  Future<void> clearSentryConfiguration() async {}
}

class _FakeSentryRuntime extends FcmSentryRuntime {
  _FakeSentryRuntime({
    this.onInitialize,
    this.onSetReportingConsent,
    bool isAvailable = false,
  }) : _isAvailable = isAvailable;

  final Future<void> Function()? onInitialize;
  final Future<void> Function(bool? consent)? onSetReportingConsent;
  bool _isAvailable;
  final consents = <bool?>[];
  final initializedConfigs = <SentryConfig>[];
  final users = <SentryUser>[];
  SentryUser? currentUser;
  int clearUserCalls = 0;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<void> setReportingConsent(bool? consent) async {
    consents.add(consent);
    if (consent == false) _isAvailable = false;
    await onSetReportingConsent?.call(consent);
    if (consent == true) _isAvailable = true;
  }

  @override
  Future<void> initialize(SentryConfig sentryConfig) async {
    initializedConfigs.add(sentryConfig);
    await onInitialize?.call();
  }

  @override
  void setUser(SentryUser user) {
    currentUser = user;
    users.add(user);
  }

  @override
  void clearUser() {
    currentUser = null;
    clearUserCalls++;
  }
}

SentryConfigurationCache _configuration({
  required bool isAvailable,
  required bool isReportingAllowed,
  String release = '1.0.0',
}) =>
    SentryConfigurationCache(
      dsn: 'https://test@sentry.io/123',
      environment: 'test',
      release: release,
      tracesSampleRate: 0.1,
      profilesSampleRate: 0.1,
      enableLogs: true,
      isDebug: false,
      attachScreenshot: false,
      isAvailable: isAvailable,
      sessionSampleRate: null,
      onErrorSampleRate: null,
      enableFramesTracking: true,
      dist: null,
      isReportingAllowed: isReportingAllowed,
    );

SentryUserCache _user(String id) => SentryUserCache(
      id: id,
      name: '',
      username: '',
      email: '',
    );

@GenerateNiceMocks([
  MockSpec<GetAuthenticatedAccountInteractor>(),
  MockSpec<DynamicUrlInterceptors>(),
  MockSpec<AuthorizationInterceptors>(),
  MockSpec<GetSessionInteractor>(),
])

// Mirrors the FCM data map built by the platform's FcmPushGateway.
const _backendMailDeliveredPayload = <String, dynamic>{
  'schemaVersion': '1',
  'eventType': 'mail.delivered',
  'deliveryId': 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1',
  'stalwartAccountId': '29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6',
  'emailId': 'e6948d51214629057f63c03d50e19d31',
};
const _platformApiUrl = 'https://api.numberinbox.com';

void main() {
  test('background isolate does not initialize Sentry without consent', () async {
    final cacheManager = _FakeCacheManager(configuration: _configuration(
      isAvailable: true,
      isReportingAllowed: false,
    ));
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false]);
    expect(sentryRuntime.clearUserCalls, 1);
    expect(sentryRuntime.initializedConfigs, isEmpty);
    expect(cacheManager.userReads, 0);
  });

  test('initializes Sentry and restores the cached user when reporting is allowed', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.initializedConfigs.single.isReportingAllowed, isTrue);
    expect(sentryRuntime.users.single.id, 'account-a');
  });

  test('reuses a running Sentry SDK when the cached config is unchanged', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.clearUserCalls, 2);
    expect(cacheManager.userReads, 2);
  });

  test('reinitializes a running Sentry SDK when the cached config changes', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    cacheManager.configuration = _configuration(
      isAvailable: true,
      isReportingAllowed: true,
      release: '2.0.0',
    );
    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true, false, true]);
    expect(
      sentryRuntime.initializedConfigs.map((config) => config.release),
      ['1.0.0', '2.0.0'],
    );
  });

  test('clears a stale user without restarting an unchanged running SDK', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    cacheManager.user = null;
    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.clearUserCalls, 2);
    expect(sentryRuntime.users, hasLength(1));
    expect(sentryRuntime.currentUser, isNull);
  });

  test('closes a running Sentry SDK when the cached config becomes unreadable', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    cacheManager.configuration = null;
    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true, false]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.isAvailable, isFalse);
  });

  test('does not initialize Sentry when the cached config is unavailable', () async {
    final cacheManager = _FakeCacheManager(configuration: _configuration(
      isAvailable: false,
      isReportingAllowed: true,
    ));
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false]);
    expect(sentryRuntime.clearUserCalls, 1);
    expect(sentryRuntime.initializedConfigs, isEmpty);
    expect(cacheManager.userReads, 0);
  });

  test('does not initialize Sentry when the config is not cached', () async {
    final cacheManager = _FakeCacheManager();
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false]);
    expect(sentryRuntime.clearUserCalls, 1);
    expect(sentryRuntime.initializedConfigs, isEmpty);
    expect(cacheManager.userReads, 0);
  });

  test('initializes Sentry without identity when the user is not cached', () async {
    final cacheManager = _FakeCacheManager(configuration: _configuration(
      isAvailable: true,
      isReportingAllowed: true,
    ));
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.users, isEmpty);
    expect(cacheManager.userReads, 1);
  });

  test('re-reads consent and fails closed for a later push', () async {
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime();

    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    cacheManager.configuration = _configuration(
      isAvailable: true,
      isReportingAllowed: false,
    );
    await FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );

    expect(sentryRuntime.consents, [false, true, false]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
    expect(sentryRuntime.clearUserCalls, 2);
    expect(cacheManager.userReads, 1);
  });

  test('does not enable Sentry when consent changes during setup', () async {
    final initializeStarted = Completer<void>();
    final finishInitialize = Completer<void>();
    final cacheManager = _FakeCacheManager(
      configuration: _configuration(
        isAvailable: true,
        isReportingAllowed: true,
      ),
      user: _user('account-a'),
    );
    final sentryRuntime = _FakeSentryRuntime(
      onInitialize: () async {
        initializeStarted.complete();
        await finishInitialize.future;
      },
    );

    final setup = FcmMessageController.instance.setUpSentryConfiguration(
      cacheManager: cacheManager,
      sentryRuntime: sentryRuntime,
    );
    await initializeStarted.future;
    cacheManager.configuration = _configuration(
      isAvailable: true,
      isReportingAllowed: false,
    );
    finishInitialize.complete();
    await setup;

    expect(sentryRuntime.consents, [false, false]);
    expect(sentryRuntime.initializedConfigs, hasLength(1));
  });

  test(
    'does not enable Sentry when setup is cancelled during initialization',
    () async {
      final initializeStarted = Completer<void>();
      final finishInitialize = Completer<void>();
      final cacheManager = _FakeCacheManager(
        configuration: _configuration(
          isAvailable: true,
          isReportingAllowed: true,
        ),
        user: _user('account-a'),
      );
      final sentryRuntime = _FakeSentryRuntime(
        onInitialize: () async {
          initializeStarted.complete();
          await finishInitialize.future;
        },
      );
      final cancellation = FcmSentrySetupCancellation();

      final setup = FcmMessageController.instance.setUpSentryConfiguration(
        cacheManager: cacheManager,
        sentryRuntime: sentryRuntime,
        cancellation: cancellation,
      );
      await initializeStarted.future;
      final invalidation = FcmMessageController.instance.invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
      await invalidation;
      finishInitialize.complete();
      await setup;

      expect(cancellation.isCancelled, isTrue);
      expect(sentryRuntime.consents, [false, false, false]);
      expect(sentryRuntime.consents.last, isFalse);
    },
  );

  test(
    'revokes a consent transition that completes after cancellation',
    () async {
      final enableStarted = Completer<void>();
      final finishEnable = Completer<void>();
      final cacheManager = _FakeCacheManager(
        configuration: _configuration(
          isAvailable: true,
          isReportingAllowed: true,
        ),
        user: _user('account-a'),
      );
      final sentryRuntime = _FakeSentryRuntime(
        onSetReportingConsent: (consent) async {
          if (consent == true) {
            enableStarted.complete();
            await finishEnable.future;
          }
        },
      );
      final cancellation = FcmSentrySetupCancellation();

      final setup = FcmMessageController.instance.setUpSentryConfiguration(
        cacheManager: cacheManager,
        sentryRuntime: sentryRuntime,
        cancellation: cancellation,
      );
      await enableStarted.future;
      final invalidation = FcmMessageController.instance.invalidateSentrySetup(
        cancellation,
        sentryRuntime: sentryRuntime,
      );
      await invalidation;
      finishEnable.complete();
      await setup;

      expect(sentryRuntime.consents, [false, true, false, false]);
      expect(sentryRuntime.consents.last, isFalse);
      expect(sentryRuntime.clearUserCalls, 3);
    },
  );

  group('FcmMessageController::handlePushPayload (NumberInbox platform pushes)', () {
    setUp(() {
      Get.testMode = true;
      FcmMessageController.instance.resetPendingPlatformPushForTesting();
      addTearDown(Get.reset);
    });

    test(
      'WHEN the backend delivers a mail.delivered push\n'
      'THEN resolves the authenticated account once so the mailbox is refreshed',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        when(mockGetAuthenticatedAccountInteractor.execute())
            .thenAnswer((_) async* {});

        FcmMessageController.instance
            .handlePushPayload(_backendMailDeliveredPayload);
        await pumpEventQueue();

        verify(mockGetAuthenticatedAccountInteractor.execute()).called(1);
      },
    );

    test(
      'WHEN the push is held mail instead of delivered mail\n'
      'THEN the app does not resolve the account at all',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        when(mockGetAuthenticatedAccountInteractor.execute())
            .thenAnswer((_) async* {});

        FcmMessageController.instance.handlePushPayload(
          <String, dynamic>{
            ..._backendMailDeliveredPayload,
            'eventType': 'mail.held',
          },
        );
        await pumpEventQueue();

        verifyNever(mockGetAuthenticatedAccountInteractor.execute());
      },
    );

    test(
      'WHEN the push carries no identifiers (notification-only payload)\n'
      'THEN the app does not resolve the account at all',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        when(mockGetAuthenticatedAccountInteractor.execute())
            .thenAnswer((_) async* {});

        FcmMessageController.instance.handlePushPayload(
          const <String, dynamic>{
            'schemaVersion': '1',
            'eventType': 'mail.delivered',
          },
        );
        await pumpEventQueue();

        verifyNever(mockGetAuthenticatedAccountInteractor.execute());
      },
    );

    test(
      'WHEN the account is basic-auth and the session resolves\n'
      'THEN the push is dispatched through the change pipeline with a non-server push state',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        final mockDynamicUrlInterceptors = MockDynamicUrlInterceptors();
        final mockAuthorizationInterceptors = MockAuthorizationInterceptors();
        final mockGetSessionInteractor = MockGetSessionInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        Get.put<DynamicUrlInterceptors>(mockDynamicUrlInterceptors);
        Get.put<AuthorizationInterceptors>(mockAuthorizationInterceptors);
        Get.put<GetSessionInteractor>(mockGetSessionInteractor);
        addTearDown(Get.reset);
        when(mockGetAuthenticatedAccountInteractor.execute()).thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(GetCredentialViewState(
            Uri.parse('https://jmap.numberinbox.com'),
            UserName('+66841234567@numberinbox.com'),
            Password('stalwart-password'),
            PersonalAccount(
              'personal-account-id',
              AuthenticationType.basic,
              isSelected: true,
              accountId: AccountFixtures.aliceAccountId,
              apiUrl: _platformApiUrl,
            ),
            stateChange: null,
          ));
        });
        when(mockGetSessionInteractor.execute(
            stateChange: null)).thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(GetSessionSuccess(
            SessionFixtures.aliceSession,
            stateChange: null,
          ));
        });
        when(mockAuthorizationInterceptors.authenticationType)
            .thenReturn(AuthenticationType.basic);

        FcmMessageController.instance
            .handlePushPayload(_backendMailDeliveredPayload);
        await pumpEventQueue();

        verify(mockGetSessionInteractor.execute(stateChange: null)).called(1);
        verify(mockDynamicUrlInterceptors
            .setJmapUrl('https://jmap.numberinbox.com')).called(1);
        verify(mockAuthorizationInterceptors.setBasicAuthorization(
          UserName('+66841234567@numberinbox.com'),
          Password('stalwart-password'),
        )).called(1);
        verify(mockDynamicUrlInterceptors.changeBaseUrl(any)).called(2);
      },
    );

    test(
      'WHEN the app is in the foreground and FCM delivers a message through onMessage\n'
      'THEN the controller routes the payload to the mailbox refresh pipeline',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        when(mockGetAuthenticatedAccountInteractor.execute())
            .thenAnswer((_) async* {});

        FcmService.instance.initialStreamController();
        addTearDown(FcmService.instance.closeStream);
        FcmMessageController.instance.initialize();
        await pumpEventQueue();

        FcmService.instance
            .handleFirebaseForegroundMessage(RemoteMessage(
              data: Map<String, String>.from(_backendMailDeliveredPayload),
            ));
        await pumpEventQueue();

        verify(mockGetAuthenticatedAccountInteractor.execute()).called(1);
      },
    );

    test(
      'WHEN the background FCM callback delivers a mail.delivered push\n'
      'THEN the controller handles it immediately through the platform push pipeline',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        when(mockGetAuthenticatedAccountInteractor.execute())
            .thenAnswer((_) async* {});

        FcmService.instance.initialStreamController();
        addTearDown(FcmService.instance.closeStream);
        FcmMessageController.instance.initialize();
        await pumpEventQueue();

        FcmService.instance.handleFirebaseBackgroundMessage(RemoteMessage(
          data: Map<String, String>.from(_backendMailDeliveredPayload),
        ));
        await pumpEventQueue();

        verify(mockGetAuthenticatedAccountInteractor.execute()).called(1);
      },
    );

    test(
      'WHEN the push belongs to a previously signed-in account\n'
      'THEN it is dropped before deriving any state or dispatching',
      () async {
        final mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
        final mockDynamicUrlInterceptors = MockDynamicUrlInterceptors();
        final mockAuthorizationInterceptors = MockAuthorizationInterceptors();
        final mockGetSessionInteractor = MockGetSessionInteractor();
        Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
        Get.put<DynamicUrlInterceptors>(mockDynamicUrlInterceptors);
        Get.put<AuthorizationInterceptors>(mockAuthorizationInterceptors);
        Get.put<GetSessionInteractor>(mockGetSessionInteractor);
        addTearDown(Get.reset);
        when(mockGetAuthenticatedAccountInteractor.execute()).thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(GetCredentialViewState(
            Uri.parse('https://jmap.numberinbox.com'),
            UserName('+66841234567@numberinbox.com'),
            Password('stalwart-password'),
            PersonalAccount(
              'personal-account-id',
              AuthenticationType.basic,
              isSelected: true,
              accountId: AccountFixtures.aliceAccountId,
              apiUrl: _platformApiUrl,
            ),
            stateChange: null,
          ));
        });
        when(mockGetSessionInteractor.execute(
            stateChange: null)).thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(GetSessionSuccess(
            SessionFixtures.aliceSession,
            stateChange: null,
          ));
        });
        when(mockAuthorizationInterceptors.authenticationType)
            .thenReturn(AuthenticationType.basic);

        FcmMessageController.instance.handlePushPayload(
          <String, dynamic>{
            ..._backendMailDeliveredPayload,
            'stalwartAccountId': 'account-id-from-an-earlier-session',
          },
        );
        await pumpEventQueue();

        verify(mockDynamicUrlInterceptors.changeBaseUrl(any)).called(1);
      },
    );

    test(
      'WHEN a platform push is dispatched\n'
      'THEN the foreground push maps to the Email key and the background push to the EmailDelivery key\n'
      'AND the email id is never used as a state token',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData(
          _backendMailDeliveredPayload,
        )!;

        expect(
          FcmMessageController.mapTypeStateForPlatformPush(
            pushMessage,
            stateToken: 'derived-real-state',
            isForeground: true,
          ),
          <String, dynamic>{'Email': 'derived-real-state'},
        );
        expect(
          FcmMessageController.mapTypeStateForPlatformPush(
            pushMessage,
            stateToken: 'derived-real-state',
            isForeground: false,
          ),
          <String, dynamic>{'EmailDelivery': 'derived-real-state'},
        );
      },
    );
  });
}
