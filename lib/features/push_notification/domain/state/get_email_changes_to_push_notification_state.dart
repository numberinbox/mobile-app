
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/email/presentation_email.dart';

class GetEmailChangesToPushNotificationLoading extends UIState {}

class GetEmailChangesToPushNotificationSuccess extends UIState {

  final List<PresentationEmail> emailList;
  final AccountId accountId;
  final UserName userName;

  /// The real Email state returned by the JMAP Email/changes response. The
  /// delivery cursor must advance to it; a push-produced state is not a
  /// server state and must never be persisted in its place.
  final jmap.State? newState;

  GetEmailChangesToPushNotificationSuccess(
    this.accountId,
    this.userName,
    this.emailList, {
    this.newState,
  });

  @override
  List<Object?> get props => [accountId, userName, emailList, newState];
}

class GetEmailChangesToPushNotificationFailure extends FeatureFailure {

  GetEmailChangesToPushNotificationFailure(exception) : super(exception: exception);
}