import 'dart:async';

import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:fcm/model/type_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/model.dart';
import 'package:tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/fcm_exception.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_stored_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
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
])

/// The state the app already displays and has cached locally when the push
/// arrives.
const _cachedAndDisplayedState = '2c9f1b12-b35a-43e6-9af2-0106fb53a943';

/// Bob's persisted delivery cursor, distinct from Alice's so a cross-account
/// contamination is visible in the captured interactor arguments.
const _bobStoredDeliveryState = '5a2c8b90-1d4e-4f6a-9c8b-3e7f6a5d4c2b';

/// The real Email state returned by the JMAP Email/changes response.
const _serverNewState = 'd3a4f1c2-9e8b-4a17-8f01-2b6f7c1d5e93';

final _userName = UserName('alice@domain.tld');

final _bobUserName = UserName('bob@domain.tld');

void main() {
  late MockMailboxDashBoardController mockDashBoardController;
  late MockGetStoredEmailDeliveryStateInteractor mockGetStoredEmailDeliveryStateInteractor;
  late MockStoreEmailDeliveryStateInteractor mockStoreEmailDeliveryStateInteractor;
  late MockGetEmailChangesToPushNotificationInteractor mockGetEmailChangesToPushNotificationInteractor;
  late MockGetStoredEmailStateInteractor mockGetStoredEmailStateInteractor;

  setUpAll(() {
    Get.testMode = true;
    mockDashBoardController = MockMailboxDashBoardController();
    mockGetStoredEmailDeliveryStateInteractor = MockGetStoredEmailDeliveryStateInteractor();
    mockStoreEmailDeliveryStateInteractor = MockStoreEmailDeliveryStateInteractor();
    mockGetEmailChangesToPushNotificationInteractor = MockGetEmailChangesToPushNotificationInteractor();
    mockGetStoredEmailStateInteractor = MockGetStoredEmailStateInteractor();
    // Get.put/Get.reset run the GetX lifecycle; the mock's fakes would throw.
    when(mockDashBoardController.onStart).thenReturn(InternalFinalCallback<void>(callback: () {}));
    when(mockDashBoardController.onDelete).thenReturn(InternalFinalCallback<void>(callback: () {}));
    Get.put<MailboxDashBoardController>(mockDashBoardController);
    Get.put<GetStoredEmailDeliveryStateInteractor>(mockGetStoredEmailDeliveryStateInteractor);
    Get.put<StoreEmailDeliveryStateInteractor>(mockStoreEmailDeliveryStateInteractor);
    Get.put<GetEmailChangesToPushNotificationInteractor>(mockGetEmailChangesToPushNotificationInteractor);
    Get.put<GetStoredEmailStateInteractor>(mockGetStoredEmailStateInteractor);
  });

  setUp(() {
    clearInteractions(mockDashBoardController);
    clearInteractions(mockGetStoredEmailDeliveryStateInteractor);
    clearInteractions(mockStoreEmailDeliveryStateInteractor);
    clearInteractions(mockGetEmailChangesToPushNotificationInteractor);
    clearInteractions(mockGetStoredEmailStateInteractor);
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
}
