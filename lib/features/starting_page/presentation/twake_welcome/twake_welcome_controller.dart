import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/account/authentication_type.dart';
import 'package:model/account/password.dart';
import 'package:model/account/personal_account.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/account_repository.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:core/data/utils/device_manager.dart';
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
  TwakeWelcomeController({
    required this.authClient,
    JmapSessionManager? sessionManager,
  }) : _sessionManager = sessionManager ?? JmapSessionManager();

  final NumberInboxAuthClient authClient;
  final JmapSessionManager _sessionManager;

  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  OtpPhase _phase = OtpPhase.phone;
  Country _selectedCountry = defaultCountry();
  String? _error;
  bool _sending = false;
  bool _verifying = false;

  OtpPhase get phase => _phase;
  Country get selectedCountry => _selectedCountry;
  String? get error => _error;
  bool get sending => _sending;
  bool get verifying => _verifying;

  String? _otpNumber;

  String get fullE164 => _selectedCountry.parseE164(phoneController.text.trim()) ?? '';

  @visibleForTesting
  set phase(OtpPhase value) {
    _phase = value;
    _otpNumber = value == OtpPhase.code ? fullE164 : null;
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
    final e164 = _selectedCountry.parseE164(phone);
    if (e164 == null) {
      _error = 'Enter a valid ${_selectedCountry.name} phone number';
      update();
      return;
    }

    try {
      _sending = true;
      _error = null;
      update();
      await authClient.startOtp(e164);
      _otpNumber = e164;
      _phase = OtpPhase.code;
      _sending = false;
    } on InvalidE164Exception {
      _error = 'Invalid phone number format';
    } on RateLimitedException {
      _error = 'Too many attempts. Try again later.';
    } catch (_) {
      // Fixed retryable copy: the exception can carry provider internals or
      // request data, which must not be shown to the user.
      _error = 'Could not send code. Please try again.';
    } finally {
      _sending = false;
      update();
    }
  }

  Future<void> verifyCode() async {
    // A second tap while the first sign-in is still in flight must not start a
    // parallel OTP request and session fetch.
    if (_verifying) return;

    final code = codeController.text.trim();
    if (code.length != 6) {
      _error = 'Enter 6-digit code';
      update();
      return;
    }

    // The OTP request finishing is not the end of sign-in: _onOtpVerified only
    // starts the JMAP session fetch, and the mailbox only opens once the
    // session resolves, the account cache is updated, and handleReloaded
    // navigates. Loading therefore stays on through that whole chain and is
    // cleared by onDataFailureViewState if it breaks.
    var sessionStarted = false;
    try {
      _verifying = true;
      _error = null;
      update();
      String? deviceId;
      try {
        deviceId = await Get.find<DeviceManager>().getDeviceId();
      } catch (_) {}
      final otpSession = await authClient.verifyOtp(_otpNumber ?? fullE164, code, deviceId: deviceId);
      sessionStarted = await _onOtpVerified(otpSession);
    } on OtpInvalidException {
      _error = 'Invalid code. Try again.';
    } on RateLimitedException {
      _error = 'Too many attempts. Try again later.';
    } catch (e) {
      _error = 'Verification failed. Try again.';
    } finally {
      if (!sessionStarted) {
        _verifying = false;
        update();
      }
    }
  }

  /// Called after OTP verification succeeds.
  /// Follows the canonical Twake Mail pattern:
  /// 1. setDataToInterceptors (both main + isolate)
  /// 2. getSessionAction (fetch JMAP session)
  /// 3. handleReloaded navigates to dashboard
  ///
  /// Returns whether the session operation was started, so [verifyCode] knows
  /// whether the loading state has to survive past the OTP request.
  Future<bool> _onOtpVerified(OtpSession otpSession) async {
    // Non-identifying only: the username identifies the mailbox account and
    // must not be written to logs.
    log('TwakeWelcomeController::_onOtpVerified: session accepted');

    // The base URL is resolved first, on purpose: it decides where the
    // username and credential from this same response are sent, so an origin
    // the client was not configured for has to fail before the interceptors
    // are pointed at it and before anything is written to storage.
    final Uri baseUrl;
    try {
      baseUrl = _sessionManager.baseUrlFromSession(otpSession);
    } on UntrustedJmapSessionUrlException catch (error) {
      // Category only: the rejected URL and the credential stay out of the
      // record. Re-thrown so verifyCode reports one generic, retryable error.
      logError(
        'TwakeWelcomeController::_onOtpVerified: '
        'event=otp_session_origin_rejected | category=${error.reason}',
      );
      rethrow;
    }

    final decoded = _sessionManager.decodeBasicAuth(otpSession);

    setDataToInterceptors(
      baseUrl: baseUrl.toString(),
      userName: UserName(decoded['username']!),
      password: Password(decoded['password']!),
    );

    if (!await _persistCredentials(
      baseUrl: baseUrl,
      username: decoded['username']!,
      password: decoded['password']!,
    )) {
      // Credentials that never reached storage do not survive a restart, so
      // the session fetch is not started and sign-in is reported as failed.
      _error = 'Could not save your sign-in. Please try again.';
      update();
      return false;
    }

    getSessionAction();
    return true;
  }

  /// Stores the OTP-issued credentials.
  ///
  /// The selected account is written last and is what commits the sign-in: a
  /// relaunch pairs whatever credential is on disk with whatever account is
  /// selected. So if that write fails, the credential writes that already
  /// succeeded are undone — otherwise the relaunch would pair the *new*
  /// credential with the *old* selected account.
  ///
  /// Returns whether the sign-in is committed. A failure is reported as `false`
  /// rather than thrown, so the caller can keep the user on the login screen.
  Future<bool> _persistCredentials({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final credentialRepo = Get.find<CredentialRepository>();
    final accountRepo = Get.find<AccountRepository>();

    // Read before writing, so a failure can be undone to the state the user
    // was actually in. On a first install these reads fail: there is no
    // credential yet, and there is nothing to restore either.
    Uri? previousBaseUrl;
    AuthenticationInfoCache? previousAuth;
    try {
      previousBaseUrl = await credentialRepo.getBaseUrl();
      previousAuth = await credentialRepo.getAuthenticationInfoStored();
    } catch (e) {
      logWarning(
        'TwakeWelcomeController::_persistCredentials: no previous credential '
        'to restore (category=${e.runtimeType})',
      );
    }

    try {
      await credentialRepo.saveBaseUrl(baseUrl);
      await credentialRepo.storeAuthenticationInfo(
        AuthenticationInfoCache(username, password),
      );
      await accountRepo.setCurrentAccount(
        PersonalAccount(
          username,
          AuthenticationType.basic,
          isSelected: true,
        ),
      );
      return true;
    } catch (e) {
      // Category only. Passing `e` as the log exception would fold its text
      // into the record, and persistence failures can carry credential data.
      logError(
        'TwakeWelcomeController::_persistCredentials: failed '
        '(category=${e.runtimeType})',
      );
      await _rollbackSignIn(
        credentialRepo: credentialRepo,
        attemptedBaseUrl: baseUrl,
        previousBaseUrl: previousBaseUrl,
        previousAuth: previousAuth,
      );
      return false;
    }
  }

  /// Puts the credential stores and the interceptors back the way a relaunch
  /// would find them.
  ///
  /// Restores the previous credential when there was one; clears the new one
  /// otherwise, because a half-written credential is what this whole method
  /// exists to prevent. Best effort: a rollback failure is reported and the
  /// sign-in is still reported as failed.
  Future<void> _rollbackSignIn({
    required CredentialRepository credentialRepo,
    required Uri attemptedBaseUrl,
    required Uri? previousBaseUrl,
    required AuthenticationInfoCache? previousAuth,
  }) async {
    // An empty record is what a store with no credential reads back, so it
    // counts as "nothing to restore" rather than as a previous session.
    final previousCredential = previousAuth?.username.isNotEmpty == true
        ? previousAuth
        : null;

    try {
      if (previousCredential != null) {
        if (previousBaseUrl != null) {
          await credentialRepo.saveBaseUrl(previousBaseUrl);
        }
        await credentialRepo.storeAuthenticationInfo(previousCredential);
      } else {
        await credentialRepo.removeBaseUrl();
        await credentialRepo.removeAuthenticationInfo();
      }
    } catch (rollbackError) {
      logError(
        'TwakeWelcomeController::_rollbackSignIn: storage rollback failed '
        '(category=${rollbackError.runtimeType})',
      );
    }

    // The interceptors hold the credential the user just typed. Whatever
    // happens on disk, they go back to the previous session, or are cleared
    // when there was none.
    if (previousCredential != null) {
      setDataToInterceptors(
        baseUrl: (previousBaseUrl ?? attemptedBaseUrl).toString(),
        userName: UserName(previousCredential.username),
        password: Password(previousCredential.password),
      );
    } else {
      authorizationInterceptors.clear();
      authorizationIsolateInterceptors.clear();
    }
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
  void onDataFailureViewState(Failure failure) {
    // Clearing here rather than in handleFailureViewState also covers the
    // urgent branch: BaseController.onDataFailureViewState sends urgent
    // exceptions straight to handleUrgentException and never reaches
    // handleFailureViewState, which would otherwise leave the spinner running.
    if (failure is GetSessionFailure) {
      _verifying = false;
    }
    super.onDataFailureViewState(failure);
  }

  @override
  void handleFailureViewState(Failure failure) {
    // Fixed event name plus the failure *type*, never the failure itself.
    // `GetSessionFailure` wraps whatever the JMAP session request threw, which
    // can be a response body, an Authorization header or a URL carrying
    // credentials; interpolating it folds all of that into the log record and
    // on into Sentry.
    logError(
      'TwakeWelcomeController::handleFailureViewState: '
      'event=sign_in_failed | category=${failure.runtimeType}',
    );
    if (failure is GetSessionFailure) {
      // Generic and retryable: the user has to be able to try the code again.
      _error = 'Failed to sign in. Please try again.';
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
