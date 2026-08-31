import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/account/password.dart';
import 'package:tmail_ui_user/features/base/reloadable/reloadable_controller.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/jmap_session_manager.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';
import 'package:tmail_ui_user/main/routes/route_utils.dart';

/// Controls the NumberInbox OTP login flow.
///
/// After OTP verification, stores the JMAP credentials into the existing
/// Twake Mail interceptor infrastructure and fetches the JMAP session.
class NumberInboxOtpController extends ReloadableController {
  NumberInboxOtpController();

  final JmapSessionManager _sessionManager = JmapSessionManager();
  OtpSession? _pendingOtpSession;

  /// Called by the OTP screen after successful verification.
  /// Stores credentials and triggers JMAP session fetch.
  void onOtpVerified(OtpSession otpSession) {
    log('NumberInboxOtpController::onOtpVerified: '
        'username=${otpSession.username} | '
        'sessionUrl=${otpSession.sessionUrl}');

    _pendingOtpSession = otpSession;

    final baseUrl = _sessionManager.baseUrlFromSession(otpSession);
    final decoded = _sessionManager.decodeBasicAuth(otpSession);

    setDataToInterceptors(
      baseUrl: baseUrl.toString(),
      userName: UserName(decoded['username']!),
      password: Password(decoded['password']!),
    );

    getSessionAction();
  }

  @override
  void handleReloaded(Session session) {
    log('NumberInboxOtpController::handleReloaded: session fetched');
    pushAndPopAll(
      RouteUtils.generateNavigationRoute(AppRoutes.dashboard),
      arguments: session,
    );
  }

  @override
  void handleFailureViewState(Failure failure) {
    logError('NumberInboxOtpController::handleFailureViewState: $failure');
    super.handleFailureViewState(failure);
  }

  @override
  void handleSuccessViewState(Success success) {
    log('NumberInboxOtpController::handleSuccessViewState: ${success.runtimeType}');
    super.handleSuccessViewState(success);
  }
}
