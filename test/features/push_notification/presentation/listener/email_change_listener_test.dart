import 'dart:async';

import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:fcm/model/type_name.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/model.dart';
import 'package:tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/fcm_exception.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_new_receive_email_from_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_stored_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/store_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_new_receive_email_from_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/action/push_notification_state_change_action.dart';
import 'package:tmail_ui_user/features/email/domain/state/get_stored_state_email_state.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/get_stored_email_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/listener/email_change_listener.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/utils/fcm_utils.dart';

import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/session_fixtures.dart';
import 'email_change_listener_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<MailboxDashBoardController>(),
  MockSpec<GetStoredEmailDeliveryStateInteractor>(),
  MockSpec<StoreEmailDeliveryStateInteractor>(),
  MockSpec<GetEmailChangesToPushNotificationInteractor>(),
  MockSpec<GetStoredEmailStateInteractor>(),
  MockSpec<GetNewReceiveEmailFromNotificationInteractor>(),
])

/// The state the app already displays and has cached locally when the push
/// arrives.
const _cachedAndDisplayedState = '2c9f1b12-b35a-43e6-9af2-0106fb53a943';

/// Bob's persisted delivery cursor, distinct from Alice's so a cross-account
/// contamination is visible in the captured interactor arguments.
const _bobStoredDeliveryState = '5a2c8b90-1d4e-4f6a-9c8b-3e7f6a5d4c2b';

/// The real Email state returned by the JMAP Email/changes response.
const _serverNewState = 'd3a4f1c2-9e8b-4a17-8f01-2b6f7c1d5e93';

/// A real server state pushed by the legacy websocket flow, distinct from the
/// cached one so the legacy changes pipeline still runs.
const _incomingLegacyServerState = 'f1e2d3c4-b5a6-9781-2f3e-4d5c6b7a9e81';

final _userName = UserName('alice@domain.tld');

final _bobUserName = UserName('bob@domain.tld');

