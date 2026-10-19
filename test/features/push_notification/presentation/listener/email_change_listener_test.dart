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
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_stored_email_delivery_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_email_delivery_state_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/action/push_notification_state_change_action.dart';
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
])

/// The state the app already displays and has cached locally when the push
/// arrives.
const _cachedAndDisplayedState = '2c9f1b12-b35a-43e6-9af2-0106fb53a943';

/// The real Email state returned by the JMAP Email/changes response.
const _serverNewState = 'd3a4f1c2-9e8b-4a17-8f01-2b6f7c1d5e93';

final _userName = UserName('alice@domain.tld');

void main() {
  late MockMailboxDashBoardController mockDashBoardController;
  late MockGetStoredEmailDeliveryStateInteractor mockGetStoredEmailDeliveryStateInteractor;
  late MockStoreEmailDeliveryStateInteractor mockStoreEmailDeliveryStateInteractor;
  late MockGetEmailChangesToPushNotificationInteractor mockGetEmailChangesToPushNotificationInteractor;

  setUpAll(() {
    Get.testMode = true;
    mockDashBoardController = MockMailboxDashBoardController();
    mockGetStoredEmailDeliveryStateInteractor = MockGetStoredEmailDeliveryStateInteractor();
    mockStoreEmailDeliveryStateInteractor = MockStoreEmailDeliveryStateInteractor();
    mockGetEmailChangesToPushNotificationInteractor = MockGetEmailChangesToPushNotificationInteractor();
    // Get.put/Get.reset run the GetX lifecycle; the mock's fakes would throw.
    when(mockDashBoardController.onStart).thenReturn(InternalFinalCallback<void>(callback: () {}));
    when(mockDashBoardController.onDelete).thenReturn(InternalFinalCallback<void>(callback: () {}));
    Get.put<MailboxDashBoardController>(mockDashBoardController);
    Get.put<GetStoredEmailDeliveryStateInteractor>(mockGetStoredEmailDeliveryStateInteractor);
    Get.put<StoreEmailDeliveryStateInteractor>(mockStoreEmailDeliveryStateInteractor);
    Get.put<GetEmailChangesToPushNotificationInteractor>(mockGetEmailChangesToPushNotificationInteractor);
  });

  setUp(() {
    clearInteractions(mockDashBoardController);
    clearInteractions(mockGetStoredEmailDeliveryStateInteractor);
    clearInteractions(mockStoreEmailDeliveryStateInteractor);
    clearInteractions(mockGetEmailChangesToPushNotificationInteractor);
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
  });

  tearDownAll(Get.reset);

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
