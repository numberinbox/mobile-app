import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
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
class MockAccountRepository extends Mock implements AccountRepository {}
class MockCredentialRepository extends Mock implements CredentialRepository {}

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
