import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/extensions/email_extension.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/email_changes_properties.dart';
import 'package:tmail_ui_user/features/push_notification/domain/repository/fcm_repository.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/get_email_changes_to_push_notification_state.dart';
import 'package:tmail_ui_user/main/exceptions/remote/method_level_exception.dart';

class GetEmailChangesToPushNotificationInteractor {
  final FCMRepository _fcmRepository;

  GetEmailChangesToPushNotificationInteractor(this._fcmRepository);

  Stream<Either<Failure, Success>> execute(
    Session session,
    AccountId accountId,
    UserName userName,
    jmap.State currentState,
    {
      Properties? propertiesCreated,
      Properties? propertiesUpdated
    }
  ) async* {
    try {
      yield Right<Failure, Success>(GetEmailChangesToPushNotificationLoading());

      final emailsResponse = await _fcmRepository.getEmailChangesToPushNotification(
        session,
        accountId,
        currentState,
        properties: EmailChangesProperties(
          created: propertiesCreated,
          updated: propertiesUpdated,
        ),
      );

      final presentationEmailList = emailsResponse.emailList
        ?.map((email) => email.toPresentationEmail())
        .toList() ?? [];

      yield Right<Failure, Success>(GetEmailChangesToPushNotificationSuccess(
        accountId,
        userName,
        presentationEmailList,
        // The delivery cursor must be the Email/changes state: the Email/get
        // state can move past changes that were not processed yet.
        newState: emailsResponse.emailChangeResponse?.newStateChanges,
      ));
    } catch (e) {
      yield Left<Failure, Success>(GetEmailChangesToPushNotificationFailure(
        e,
        recoveredState: e is CannotCalculateChangesMethodResponseException
          ? await _findCurrentState(session, accountId)
          : null,
      ));
    }
  }

  Future<jmap.State?> _findCurrentState(Session session, AccountId accountId) async {
    try {
      return await _fcmRepository.getCurrentEmailState(session, accountId);
    } catch (e, st) {
      logError(
        'GetEmailChangesToPushNotificationInteractor::_findCurrentState: state lookup failed',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }
}