void main() {
  late MockMailboxDashBoardController mockDashBoardController;
  late MockGetStoredEmailDeliveryStateInteractor mockGetStoredEmailDeliveryStateInteractor;
  late MockStoreEmailDeliveryStateInteractor mockStoreEmailDeliveryStateInteractor;
  late MockGetEmailChangesToPushNotificationInteractor mockGetEmailChangesToPushNotificationInteractor;
  late MockGetStoredEmailStateInteractor mockGetStoredEmailStateInteractor;
  late MockGetNewReceiveEmailFromNotificationInteractor mockGetNewReceiveEmailFromNotificationInteractor;

  setUpAll(() {
    Get.testMode = true;
    mockDashBoardController = MockMailboxDashBoardController();
    mockGetStoredEmailDeliveryStateInteractor = MockGetStoredEmailDeliveryStateInteractor();
    mockStoreEmailDeliveryStateInteractor = MockStoreEmailDeliveryStateInteractor();
    mockGetEmailChangesToPushNotificationInteractor = MockGetEmailChangesToPushNotificationInteractor();
    mockGetStoredEmailStateInteractor = MockGetStoredEmailStateInteractor();
    mockGetNewReceiveEmailFromNotificationInteractor = MockGetNewReceiveEmailFromNotificationInteractor();
    // Get.put/Get.reset run the GetX lifecycle; the mock's fakes would throw.
    when(mockDashBoardController.onStart).thenReturn(InternalFinalCallback<void>(callback: () {}));
    when(mockDashBoardController.onDelete).thenReturn(InternalFinalCallback<void>(callback: () {}));
    Get.put<MailboxDashBoardController>(mockDashBoardController);
    Get.put<GetStoredEmailDeliveryStateInteractor>(mockGetStoredEmailDeliveryStateInteractor);
    Get.put<StoreEmailDeliveryStateInteractor>(mockStoreEmailDeliveryStateInteractor);
    Get.put<GetEmailChangesToPushNotificationInteractor>(mockGetEmailChangesToPushNotificationInteractor);
    Get.put<GetStoredEmailStateInteractor>(mockGetStoredEmailStateInteractor);
    Get.put<GetNewReceiveEmailFromNotificationInteractor>(mockGetNewReceiveEmailFromNotificationInteractor);
  });

  setUp(() {
    clearInteractions(mockDashBoardController);
    clearInteractions(mockGetStoredEmailDeliveryStateInteractor);
    clearInteractions(mockStoreEmailDeliveryStateInteractor);
    clearInteractions(mockGetEmailChangesToPushNotificationInteractor);
    clearInteractions(mockGetStoredEmailStateInteractor);
    clearInteractions(mockGetNewReceiveEmailFromNotificationInteractor);
    when(mockGetStoredEmailDeliveryStateInteractor.execute(any, any)).thenAnswer((_) async* {
      yield dartz.Right<Failure, Success>(
          GetStoredEmailDeliveryStateSuccess(State(_cachedAndDisplayedState)));
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
        newState: State(_serverNewState),
      ));
    });
    // The default setUp stub returns a stored state; the missing-cursor test
    // overrides this per case below.
  });

  tearDownAll(Get.reset);

  group('EmailChangeListener::platform push cross-account isolation (overlapping pushes)', () {
    test(
      'WHEN two overlapping background pushes for different accounts resolve in reversed order\n'
      'THEN each push processes its mail changes against its own session, account and user name\n'
      'AND neither push advances the other account cursor',
      () async {
        final alicePushState = FcmUtils.createPlatformPushState();
        final bobPushState = FcmUtils.createPlatformPushState();
        final aliceDeliveryGate = Completer<void>();
        when(mockGetStoredEmailDeliveryStateInteractor.execute(
          AccountFixtures.aliceAccountId,
          _userName,
        )).thenAnswer((_) => Stream.fromFuture(aliceDeliveryGate.future).asyncExpand(
            (_) => Stream.value(dartz.Right<Failure, Success>(
                GetStoredEmailDeliveryStateSuccess(State(_cachedAndDisplayedState))))));
        when(mockGetStoredEmailDeliveryStateInteractor.execute(
          AccountFixtures.bobAccountId,
          _bobUserName,
        )).thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(
              GetStoredEmailDeliveryStateSuccess(State(_bobStoredDeliveryState)));
        });

        final aliceProcessing = EmailChangeListener.instance.processPlatformPushNotification(
          newState: alicePushState,
          accountId: AccountFixtures.aliceAccountId,
          userName: _userName,
          session: SessionFixtures.aliceSession);
        // Alice is now suspended on her slow stored-state lookup.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Bob is queued behind Alice: the listener serializes platform pushes
        // so Bob's fields cannot overwrite Alice's pending work.
        final bobProcessing = EmailChangeListener.instance.processPlatformPushNotification(
          newState: bobPushState,
          accountId: AccountFixtures.bobAccountId,
          userName: _bobUserName,
          session: SessionFixtures.bobSession);
        aliceDeliveryGate.complete();
        await bobProcessing;
        await aliceProcessing;
        await pumpEventQueue();

        verify(mockGetEmailChangesToPushNotificationInteractor.execute(
          SessionFixtures.bobSession,
          AccountFixtures.bobAccountId,
          _bobUserName,
          State(_bobStoredDeliveryState),
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).called(1);
        verify(mockGetEmailChangesToPushNotificationInteractor.execute(
          SessionFixtures.aliceSession,
          AccountFixtures.aliceAccountId,
          _userName,
          State(_cachedAndDisplayedState),
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).called(1);
      },
    );
  });

  group('EmailChangeListener::platform push recovery (delivery cursor missing)', () {
    test(
      'WHEN the first push arrives with no delivery cursor persisted yet\n'
      'THEN the listener recovers the Email state cursor and processes the changes from it\n'
      'AND the non-server platform push state is never stored',
      () async {
        final platformPushState = FcmUtils.createPlatformPushState();
        when(mockGetStoredEmailDeliveryStateInteractor.execute(any, any))
            .thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(GetStoredEmailDeliveryStateFailure(
            const NotFoundEmailDeliveryStateException(),
          ));
        });
        when(mockGetStoredEmailStateInteractor.execute(any, any))
            .thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(
              GetStoredEmailStateSuccess(State(_cachedAndDisplayedState)));
        });

        EmailChangeListener.instance.dispatchActions([
          PushNotificationAction(
            TypeName.emailDelivery,
            platformPushState,
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            _userName,
          ),
        ]);
        await pumpEventQueue();

        verify(mockGetStoredEmailStateInteractor.execute(
          SessionFixtures.aliceSession,
          AccountFixtures.aliceAccountId,
        )).called(1);
        verify(mockGetEmailChangesToPushNotificationInteractor.execute(
          SessionFixtures.aliceSession,
          AccountFixtures.aliceAccountId,
          _userName,
          State(_cachedAndDisplayedState),
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).called(1);
        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(
          any,
          any,
          platformPushState,
        ));
      },
    );

    test(
      'WHEN the persisted delivery cursor is stale and the server rejects the Email/changes request\n'
      'THEN nothing is stored, no local notification is dispatched\n'
      'AND no platform push state or half-processed state leaks into the cursor',
      () async {
        final platformPushState = FcmUtils.createPlatformPushState();
        when(mockGetStoredEmailDeliveryStateInteractor.execute(any, any))
            .thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(GetStoredEmailDeliveryStateFailure(
            const NotFoundEmailDeliveryStateException(),
          ));
        });
        when(mockGetStoredEmailStateInteractor.execute(any, any))
            .thenAnswer((_) async* {
          yield dartz.Right<Failure, Success>(
              GetStoredEmailStateSuccess(State(_cachedAndDisplayedState)));
        });
        when(mockGetEmailChangesToPushNotificationInteractor.execute(
          any,
          any,
          any,
          any,
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(
              GetEmailChangesToPushNotificationFailure(Exception('stateId not found')));
        });

        EmailChangeListener.instance.dispatchActions([
          PushNotificationAction(
            TypeName.emailDelivery,
            platformPushState,
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            _userName,
          ),
        ]);
        await pumpEventQueue();

        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(any, any, any));
        verifyNever(mockDashBoardController.dispatchEmailUIAction(any));
      },
    );
  });

  group('EmailChangeListener::platform push (state unknown to the server)', () {
    test(
      'WHEN the cached Email state equals the displayed state\n'
      'THEN a foreground platform push still asks the mailbox to refresh with a state it cannot match',
      () {
        final platformPushState = FcmUtils.createPlatformPushState();

        EmailChangeListener.instance.dispatchActions([
          SynchronizeEmailOnForegroundAction(
            TypeName.emailType,
            platformPushState,
            AccountFixtures.aliceAccountId,
            SessionFixtures.aliceSession,
          ),
        ]);

        final refreshAction = verify(mockDashBoardController.dispatchEmailUIAction(captureAny))
            .captured
            .single as RefreshChangeEmailAction;
        expect(refreshAction.newState, platformPushState);
        expect(refreshAction.newState, isNot(equals(State(_cachedAndDisplayedState))));
        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(any, any, any));
      },
    );

    test(
      'WHEN the saved delivery state equals the cached and displayed state\n'
      'THEN a background platform push still processes the email changes from that real state\n'
      'AND the delivery cursor advances to the real JMAP state\n'
      'AND the non-server platform push state is never stored',
      () async {
        final platformPushState = FcmUtils.createPlatformPushState();
        EmailChangeListener.instance.dispatchActions([
          PushNotificationAction(
            TypeName.emailDelivery,
            platformPushState,
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            _userName,
          ),
        ]);
        await pumpEventQueue();

        verify(mockGetEmailChangesToPushNotificationInteractor.execute(
          SessionFixtures.aliceSession,
          AccountFixtures.aliceAccountId,
          _userName,
          State(_cachedAndDisplayedState),
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).called(1);
        verify(mockStoreEmailDeliveryStateInteractor.execute(
          AccountFixtures.aliceAccountId,
          _userName,
          State(_serverNewState),
        )).called(1);
        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(
          any,
          any,
          platformPushState,
        ));
      },
    );
  });

  group('EmailChangeListener::platform push stays silent (Android already displayed the system notification)', () {
    const localNotificationChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');

    final PresentationEmail discoveredEmail = PresentationEmail(
      id: EmailId(Id('e6948d51214629057f63c03d50e19d31')),
      subject: 'Your one-time password',
      preview: 'Your code is 551144',
      from: {EmailAddress('IT department', 'attacker@evil.example')},
    );

    Future<List<MethodCall>> mockLocalNotificationChannel() async {
      final showCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(localNotificationChannel, (call) async {
        showCalls.add(call);
        return null;
      });
      return showCalls;
    }

    void unmockLocalNotificationChannel() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(localNotificationChannel, null);
    }

    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test(
      'WHEN a background platform push discovers new emails\n'
      'THEN the listener processes the changes and advances the cursor\n'
      'AND it posts no app-generated local notification of its own\n'
      'AND no subject, preview or sender data reach the notification channel',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final showCalls = await mockLocalNotificationChannel();
        try {
          when(mockGetEmailChangesToPushNotificationInteractor.execute(
            any,
            any,
            any,
            any,
            propertiesCreated: anyNamed('propertiesCreated'),
            propertiesUpdated: anyNamed('propertiesUpdated'),
          )).thenAnswer((_) async* {
            yield dartz.Right<Failure, Success>(
                GetEmailChangesToPushNotificationSuccess(
              AccountFixtures.aliceAccountId,
              _userName,
              <PresentationEmail>[discoveredEmail],
              newState: State(_serverNewState),
            ));
          });

          await EmailChangeListener.instance.processPlatformPushNotification(
            newState: FcmUtils.createPlatformPushState(),
            accountId: AccountFixtures.aliceAccountId,
            userName: _userName,
            session: SessionFixtures.aliceSession);
          await pumpEventQueue();

          expect(
            showCalls.where((call) => call.method == 'show'),
            isEmpty,
            reason: 'Android already displayed the system notification for '
                'the push; a duplicate rich app notification would show the '
                'email subject, preview and sender on the lock screen.',
          );
          verify(mockGetEmailChangesToPushNotificationInteractor.execute(
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            _userName,
            State(_cachedAndDisplayedState),
            propertiesCreated: anyNamed('propertiesCreated'),
            propertiesUpdated: anyNamed('propertiesUpdated'),
          )).called(1);
          verify(mockStoreEmailDeliveryStateInteractor.execute(
            AccountFixtures.aliceAccountId,
            _userName,
            State(_serverNewState),
          )).called(1);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          unmockLocalNotificationChannel();
        }
      },
    );

    test(
      'WHEN a legacy websocket-delivered push (real JMAP state, no system notification) discovers new emails\n'
      'THEN the listener still posts its local notification of its own',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final showCalls = await mockLocalNotificationChannel();
        try {
          when(mockGetEmailChangesToPushNotificationInteractor.execute(
            any,
            any,
            any,
            any,
            propertiesCreated: anyNamed('propertiesCreated'),
            propertiesUpdated: anyNamed('propertiesUpdated'),
          )).thenAnswer((_) async* {
            yield dartz.Right<Failure, Success>(
                GetEmailChangesToPushNotificationSuccess(
              AccountFixtures.aliceAccountId,
              _userName,
              <PresentationEmail>[discoveredEmail],
              newState: State(_serverNewState),
            ));
          });

          EmailChangeListener.instance.dispatchActions([
            PushNotificationAction(
              TypeName.emailDelivery,
              State(_incomingLegacyServerState),
              SessionFixtures.aliceSession,
              AccountFixtures.aliceAccountId,
              _userName,
            ),
          ]);
          await pumpEventQueue();

          expect(
            showCalls.where((call) => call.method == 'show'),
            isNotEmpty,
            reason: 'Legacy pushes arrive without a system notification, the '
                'app-generated local notification is their only display.',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
          unmockLocalNotificationChannel();
        }
      },
    );
  });

  group('EmailChangeListener::platform push completion reporting', () {
    test(
      'WHEN the delivery cursor lookup fails\n'
      'THEN the push reports incomplete so the delivery is not marked processed',
      () async {
        when(mockGetStoredEmailDeliveryStateInteractor.execute(any, any))
            .thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(GetStoredEmailDeliveryStateFailure(
            Exception('delivery cache unavailable'),
          ));
        });

        final completed = await EmailChangeListener.instance
            .processPlatformPushNotification(
          newState: FcmUtils.createPlatformPushState(),
          accountId: AccountFixtures.aliceAccountId,
          userName: _userName,
          session: SessionFixtures.aliceSession,
        );

        expect(completed, isFalse);
        verifyNever(mockGetEmailChangesToPushNotificationInteractor.execute(
          any,
          any,
          any,
          any,
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        ));
        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(any, any, any));
      },
    );

    test(
      'WHEN the Email/changes fetch fails\n'
      'THEN the push reports incomplete and the cursor is not advanced',
      () async {
        when(mockGetEmailChangesToPushNotificationInteractor.execute(
          any,
          any,
          any,
          any,
          propertiesCreated: anyNamed('propertiesCreated'),
          propertiesUpdated: anyNamed('propertiesUpdated'),
        )).thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(
              GetEmailChangesToPushNotificationFailure(Exception('backend down')));
        });

        final completed = await EmailChangeListener.instance
            .processPlatformPushNotification(
          newState: FcmUtils.createPlatformPushState(),
          accountId: AccountFixtures.aliceAccountId,
          userName: _userName,
          session: SessionFixtures.aliceSession,
        );

        expect(completed, isFalse);
        verifyNever(mockStoreEmailDeliveryStateInteractor.execute(any, any, any));
      },
    );

    test(
      'WHEN the delivery cursor write fails\n'
      'THEN the push reports incomplete so a redelivery can retry it',
      () async {
        when(mockStoreEmailDeliveryStateInteractor.execute(any, any, any))
            .thenAnswer((_) async* {
          yield dartz.Left<Failure, Success>(
              StoreEmailDeliveryStateFailure(Exception('disk full')));
        });

        final completed = await EmailChangeListener.instance
            .processPlatformPushNotification(
          newState: FcmUtils.createPlatformPushState(),
          accountId: AccountFixtures.aliceAccountId,
          userName: _userName,
          session: SessionFixtures.aliceSession,
        );

        expect(completed, isFalse);
      },
    );

    test(
      'WHEN a foreground push cannot fetch the new emails\n'
      'THEN the foreground pipeline reports incomplete',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          when(mockGetNewReceiveEmailFromNotificationInteractor.execute(
            session: anyNamed('session'),
            accountId: anyNamed('accountId'),
            userName: anyNamed('userName'),
            newState: anyNamed('newState'),
          )).thenAnswer((_) async* {
            yield dartz.Left<Failure, Success>(
                GetNewReceiveEmailFromNotificationFailure(
                    Exception('network down')));
          });
          when(mockStoreEmailDeliveryStateInteractor.execute(any, any, any))
              .thenAnswer((_) async* {
            yield dartz.Right<Failure, Success>(StoreEmailDeliveryStateSuccess());
          });

          final completed = await EmailChangeListener.instance
              .processForegroundPlatformPushNotification(
            newState: State(_incomingLegacyServerState),
            accountId: AccountFixtures.aliceAccountId,
            userName: _userName,
            session: SessionFixtures.aliceSession,
          );

          expect(completed, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test(
      'WHEN the foreground delivery cursor write fails\n'
      'THEN the foreground pipeline reports incomplete',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          when(mockGetNewReceiveEmailFromNotificationInteractor.execute(
            session: anyNamed('session'),
            accountId: anyNamed('accountId'),
            userName: anyNamed('userName'),
            newState: anyNamed('newState'),
          )).thenAnswer((_) async* {
            yield dartz.Right<Failure, Success>(
                GetNewReceiveEmailFromNotificationSuccess(
              AccountFixtures.aliceAccountId,
              SessionFixtures.aliceSession,
              const [],
            ));
          });
          when(mockStoreEmailDeliveryStateInteractor.execute(any, any, any))
              .thenAnswer((_) async* {
            yield dartz.Left<Failure, Success>(
                StoreEmailDeliveryStateFailure(Exception('disk full')));
          });

          final completed = await EmailChangeListener.instance
              .processForegroundPlatformPushNotification(
            newState: State(_incomingLegacyServerState),
            accountId: AccountFixtures.aliceAccountId,
            userName: _userName,
            session: SessionFixtures.aliceSession,
          );

          expect(completed, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test(
      'WHEN there are no new emails to fetch\n'
      'THEN the no-change result is a success, not a retriable failure',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          when(mockGetNewReceiveEmailFromNotificationInteractor.execute(
            session: anyNamed('session'),
            accountId: anyNamed('accountId'),
            userName: anyNamed('userName'),
            newState: anyNamed('newState'),
          )).thenAnswer((_) async* {
            yield dartz.Left<Failure, Success>(
                GetNewReceiveEmailFromNotificationFailure(
                    const EmailStateNoChangeException()));
          });
          when(mockStoreEmailDeliveryStateInteractor.execute(any, any, any))
              .thenAnswer((_) async* {
            yield dartz.Right<Failure, Success>(StoreEmailDeliveryStateSuccess());
          });

          final completed = await EmailChangeListener.instance
              .processForegroundPlatformPushNotification(
            newState: State(_incomingLegacyServerState),
            accountId: AccountFixtures.aliceAccountId,
            userName: _userName,
            session: SessionFixtures.aliceSession,
          );

          expect(completed, isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
