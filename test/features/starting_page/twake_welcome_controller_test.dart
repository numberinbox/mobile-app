import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/data/utils/device_manager.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/utils/logging/app_logger_registry.dart';
import 'package:core/utils/logging/log_handler.dart';
import 'package:core/utils/logging/log_level.dart';
import 'package:core/utils/logging/log_record.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/push/state_change.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/home/domain/repository/session_repository.dart';
import 'package:tmail_ui_user/features/home/domain/state/get_session_state.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/repository/account_repository.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/state/update_authentication_account_state.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_oidc_user_info_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/update_account_cache_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/numberinbox/jmap_session_manager.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/exceptions/remote/network_exception.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:model/account/authentication_type.dart';
import 'package:model/account/personal_account.dart';

class MockCachingManager extends Mock implements CachingManager {}
class MockLanguageCacheManager extends Mock implements LanguageCacheManager {}
class MockAuthorizationInterceptors extends Mock implements AuthorizationInterceptors {}
class MockDynamicUrlInterceptors extends Mock implements DynamicUrlInterceptors {}
class MockDeleteCredentialInteractor extends Mock implements DeleteCredentialInteractor {}
class MockLogoutOidcInteractor extends Mock implements LogoutOidcInteractor {}
class MockDeleteAuthorityOidcInteractor extends Mock implements DeleteAuthorityOidcInteractor {}
class MockGetAuthenticatedAccountInteractor extends Mock implements GetAuthenticatedAccountInteractor {}
class MockGetOidcUserInfoInteractor extends Mock implements GetOidcUserInfoInteractor {}
class MockUpdateAccountCacheInteractor extends Mock implements UpdateAccountCacheInteractor {}
class MockGetSessionInteractor extends Mock implements GetSessionInteractor {}
class MockAppToast extends Mock implements AppToast {}
class MockImagePaths extends Mock implements ImagePaths {}
class MockResponsiveUtils extends Mock implements ResponsiveUtils {}
class MockUuid extends Mock implements Uuid {}
class MockTwakeAppManager extends Mock implements TwakeAppManager {}
class MockSession extends Mock implements Session {}
class MockSessionRepository extends Mock implements SessionRepository {}
class MockDeviceManager extends Mock implements DeviceManager {}
class MockAccountRepository extends Mock implements AccountRepository {}
class MockCredentialRepository extends Mock implements CredentialRepository {}

/// Session interactor whose stream stays open until the test drives it, so a
/// pending session can be observed instead of raced against.
class ControllableGetSessionInteractor extends GetSessionInteractor {
  ControllableGetSessionInteractor() : super(MockSessionRepository());

  // Broadcast so close() completes even when nothing ever listened: a
  // single-subscription controller only finishes closing once it is drained,
  // which hangs the tests where the session fetch is never reached.
  final _controller = StreamController<Either<Failure, Success>>.broadcast();
  int executeCalls = 0;

  @override
  Stream<Either<Failure, Success>> execute({StateChange? stateChange}) {
    executeCalls++;
    return _controller.stream;
  }

  void succeed(Session session) =>
      _controller.add(Right<Failure, Success>(GetSessionSuccess(session)));

  void fail(Failure failure) => _controller.add(Left<Failure, Success>(failure));

  Future<void> close() => _controller.close();
}

/// Auth client that returns a scripted result instead of going through HTTP,
/// so these tests exercise loading-state timing rather than the mock adapter.
class ScriptedAuthClient extends NumberInboxAuthClient {
  ScriptedAuthClient() : super(Dio());

  int verifyCalls = 0;
  Object? verifyError;
  Object? startOtpError;
  OtpSession? session;

  /// Overrides the JMAP URL inside the default session, for the origin checks.
  String? sessionUrl;

  @override
  Future<void> startOtp(String rawE164) async {
    final error = startOtpError;
    if (error != null) throw error;
  }

  @override
  Future<OtpSession> verifyOtp(String rawE164, String code, {String? deviceId}) async {
    verifyCalls++;
    final error = verifyError;
    if (error != null) throw error;
    final url = sessionUrl;
    if (url != null) {
      return OtpSession(
        accessToken: 'jwt',
        username: '+66812345678@numberinbox.test',
        sessionUrl: url,
        credential: 'app_secret',
      );
    }
    return session ??
        const OtpSession(
          accessToken: 'jwt',
          username: '+66812345678@numberinbox.test',
          sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
          credential: 'app_secret',
        );
  }
}

