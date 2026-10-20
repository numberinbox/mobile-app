import 'dart:async';

import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/logging/app_logger_registry.dart';
import 'package:core/utils/logging/log_handler.dart';
import 'package:core/utils/logging/log_level.dart';
import 'package:core/utils/logging/log_record.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/account/authentication_type.dart';
import 'package:model/account/password.dart';
import 'package:model/account/personal_account.dart';
import 'package:model/email/presentation_email.dart';
import 'package:tmail_ui_user/features/home/domain/state/get_session_state.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/state/get_credential_state.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_stored_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/store_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/fcm_message_controller.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/services/fcm_receiver.dart';

import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/session_fixtures.dart';
import 'fcm_receiver_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<GetAuthenticatedAccountInteractor>(),
  MockSpec<GetSessionInteractor>(),
  MockSpec<GetStoredEmailDeliveryStateInteractor>(),
  MockSpec<GetEmailChangesToPushNotificationInteractor>(),
  MockSpec<StoreEmailDeliveryStateInteractor>(),
])

const _platformPushMessage = RemoteMessage(
  messageId: 'message-id',
  data: <String, String>{
    'schemaVersion': '1',
    'eventType': 'mail.delivered',
    'deliveryId': 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1',
    'stalwartAccountId': '29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6',
    'emailId': 'e6948d51214629057f63c03d50e19d31',
  },
);

final _userName = UserName('alice@domain.tld');

