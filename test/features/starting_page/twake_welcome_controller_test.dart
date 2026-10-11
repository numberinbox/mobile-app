import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/data/utils/device_manager.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
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

  final _controller = StreamController<Either<Failure, Success>>();
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
  OtpSession? session;

  @override
  Future<OtpSession> verifyOtp(String rawE164, String code, {String? deviceId}) async {
    verifyCalls++;
    final error = verifyError;
    if (error != null) throw error;
    return session ??
        const OtpSession(
          accessToken: 'jwt',
          username: '+66812345678@numberinbox.test',
          sessionUrl: 'https://localhost/.well-known/jmap',
          credential: 'app_secret',
        );
  }

  @override
  Future<void> startOtp(String rawE164) async {}
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
      expect(controller.error, contains('GetSessionFailure'));
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
          'sessionUrl': 'https://localhost/.well-known/jmap',
          'username': '+66812345678@numberinbox.test',
          'credential': 'app_aaaasecret',
        }
      }), data: {'e164': '+66812345678', 'code': '123456'});

      controller.phoneController.text = '812345678';
      await controller.sendCode();

      controller.codeController.text = '123456';
      await controller.verifyCode();

      expect(fakeCredentialRepo.savedBaseUrl, isNotNull);
      expect(fakeCredentialRepo.savedBaseUrl!.host, 'localhost');
      expect(fakeCredentialRepo.storedAuth, isNotNull);
      expect(fakeCredentialRepo.storedAuth!.username, '+66812345678@numberinbox.test');
      expect(fakeCredentialRepo.storedAuth!.password, 'app_aaaasecret');
      expect(fakeAccountRepo.savedAccount, isNotNull);
      expect(fakeAccountRepo.savedAccount!.authenticationType, AuthenticationType.basic);
      expect(fakeAccountRepo.savedAccount!.isSelected, isTrue);
    });
  });
}