/// Repository that always fails, so credential-persistence error paths run.
class ThrowingAccountRepository extends FakeAccountRepository {
  ThrowingAccountRepository(this.marker);

  final String marker;

  @override
  Future<void> setCurrentAccount(PersonalAccount account) async =>
      throw Exception(marker);
}

/// Repository that always fails, so credential-persistence error paths run.
class ThrowingCredentialRepository extends FakeCredentialRepository {
  ThrowingCredentialRepository(this.marker);

  final String marker;

  @override
  Future storeAuthenticationInfo(AuthenticationInfoCache info) async =>
      throw Exception(marker);
}

/// Captures every dispatched [LogRecord] so tests can assert on log content.
class _CapturingLogHandler extends LogHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  String get handlerKey => 'capturing-log-handler-for-tests';

  @override
  void handle(LogRecord record) => records.add(record);

  /// Everything a sink would ever see: the message plus the exception,
  /// extras and stack trace, which [LogRecord.build] folds into rawMessage.
  String get everything =>
      records.map((r) => r.rawMessage).join('\n');
}

/// Emits a caller-supplied cache-update stream so the pending update that
/// sits between session success and dashboard navigation can be observed.
class ControllableUpdateAccountCacheInteractor extends UpdateAccountCacheInteractor {
  ControllableUpdateAccountCacheInteractor(this._stream) : super(FakeAccountRepository());

  final Stream<Either<Failure, Success>> _stream;

  @override
  Stream<Either<Failure, Success>> execute({required Session session, String? baseUrl}) =>
      _stream;
}

/// Counts dashboard navigations instead of pushing a real route.
class NavigationCountingTwakeWelcomeController extends TwakeWelcomeController {
  NavigationCountingTwakeWelcomeController({required super.authClient});

  int dashboardNavigations = 0;

  @override
  void handleReloaded(Session session) {
    dashboardNavigations++;
  }
}

class FakeCredentialRepository implements CredentialRepository {
  Uri? savedBaseUrl;
  AuthenticationInfoCache? storedAuth;

  @override
  Future saveBaseUrl(Uri baseUrl) async { savedBaseUrl = baseUrl; }

  @override
  Future removeBaseUrl() async {}

  @override
  Future<Uri> getBaseUrl() async => Uri.parse('https://localhost');

  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async { storedAuth = info; }

  @override
  Future<AuthenticationInfoCache> getAuthenticationInfoStored() async => AuthenticationInfoCache('', '');

  @override
  Future<void> removeAuthenticationInfo() async {}
}

class FakeAccountRepository implements AccountRepository {
  PersonalAccount? savedAccount;

  @override
  Future<PersonalAccount> getCurrentAccount() async => throw Exception('no account');

  @override
  Future<void> setCurrentAccount(PersonalAccount account) async { savedAccount = account; }

  @override
  Future<void> deleteCurrentAccount(String hashId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late DioAdapter adapter;
  late NumberInboxAuthClient client;
  late TwakeWelcomeController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;

    Get.put<CachingManager>(MockCachingManager());
    Get.put<LanguageCacheManager>(MockLanguageCacheManager());
    Get.put<AppToast>(MockAppToast());
    Get.put<ImagePaths>(MockImagePaths());
    Get.put<ResponsiveUtils>(MockResponsiveUtils());
    Get.put<Uuid>(MockUuid());
    Get.put(ToastManager(MockAppToast(), MockImagePaths()));
    Get.put<TwakeAppManager>(MockTwakeAppManager());
    Get.put<DeleteCredentialInteractor>(MockDeleteCredentialInteractor());
    Get.put<LogoutOidcInteractor>(MockLogoutOidcInteractor());
    Get.put<DeleteAuthorityOidcInteractor>(MockDeleteAuthorityOidcInteractor());
    Get.put<GetAuthenticatedAccountInteractor>(MockGetAuthenticatedAccountInteractor());
    Get.put<GetOidcUserInfoInteractor>(MockGetOidcUserInfoInteractor());
    Get.put<UpdateAccountCacheInteractor>(MockUpdateAccountCacheInteractor());
    Get.put<GetSessionInteractor>(MockGetSessionInteractor());
    Get.put<DeviceManager>(MockDeviceManager());

    final fakeAccountRepo = FakeAccountRepository();
    Get.put<AccountRepository>(fakeAccountRepo);

    final fakeCredentialRepo = FakeCredentialRepository();
    Get.put<CredentialRepository>(fakeCredentialRepo);

    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);