void main() {
  late MockGetAuthenticatedAccountInteractor mockGetAuthenticatedAccountInteractor;
  late MockGetSessionInteractor mockGetSessionInteractor;
  late MockGetStoredEmailDeliveryStateInteractor mockGetStoredEmailDeliveryStateInteractor;
  late MockGetEmailChangesToPushNotificationInteractor mockGetEmailChangesToPushNotificationInteractor;
  late MockStoreEmailDeliveryStateInteractor mockStoreEmailDeliveryStateInteractor;

  setUpAll(() {
    Get.testMode = true;
    mockGetAuthenticatedAccountInteractor = MockGetAuthenticatedAccountInteractor();
    mockGetSessionInteractor = MockGetSessionInteractor();
    mockGetStoredEmailDeliveryStateInteractor = MockGetStoredEmailDeliveryStateInteractor();
    mockGetEmailChangesToPushNotificationInteractor = MockGetEmailChangesToPushNotificationInteractor();
    mockStoreEmailDeliveryStateInteractor = MockStoreEmailDeliveryStateInteractor();
    Get.put<GetAuthenticatedAccountInteractor>(mockGetAuthenticatedAccountInteractor);
    Get.put<GetSessionInteractor>(mockGetSessionInteractor);
    Get.put<GetStoredEmailDeliveryStateInteractor>(mockGetStoredEmailDeliveryStateInteractor);
    Get.put<GetEmailChangesToPushNotificationInteractor>(mockGetEmailChangesToPushNotificationInteractor);
    Get.put<StoreEmailDeliveryStateInteractor>(mockStoreEmailDeliveryStateInteractor);
  });

  setUp(() {
    clearInteractions(mockGetAuthenticatedAccountInteractor);
    clearInteractions(mockGetSessionInteractor);
    clearInteractions(mockGetStoredEmailDeliveryStateInteractor);
    clearInteractions(mockGetEmailChangesToPushNotificationInteractor);
    clearInteractions(mockStoreEmailDeliveryStateInteractor);

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
          apiUrl: 'https://api.numberinbox.com',
        ),
        stateChange: null,
      ));
    });
    when(mockGetSessionInteractor.execute(stateChange: null)).thenAnswer((_) async* {
      yield dartz.Right<Failure, Success>(GetSessionSuccess(
        SessionFixtures.aliceSession,
        stateChange: null,
      ));
    });
    when(mockGetStoredEmailDeliveryStateInteractor.execute(any, any)).thenAnswer((_) async* {
      yield dartz.Right<Failure, Success>(
          GetStoredEmailDeliveryStateSuccess(State('stored-delivery-state')));
    });
    when(mockGetEmailChangesToPushNotificationInteractor.execute(
      any,
      any,
      any,
      any,
      propertiesCreated: anyNamed('propertiesCreated'),
      propertiesUpdated: anyNamed('propertiesUpdated'),
    )).thenAnswer((_) async* {
      yield dartz.Right<Failure, Success>(GetEmailChangesToPushNotificationSuccess(
        AccountFixtures.aliceAccountId,
        _userName,
        <PresentationEmail>[],
        newState: State('server-new-state-changes'),
      ));
    });
  });

  tearDownAll(Get.reset);

  Future<void> deliverPlatformPush() => handleFirebaseBackgroundMessage(
        _platformPushMessage,
        ensureBackgroundInitialized: () async {},
        refreshSentryConfiguration: (_) async {},
        invalidateSentryConfiguration: (_) async {},
      );

  test('refreshes Sentry consent for every background message', () async {
    var initializationCalls = 0;
    var consentRefreshCalls = 0;
    var handledMessages = 0;
    const message = RemoteMessage(messageId: 'message-id');

    Future<void> handle() => handleFirebaseBackgroundMessage(
          message,
          ensureBackgroundInitialized: () async {
            initializationCalls++;
          },
          refreshSentryConfiguration: (_) async {
            consentRefreshCalls++;
          },
          handleMessage: (_) {
            handledMessages++;
          },
        );

    await handle();
    await handle();

    expect(initializationCalls, 2);
    expect(consentRefreshCalls, 2);
    expect(handledMessages, 2);
  });

  test('continues handling when Sentry refresh times out', () async {
    var invalidationCalls = 0;
    var handledMessages = 0;
    FcmSentrySetupCancellation? timedOutCancellation;
    final refreshNeverCompletes = Completer<void>();
    const message = RemoteMessage(messageId: 'message-id');

    await handleFirebaseBackgroundMessage(
      message,
      ensureBackgroundInitialized: () async {},
      refreshSentryConfiguration: (_) => refreshNeverCompletes.future,
      invalidateSentryConfiguration: (cancellation) async {
        timedOutCancellation = cancellation;
        cancellation.cancel();
        invalidationCalls++;
      },
      handleMessage: (_) {
        handledMessages++;
      },
      sentryRefreshTimeout: Duration.zero,
    );

    expect(invalidationCalls, 1);
    expect(timedOutCancellation?.isCancelled, isTrue);
    expect(handledMessages, 1);
  });

  test(
    'WHEN the background callback delivers a platform push\n'
    'THEN it awaits the account lookup before returning',
    () async {
      final accountLookupStarted = Completer<void>();
      final releaseAccountLookup = Completer<void>();
      when(mockGetAuthenticatedAccountInteractor.execute()).thenAnswer((_) async* {
        accountLookupStarted.complete();
        await releaseAccountLookup.future;
      });

      final callback = deliverPlatformPush();
      await accountLookupStarted.future.timeout(const Duration(seconds: 2));

      var callbackCompleted = false;
      final trackedCallback = callback.whenComplete(() => callbackCompleted = true);
      await pumpEventQueue();
      expect(callbackCompleted, isFalse);

      releaseAccountLookup.complete();
      await trackedCallback;
      expect(callbackCompleted, isTrue);
    },
  );

  test(
    'WHEN the background callback delivers a platform push\n'
    'THEN it awaits the JMAP email-change fetch and the delivery cursor update',
    () async {
      final changesFetchStarted = Completer<void>();
      final releaseChangesFetch = Completer<void>();
      when(mockGetEmailChangesToPushNotificationInteractor.execute(
        any,
        any,
        any,
        any,
        propertiesCreated: anyNamed('propertiesCreated'),
        propertiesUpdated: anyNamed('propertiesUpdated'),
      )).thenAnswer((_) async* {
        changesFetchStarted.complete();
        await releaseChangesFetch.future;
        yield dartz.Right<Failure, Success>(GetEmailChangesToPushNotificationSuccess(
          AccountFixtures.aliceAccountId,
          _userName,
          <PresentationEmail>[],
          newState: State('server-new-state-changes'),
        ));
      });
      final cursorWriteStarted = Completer<void>();
      final releaseCursorWrite = Completer<void>();
      when(mockStoreEmailDeliveryStateInteractor.execute(any, any, any)).thenAnswer((_) async* {
        cursorWriteStarted.complete();
        await releaseCursorWrite.future;
        yield dartz.Right<Failure, Success>(StoreEmailDeliveryStateSuccess());
      });

      final callback = deliverPlatformPush();
      await changesFetchStarted.future.timeout(const Duration(seconds: 2));

      var callbackCompleted = false;
      final trackedCallback = callback.whenComplete(() => callbackCompleted = true);
      await pumpEventQueue();
      expect(callbackCompleted, isFalse);

      releaseChangesFetch.complete();
      await cursorWriteStarted.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(callbackCompleted, isFalse,
          reason: 'the FCM callback must not complete before the delivery-cursor write finishes');
      verify(mockStoreEmailDeliveryStateInteractor.execute(
        AccountFixtures.aliceAccountId,
        _userName,
        State('server-new-state-changes'),
      )).called(1);

      releaseCursorWrite.complete();
      await trackedCallback;
      expect(callbackCompleted, isTrue);
    },
  );

  group('token acquisition logging contract (M3)', () {
    _CapturingLogHandler logs = _CapturingLogHandler();

    setUp(() {
      logs = _CapturingLogHandler();
      AppLoggerRegistry.instance.registerHandler(logs);
    });

    tearDown(() => AppLoggerRegistry.instance.resetForTesting());

    test(
      'WHEN the initial FCM token is acquired\n'
      'THEN the token never reaches a log sink',
      () async {
        const tokenMarker = 'TOKENTOKEN-MARKER-startup-fcm-device-token';

        await FcmReceiver.acquireFcmToken(
          () async => tokenMarker,
          delayBetweenAttempts: (_) => Duration.zero,
        );

        expect(
          logs.everything,
          isNot(contains(tokenMarker)),
          reason: 'the FCM device token is a credential and must never be '
              'written to a log sink',
        );
        expect(
          logs.records,
          isNotEmpty,
          reason: 'acquisition must stay diagnosable without the value',
        );
      },
    );

    test(
      'WHEN token acquisition keeps failing\n'
      'THEN the failure is reported without the throwable payload',
      () async {
        const failureSecret = 'token-channel-secret-zzz999';

        final token = await FcmReceiver.acquireFcmToken(
          () => Future.error(Exception(failureSecret)),
          delayBetweenAttempts: (_) => Duration.zero,
        );

        expect(token, isNull,
            reason: 'exhausted retries yield no token instead of crashing');
        expect(
          logs.everything,
          isNot(contains(failureSecret)),
          reason: 'the throwable payload must never reach a log sink',
        );
        expect(
          logs.records.where((record) => record.level == Level.error),
          isNotEmpty,
          reason: 'the exhaustion must still be reported, as a fixed event name',
        );
      },
    );
  });
}

/// Everything a log sink would ever see: the message plus the folded
/// exception, extras and stack trace of every record.
class _CapturingLogHandler extends LogHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  String get handlerKey => 'capturing-log-handler-for-tests';

  @override
  void handle(LogRecord record) => records.add(record);

  String get everything =>
      records.map((record) => record.rawMessage).join('\n');
}
