import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/email_changes_properties.dart';
import 'package:tmail_ui_user/features/push_notification/domain/repository/fcm_repository.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_email_changes_to_push_notification_interactor.dart';
import 'package:tmail_ui_user/features/thread/data/model/email_change_response.dart';
import 'package:tmail_ui_user/features/thread/domain/model/email_response.dart';
import 'package:tmail_ui_user/main/exceptions/remote/method_level_exception.dart';

import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/session_fixtures.dart';
import '../../../../fixtures/state_fixtures.dart';

/// Minimal fake that only answers [getEmailChangesToPushNotification]; every
/// other [FCMRepository] member forwards to [noSuchMethod] (unused by tests).
class _FakeFCMRepository implements FCMRepository {
  final EmailsResponse emailsResponse;

  _FakeFCMRepository(this.emailsResponse);

  @override
  Future<EmailsResponse> getEmailChangesToPushNotification(
    Session session,
    AccountId accountId,
    jmap.State currentState, {
    EmailChangesProperties? properties,
  }) async =>
      emailsResponse;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingFCMRepository implements FCMRepository {
  final Object changesError;
  final Future<jmap.State?> Function()? currentState;
  int currentStateCalls = 0;

  _ThrowingFCMRepository(this.changesError, {this.currentState});

  @override
  Future<EmailsResponse> getEmailChangesToPushNotification(
    Session session,
    AccountId accountId,
    jmap.State currentState, {
    EmailChangesProperties? properties,
  }) async =>
      throw changesError;

  @override
  Future<jmap.State?> getCurrentEmailState(Session session, AccountId accountId) {
    currentStateCalls++;
    return currentState!();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final userName = UserName('alice@domain.tld');

  Future<GetEmailChangesToPushNotificationFailure> failureFrom(FCMRepository repository) async {
    final states = await GetEmailChangesToPushNotificationInteractor(repository)
        .execute(
          SessionFixtures.aliceSession,
          AccountFixtures.aliceAccountId,
          userName,
          StateFixtures.currentEmailState,
        )
        .toList();
    return states.last.fold((failure) => failure, (_) => fail('expected a failure'))
        as GetEmailChangesToPushNotificationFailure;
  }

  test('WHEN the since-state expired THEN the failure carries the current server state', () async {
    final failure = await failureFrom(_ThrowingFCMRepository(
      CannotCalculateChangesMethodResponseException(),
      currentState: () async => jmap.State('server-state'),
    ));
    expect(failure.exception, isA<CannotCalculateChangesMethodResponseException>());
    expect(failure.recoveredState, jmap.State('server-state'));
  });

  test('WHEN the since-state expired and the state lookup fails THEN the failure has no state', () async {
    final failure = await failureFrom(_ThrowingFCMRepository(
      CannotCalculateChangesMethodResponseException(),
      currentState: () async => throw Exception('offline'),
    ));
    expect(failure.exception, isA<CannotCalculateChangesMethodResponseException>());
    expect(failure.recoveredState, isNull);
  });

  test('WHEN Email/changes fails for another reason THEN the server state is not fetched', () async {
    final repository = _ThrowingFCMRepository(Exception('offline'));
    final failure = await failureFrom(repository);
    expect(failure.recoveredState, isNull);
    expect(repository.currentStateCalls, 0);
  });

  test(
    'should emit a growable email list when the JMAP response has no emails '
    'so that a downstream clear() does not throw on a fixed-length list',
    () async {
      final interactor = GetEmailChangesToPushNotificationInteractor(
        _FakeFCMRepository(const EmailsResponse(emailList: null)),
      );

      final states = await interactor
          .execute(
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            userName,
            StateFixtures.currentEmailState,
          )
          .toList();

      final success = states
              .lastWhere((either) => either.isRight())
              .fold((_) => null, (success) => success)
          as GetEmailChangesToPushNotificationSuccess;

      expect(success.emailList, isEmpty);
      expect(() => success.emailList.clear(), returnsNormally);
    },
  );

  test(
    'WHEN the Email/changes and Email/get responses carry different new states\n'
    'THEN the success exposes the Email/changes state so the cursor cannot skip a change',
    () async {
      final interactor = GetEmailChangesToPushNotificationInteractor(
        _FakeFCMRepository(EmailsResponse(
          emailList: null,
          emailChangeResponse: EmailChangeResponse(
            newStateEmail: jmap.State('server-new-state-email'),
            newStateChanges: jmap.State('server-new-state-changes'),
          ),
        )),
      );

      final states = await interactor
          .execute(
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            userName,
            StateFixtures.currentEmailState,
          )
          .toList();

      final success = states
              .lastWhere((either) => either.isRight())
              .fold((_) => null, (success) => success)
          as GetEmailChangesToPushNotificationSuccess;

      expect(success.newState, jmap.State('server-new-state-changes'));
      expect(success.newState, isNot(equals(jmap.State('server-new-state-email'))));
    },
  );

  test(
    'WHEN the JMAP Email/changes response carries no new state\n'
    'THEN the success leaves the delivery cursor untouched',
    () async {
      final interactor = GetEmailChangesToPushNotificationInteractor(
        _FakeFCMRepository(const EmailsResponse(emailList: null)),
      );

      final states = await interactor
          .execute(
            SessionFixtures.aliceSession,
            AccountFixtures.aliceAccountId,
            userName,
            StateFixtures.currentEmailState,
          )
          .toList();

      final success = states
              .lastWhere((either) => either.isRight())
              .fold((_) => null, (success) => success)
          as GetEmailChangesToPushNotificationSuccess;

      expect(success.newState, isNull);
    },
  );
}