    final dynamicUrlInterceptors = MockDynamicUrlInterceptors();
    Get.put<DynamicUrlInterceptors>(dynamicUrlInterceptors);

    final authInterceptors = MockAuthorizationInterceptors();
    Get.put<AuthorizationInterceptors>(authInterceptors);

    final authIsolateInterceptors = MockAuthorizationInterceptors();
    Get.put<AuthorizationInterceptors>(authIsolateInterceptors, tag: BindingTag.isolateTag);

    controller = TwakeWelcomeController(authClient: client);
    // OTP-flow tests below run as Thailand regardless of test env locale.
    controller.onCountrySelected(
      countries.firstWhere((c) => c.code == 'TH'),
    );
  });

  tearDown(() => Get.reset());

  group('initial state', () {
    test('country defaults to device locale', () {
      // Fresh controller: default must follow the device locale helper,
      // not a hardcoded country.
      final fresh = TwakeWelcomeController(authClient: client);
      expect(
        fresh.selectedCountry.code,
        countryForRegionCode(deviceRegionCode()).code,
      );
      fresh.dispose();
    });

    test('phase is phone', () {
      expect(controller.phase, OtpPhase.phone);
    });

    test('error is null', () {
      expect(controller.error, isNull);
    });

    test('sending is false', () {
      expect(controller.sending, isFalse);
    });

    test('verifying is false', () {
      expect(controller.verifying, isFalse);
    });
  });

  group('onCountrySelected', () {
    test('changes country', () {
      final us = countries.firstWhere((c) => c.code == 'US');
      controller.onCountrySelected(us);
      expect(controller.selectedCountry.code, 'US');
    });
  });

  group('sendCode', () {
    test('empty phone sets error', () async {
      await controller.sendCode();
      expect(controller.error, 'Enter your phone number');
      expect(controller.phase, OtpPhase.phone);
    });

    test('short phone sets error', () async {
      controller.phoneController.text = '12';
      await controller.sendCode();
      expect(controller.error, isNotNull);
      expect(controller.phase, OtpPhase.phone);
    });

    test('valid phone calls API and transitions to code phase', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      expect(controller.phase, OtpPhase.code);
      expect(controller.error, isNull);
    });

    test('server error sets error message', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(500, {'error': 'internal'}),
          data: {'e164': '+66812345678'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      expect(controller.error, isNotNull);
      expect(controller.phase, OtpPhase.phone);
    });

    test('unexpected send failure does not leak the exception to the user',
        () async {
      // Anything that is not a DioException escapes NumberInboxAuthClient
      // unmapped, so its toString() can carry provider internals, a token, or
      // a request body straight into the UI.
      const secret = 'SECRET-MARKER-abc123';
      final auth = ScriptedAuthClient()
        ..startOtpError = Exception('provider said: $secret');

      Get.replace<GetSessionInteractor>(ControllableGetSessionInteractor());
      final ctrl = TwakeWelcomeController(authClient: auth);
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phoneController.text = '812345678';

      await ctrl.sendCode();
      final error = ctrl.error;
      ctrl.dispose();

      expect(error, isNotNull, reason: 'an unexpected failure must still be reported');
      expect(
        error,
        isNot(contains(secret)),
        reason: 'the raw exception must not reach the user-visible error',
      );
      expect(
        error,
        isNot(contains('Exception')),
        reason: 'the user-visible error must not read like a stack dump',
      );
      expect(ctrl.phase, OtpPhase.phone);
      expect(ctrl.sending, isFalse);
    });

    test('rate limit and invalid number keep their specific messages', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(429, {'error': 'rate_limited'}),
          data: {'e164': '+66812345678'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();
      expect(controller.error, 'Too many attempts. Try again later.');

      adapter.onPost('/v1/otp/start',
          (server) => server.reply(400, {'error': 'invalid_e164'}),
          data: {'e164': '+66812345678'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();
      expect(controller.error, 'Invalid phone number format');
    });
  });

  group('verifyCode', () {
    test('short code shows error', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();
      expect(controller.phase, OtpPhase.code);

      controller.codeController.text = '123';
      await controller.verifyCode();

      expect(controller.error, isNotEmpty);
    });

    test('wrong code shows otp_invalid error', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify',
          (server) => server.reply(401, {'error': 'otp_invalid'}),
          data: {'e164': '+66812345678', 'code': '000000'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '000000';
      await controller.verifyCode();

      expect(controller.error, isNotEmpty);
    });

    test('rate limited shows error', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify',
          (server) => server.reply(429, {'error': 'rate_limited'}),
          data: {'e164': '+66812345678', 'code': '123456'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '123456';
      await controller.verifyCode();

      expect(controller.error, isNotEmpty);
    });

    test('happy path triggers session fetch after OTP verify', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify', (server) => server.reply(200, {
        'accessToken': 'jwt',
        'jmap': {
          'sessionUrl': 'https://jmap.numberinbox.com/.well-known/jmap',
          'username': '+66812345678@numberinbox.com',
          'credential': 'app-secret',
        }
      }), data: {'e164': '+66812345678', 'code': '123456'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '123456';
      await controller.verifyCode();

      // OTP verify succeeds and triggers getSessionAction.
      // getSessionAction fails because there's no real JMAP endpoint,
      // so handleFailureViewState is called. This is expected in unit tests.
      // The key assertion: OTP verify did NOT set an OTP-related error.
      expect(controller.error, isNot(equals('Invalid code. Try again.')));
      expect(controller.error, isNot(equals('Enter 6-digit code')));
    });

    test('post-OTP sets interceptors and calls getSessionAction', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify', (server) => server.reply(200, {
        'accessToken': 'jwt',
        'jmap': {
          'sessionUrl': 'https://jmap.numberinbox.com/.well-known/jmap',
          'username': '+66812345678@numberinbox.com',
          'credential': 'app-secret',
        }
      }), data: {'e164': '+66812345678', 'code': '123456'});

      final mockDynamicUrlInterceptors = Get.find<DynamicUrlInterceptors>();

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '123456';
      await controller.verifyCode();

      verify(mockDynamicUrlInterceptors.setJmapUrl(any)).called(greaterThanOrEqualTo(1));
      verify(mockDynamicUrlInterceptors.changeBaseUrl(any)).called(greaterThanOrEqualTo(1));
    });
  });

  group('verifyCode loading state', () {
    /// Drives a freshly built controller to the code screen with a valid OTP
    /// response.
    ///
    /// [ReloadableController] resolves its interactors in field initialisers, so
    /// the session interactor has to be registered *before* the controller is
    /// constructed or the controller keeps the previous one.
    Future<TwakeWelcomeController> arrangeOnCodeScreen({
      required ControllableGetSessionInteractor session,
      ScriptedAuthClient? auth,
    }) async {
      // Get.put is a no-op when the type is already registered by setUp, so
      // replace instead: ReloadableController resolves the interactor in a
      // field initialiser and would otherwise keep the Mockito stub.
      Get.replace<GetSessionInteractor>(session);

      final ctrl = TwakeWelcomeController(authClient: auth ?? ScriptedAuthClient());
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';
      return ctrl;
    }

    test(
        'keeps verifying true after OTP succeeds while the session is pending',
        () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final ctrl = await arrangeOnCodeScreen(session: session);

      // Do not await: the OTP call returns, then the session stream stays open.
      final pending = ctrl.verifyCode();
      for (var i = 0; i < 50 && session.executeCalls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(session.executeCalls, 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        ctrl.verifying,
        isTrue,
        reason: 'the Verify spinner must stay until the mailbox opens, not just '
            'until the OTP request finishes',
      );
      await pending;
      ctrl.dispose();
    });

    test('ignores a second verifyCode while one is already in flight',
        () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final ctrl = await arrangeOnCodeScreen(session: session);

      final first = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        session.executeCalls,
        1,
        reason: 'a second tap must not start a second session fetch',
      );
      await first;
      await second;
      ctrl.dispose();
    });

    test('clears verifying when the OTP code is rejected', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify',
          (server) => server.reply(401, {'error': 'otp_invalid'}),
          data: {'e164': '+66812345678', 'code': '000000'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();
      controller.codeController.text = '000000';
      await controller.verifyCode();

      expect(controller.verifying, isFalse);
      expect(controller.error, isNotNull);
    });

    test('clears verifying when the OTP request is rate limited', () async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify',
          (server) => server.reply(429, {'error': 'rate_limited'}),
          data: {'e164': '+66812345678', 'code': '123456'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();
      controller.codeController.text = '123456';
      await controller.verifyCode();

      expect(controller.verifying, isFalse);
      expect(controller.error, isNotNull);
    });

    test('clears verifying when the code length is invalid', () async {
      controller.codeController.text = '123';
      await controller.verifyCode();

      expect(controller.verifying, isFalse);
      expect(controller.error, 'Enter 6-digit code');
    });

    test('clears verifying and allows retry on a session failure', () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final ctrl = await arrangeOnCodeScreen(session: session);

      final pending = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ctrl.verifying, isTrue);

      session.fail(GetSessionFailure(Exception('session unavailable')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pending;

      expect(
        ctrl.verifying,
        isFalse,
        reason: 'a session failure must restore a usable Verify button',
      );
      expect(ctrl.error, isNotNull);
      ctrl.dispose();
    });

    test('clears verifying for an urgent session failure routed around '
        'handleFailureViewState', () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final ctrl = await arrangeOnCodeScreen(session: session);

      final pending = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ctrl.verifying, isTrue);

      // NoNetworkError is an urgent exception: BaseController.onDataFailure
      // ViewState sends it to handleUrgentException instead of
      // handleFailureViewState, so the clear has to happen before that branch.
      session.fail(GetSessionFailure(const NoNetworkError()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pending;

      expect(ctrl.verifying, isFalse);
      ctrl.dispose();
    });

    test('keeps verifying through the account-cache update', () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);

      // A cache stream that emits a loading state and then stays open, so the
      // pending update can be observed rather than raced against.
      final fakeSession = MockSession();
      final cacheStream = StreamController<Either<Failure, Success>>();
      addTearDown(cacheStream.close);

      Get.replace<UpdateAccountCacheInteractor>(
        ControllableUpdateAccountCacheInteractor(cacheStream.stream),
      );

      final ctrl = await arrangeOnCodeScreen(session: session);

      final pending = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Session resolves; the cache update that follows must not clear loading.
      session.succeed(fakeSession);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        ctrl.verifying,
        isTrue,
        reason: 'loading must survive the account-cache update that precedes '
            'dashboard navigation',
      );
      await pending;
      ctrl.dispose();
    });

    test('does not clear verifying on UpdateAccountCacheFailure', () async {
      final fakeSession = MockSession();
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);

      Get.replace<UpdateAccountCacheInteractor>(
        ControllableUpdateAccountCacheInteractor(
          Stream.value(
            Left<Failure, Success>(UpdateAccountCacheFailure(
              session: fakeSession,
              apiUrl: 'https://localhost',
              exception: Exception('cache write failed'),
            )),
          ),
        ),
      );

      final ctrl = await arrangeOnCodeScreen(session: session);

      final pending = ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      session.succeed(fakeSession);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        ctrl.verifying,
        isTrue,
        reason: 'UpdateAccountCacheFailure still navigates with the fetched '
            'session, so loading must not be cleared',
      );
      await pending;
      ctrl.dispose();
    });
  });

  group('OTP-flow logging', () {
    late _CapturingLogHandler logs;

    setUp(() {
      logs = _CapturingLogHandler();
      AppLoggerRegistry.instance.registerHandler(logs);
    });

    tearDown(() => AppLoggerRegistry.instance.resetForTesting());

    test('successful verification does not log the account identifier',
        () async {
      const accountId = 'ACCOUNT-ID-MARKER-zzz999';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final auth = ScriptedAuthClient()
        ..session = const OtpSession(
          accessToken: 'jwt',
          username: accountId,
          sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
          credential: 'app_secret',
        );

      Get.replace<GetSessionInteractor>(session);
      final ctrl = TwakeWelcomeController(authClient: auth);
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';

      await ctrl.verifyCode();
      ctrl.dispose();

      expect(
        logs.everything,
        isNot(contains(accountId)),
        reason: 'the mailbox username identifies the account and must not be logged',
      );
    });

    test('credential storage failure does not log the exception text',
        () async {
      const secret = 'CREDENTIAL-SECRET-987xyz';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);

      // Credential storage is written first, so only this repository throws.
      Get.replace<CredentialRepository>(ThrowingCredentialRepository(secret));

      Get.replace<GetSessionInteractor>(session);
      final ctrl = TwakeWelcomeController(authClient: ScriptedAuthClient());
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';

      await ctrl.verifyCode();
      ctrl.dispose();

      expect(
        logs.everything,
        isNot(contains(secret)),
        reason: 'persistence failures must log a category, not the exception text',
      );
      expect(
        logs.records.where((r) => r.level == Level.error),
        isNotEmpty,
        reason: 'the failure must still be reported for diagnostics',
      );
    });

    test('account storage failure does not log the exception text', () async {
      // The later failure point: credentials are already stored by the time
      // setCurrentAccount throws, so this covers the second persistence error.
      const secret = 'ACCOUNT-SECRET-654zzy';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);

      Get.replace<AccountRepository>(ThrowingAccountRepository(secret));

      Get.replace<GetSessionInteractor>(session);
      final ctrl = TwakeWelcomeController(authClient: ScriptedAuthClient());
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';

      await ctrl.verifyCode();
      ctrl.dispose();

      expect(
        logs.everything,
        isNot(contains(secret)),
        reason: 'account persistence failures must log a category, not the '
            'exception text',
      );
      expect(
        logs.records.where((r) => r.level == Level.error),
        isNotEmpty,
        reason: 'the failure must still be reported for diagnostics',
      );
    });
  });

  group('OTP session origin', () {
    // The OTP response chooses where the Basic-auth credentials go. A response
    // naming any other origin must be refused before the interceptors are
    // pointed at it, before anything is persisted, and before a session fetch
    // is attempted.
    Future<TwakeWelcomeController> arrangeOnCodeScreen({
      required ScriptedAuthClient auth,
      required ControllableGetSessionInteractor session,
    }) async {
      Get.replace<GetSessionInteractor>(session);
      final ctrl = TwakeWelcomeController(authClient: auth);
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';
      return ctrl;
    }

    test('a trusted origin installs credentials and fetches the session',
        () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final auth = ScriptedAuthClient()
        ..sessionUrl = 'https://jmap.numberinbox.com/.well-known/jmap';
      final ctrl = await arrangeOnCodeScreen(auth: auth, session: session);

      await ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(session.executeCalls, 1);
      final credentials =
          Get.find<CredentialRepository>() as FakeCredentialRepository;
      expect(credentials.savedBaseUrl?.host, 'jmap.numberinbox.com');
      ctrl.dispose();
    });

    test('an untrusted origin is refused before any credential is used',
        () async {
      const attackerHost = 'attacker-jmap.example';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final auth = ScriptedAuthClient()
        ..sessionUrl = 'https://$attackerHost/.well-known/jmap';
      final ctrl = await arrangeOnCodeScreen(auth: auth, session: session);

      await ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final credentials =
          Get.find<CredentialRepository>() as FakeCredentialRepository;
      final accounts = Get.find<AccountRepository>() as FakeAccountRepository;
      final interceptors = Get.find<DynamicUrlInterceptors>() as MockDynamicUrlInterceptors;

      expect(
        session.executeCalls,
        0,
        reason: 'no session fetch may be attempted against an untrusted host',
      );
      expect(credentials.savedBaseUrl, isNull);
      expect(credentials.storedAuth, isNull);
      expect(accounts.savedAccount, isNull);
      verifyNever(interceptors.changeBaseUrl(any));
      verifyNever(interceptors.setJmapUrl(any));
      expect(ctrl.verifying, isFalse, reason: 'the user must be able to retry');
      ctrl.dispose();
    });

    test('an untrusted origin shows a generic, retryable error', () async {
      const secret = 'UNTRUSTED-URL-MARKER-555';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final auth = ScriptedAuthClient()
        ..sessionUrl = 'https://$secret.example/.well-known/jmap';
      final ctrl = await arrangeOnCodeScreen(auth: auth, session: session);

      await ctrl.verifyCode();
      final error = ctrl.error;
      ctrl.dispose();

      expect(error, isNotNull);
      expect(
        error,
        isNot(contains(secret)),
        reason: 'the rejected host must not reach the user',
      );
      expect(error, isNot(contains('UntrustedJmapSessionUrl')));
    });

    test('the rejected origin is logged as a category, not as a URL', () async {
      const secret = 'LOGGED-URL-MARKER-666';
      final logs = _CapturingLogHandler();
      AppLoggerRegistry.instance.registerHandler(logs);
      addTearDown(AppLoggerRegistry.instance.resetForTesting);

      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final auth = ScriptedAuthClient()
        ..sessionUrl = 'https://$secret.example/.well-known/jmap';
      final ctrl = await arrangeOnCodeScreen(auth: auth, session: session);

      await ctrl.verifyCode();
      ctrl.dispose();

      expect(
        logs.everything,
        isNot(contains(secret)),
        reason: 'the rejected URL must never reach a log sink',
      );
      expect(
        logs.everything,
        contains('otp_session_origin_rejected'),
        reason: 'the rejection must still be diagnosable',
      );
    });

    test('an injected development origin is honoured for its own host', () {
      // Local development runs against plain http on a custom port, which the
      // production origin check would otherwise reject.
      final manager = JmapSessionManager(baseUrl: 'http://localhost:8080');
      expect(
        manager
            .baseUrlFromSession(const OtpSession(
              accessToken: 'jwt',
              username: '+66812345678@numberinbox.test',
              sessionUrl: 'http://localhost:8080/.well-known/jmap',
              credential: 'secret',
            ))
            .toString(),
        'http://localhost:8080',
      );
    });
  });

  group('OTP credential persistence', () {
    // Credentials that are not on disk do not survive a restart, so a
    // persistence failure must not report success: no session fetch, no
    // navigation, and a retry the user can actually make.
    Future<TwakeWelcomeController> arrangeOnCodeScreen({
      required ScriptedAuthClient auth,
      required ControllableGetSessionInteractor session,
    }) async {
      Get.replace<GetSessionInteractor>(session);
      final ctrl = TwakeWelcomeController(authClient: auth);
      ctrl.onCountrySelected(countries.firstWhere((c) => c.code == 'TH'));
      ctrl.phase = OtpPhase.code;
      ctrl.codeController.text = '123456';
      return ctrl;
    }

    test('a credential write failure does not report success', () async {
      const secret = 'WRITE-FAILURE-MARKER-888';
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      Get.replace<CredentialRepository>(ThrowingCredentialRepository(secret));
      final ctrl = await arrangeOnCodeScreen(
        auth: ScriptedAuthClient(),
        session: session,
      );

      await ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        session.executeCalls,
        0,
        reason: 'a session fetch would run against credentials that were '
            'never stored, and the app would look signed in until restart',
      );
      expect(ctrl.error, isNotNull);
      expect(
        ctrl.error,
        isNot(contains(secret)),
        reason: 'the persistence failure text must not reach the user',
      );
      expect(
        ctrl.verifying,
        isFalse,
        reason: 'the user must get a usable Verify button back',
      );
      ctrl.dispose();
    });

    test('an account write failure does not report success', () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      Get.replace<AccountRepository>(
        ThrowingAccountRepository('ACCOUNT-WRITE-MARKER-999'),
      );
      final ctrl = await arrangeOnCodeScreen(
        auth: ScriptedAuthClient(),
        session: session,
      );

      await ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(session.executeCalls, 0);
      expect(ctrl.error, isNotNull);
      expect(ctrl.verifying, isFalse);
      ctrl.dispose();
    });

    test('a retry after a write failure succeeds', () async {
      final session = ControllableGetSessionInteractor();
      addTearDown(session.close);
      final brokenCredentials = ThrowingCredentialRepository('FIRST-ATTEMPT');
      Get.replace<CredentialRepository>(brokenCredentials);
      final ctrl = await arrangeOnCodeScreen(
        auth: ScriptedAuthClient(),
        session: session,
      );

      await ctrl.verifyCode();
      expect(ctrl.error, isNotNull);

      // The storage layer recovers (a transient failure, a full disk that was
      // cleared); the same code must sign in normally.
      Get.replace<CredentialRepository>(FakeCredentialRepository());
      await ctrl.verifyCode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(session.executeCalls, 1);
      expect(ctrl.error, isNull);
      ctrl.dispose();
    });
  });

  group('dispose', () {
    test('disposes controllers', () {
      final ctrl = TwakeWelcomeController(authClient: client);
      ctrl.phoneController.text = 'test';
      ctrl.codeController.text = 'test';
      ctrl.dispose();
    });
  });

  group('handleFailureViewState', () {
    test('GetSessionFailure shows error and blocks navigation', () {
      controller.handleFailureViewState(
        GetSessionFailure(Exception('bad credentials')),
      );
      expect(controller.error, isNotNull);
    });

    test('GetSessionFailure error copy carries no failure detail', () {
      // The user-visible string is the only thing a screenshot or a support
      // reply can leak, so it must not name the internal failure type either.
      const secret = 'BAD-CREDENTIALS-MARKER-777';
      controller.handleFailureViewState(
        GetSessionFailure(Exception(secret)),
      );

      final error = controller.error;
      expect(error, isNotNull);
      expect(error, isNot(contains(secret)));
      expect(
        error,
        isNot(contains('GetSessionFailure')),
        reason: 'the failure type is a diagnostic detail, not user copy',
      );
    });

    test('GetSessionFailure is logged without the failure payload', () {
      // GetSessionFailure wraps whatever the session request threw, which can
      // be a 401 body, a Basic-auth header, or a URL with credentials in it.
      const secret = 'BASIC-AUTH-LEAK-MARKER-321';
      final logs = _CapturingLogHandler();
      AppLoggerRegistry.instance.registerHandler(logs);
      addTearDown(AppLoggerRegistry.instance.resetForTesting);

      controller.handleFailureViewState(
        GetSessionFailure(Exception(secret)),
      );

      expect(
        logs.everything,
        isNot(contains(secret)),
        reason: 'the session failure payload must never reach a log sink',
      );
      expect(
        logs.records.where((r) => r.level == Level.error),
        isNotEmpty,
        reason: 'the failure must still be reported, as a fixed event name',
      );
      expect(
        logs.everything,
        contains('GetSessionFailure'),
        reason: 'the safe category is what makes the record diagnosable',
      );
    });

    test('UpdateAccountCacheFailure delegates to super (no error set)', () {
      final fakeSession = MockSession();

      controller.handleFailureViewState(
        UpdateAccountCacheFailure(
          session: fakeSession,
          apiUrl: 'https://localhost',
          exception: Exception('cache write failed'),
        ),
      );

      expect(controller.error, isNull);
    });
  });

  group('OTP persistence', () {
    test('saves account, baseUrl, and credentials on OTP verify', () async {
      final fakeAccountRepo = Get.find<AccountRepository>() as FakeAccountRepository;
      final fakeCredentialRepo = Get.find<CredentialRepository>() as FakeCredentialRepository;

      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});
      adapter.onPost('/v1/otp/verify', (server) => server.reply(200, {
        'accessToken': 'jwt',
        'jmap': {
          'sessionUrl': 'https://jmap.numberinbox.com/.well-known/jmap',
          'username': '+66812345678@numberinbox.test',
          'credential': 'app_aaaasecret',
        }
      }), data: {'e164': '+66812345678', 'code': '123456'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '123456';
      await controller.verifyCode();

      expect(fakeCredentialRepo.savedBaseUrl, isNotNull);
      expect(fakeCredentialRepo.savedBaseUrl!.host, 'jmap.numberinbox.com');
      expect(fakeCredentialRepo.storedAuth, isNotNull);
      expect(fakeCredentialRepo.storedAuth!.username, '+66812345678@numberinbox.test');
      expect(fakeCredentialRepo.storedAuth!.password, 'app_aaaasecret');
      expect(fakeAccountRepo.savedAccount, isNotNull);
      expect(fakeAccountRepo.savedAccount!.authenticationType, AuthenticationType.basic);
      expect(fakeAccountRepo.savedAccount!.isSelected, isTrue);
    });
  });
}
