import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/account/password.dart';
import 'package:tmail_ui_user/features/base/reloadable/reloadable_controller.dart';
import 'package:tmail_ui_user/features/home/domain/state/get_session_state.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/numberinbox/jmap_session_manager.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';
import 'package:tmail_ui_user/main/routes/route_utils.dart';

enum OtpPhase { phone, code }

class TwakeWelcomeController extends ReloadableController {
  TwakeWelcomeController({required this.authClient});

  final NumberInboxAuthClient authClient;
  final _sessionManager = JmapSessionManager();

  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  OtpPhase _phase = OtpPhase.phone;
  Country _selectedCountry = countries.first;
  String? _error;
  bool _sending = false;
  bool _verifying = false;

  OtpPhase get phase => _phase;
  Country get selectedCountry => _selectedCountry;
  String? get error => _error;
  bool get sending => _sending;
  bool get verifying => _verifying;

  String get fullE164 => _selectedCountry.buildE164(phoneController.text.trim());

  @visibleForTesting
  set phase(OtpPhase value) {
    _phase = value;
    update();
  }

  @visibleForTesting
  set error(String? value) {
    _error = value;
    update();
  }

  void onCountrySelected(Country country) {
    _selectedCountry = country;
    update();
  }

  Future<void> sendCode() async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      _error = 'Enter your phone number';
      update();
      return;
    }
    if (!_selectedCountry.isValidPhone(phone)) {
      _error = 'Enter a valid ${_selectedCountry.name} phone number';
      update();
      return;
    }

    final e164 = fullE164;
    try {
      _sending = true;
      _error = null;
      update();
      await authClient.startOtp(e164);
      _phase = OtpPhase.code;
      _sending = false;
    } on InvalidE164Exception {
      _error = 'Invalid phone number format';
    } on RateLimitedException {
      _error = 'Too many attempts. Try again later.';
    } catch (e) {
      _error = 'Failed to send code: $e';
    } finally {
      _sending = false;
      update();
    }
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      _error = 'Enter 6-digit code';
      update();
      return;
    }

    try {
      _verifying = true;
      _error = null;
      update();
      final otpSession = await authClient.verifyOtp(fullE164, code);
      _onOtpVerified(otpSession);
    } on OtpInvalidException {
      _error = 'Invalid code. Try again.';
    } on RateLimitedException {
      _error = 'Too many attempts. Try again later.';
    } catch (e) {
      _error = 'Verification failed. Try again.';
    } finally {
      _verifying = false;
      update();
    }
  }

  /// Called after OTP verification succeeds.
  /// Follows the canonical Twake Mail pattern:
  /// 1. setDataToInterceptors (both main + isolate)
  /// 2. getSessionAction (fetch JMAP session)
  /// 3. handleReloaded navigates to dashboard
  void _onOtpVerified(OtpSession otpSession) {
    log('TwakeWelcomeController::_onOtpVerified: username=${otpSession.username}');

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
    log('TwakeWelcomeController::handleReloaded: session fetched');
    pushAndPopAll(
      RouteUtils.generateNavigationRoute(AppRoutes.dashboard),
      arguments: session,
    );
  }

  @override
  void handleFailureViewState(Failure failure) {
    logError('TwakeWelcomeController::handleFailureViewState: ${failure.runtimeType} — $failure');
    if (failure is GetSessionFailure) {
      _error = 'Failed to sign in: ${failure.runtimeType}';
      update();
    } else {
      super.handleFailureViewState(failure);
    }
  }

  @override
  void handleSuccessViewState(Success success) {
    log('TwakeWelcomeController::handleSuccessViewState: ${success.runtimeType}');
    super.handleSuccessViewState(success);
  }

  @override
  void onClose() {
    phoneController.dispose();
    codeController.dispose();
    super.onClose();
  }
}
