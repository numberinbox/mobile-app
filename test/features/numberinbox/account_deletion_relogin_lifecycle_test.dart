import 'dart:async';

import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/data/utils/device_manager.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:model/account/authentication_type.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_oidc_user_info_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/update_account_cache_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_page.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_bindings.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

class _MockDynamicUrlInterceptors extends Mock implements DynamicUrlInterceptors {}
class _MockLogoutOidcInteractor extends Mock implements LogoutOidcInteractor {}
class _MockDeleteAuthorityOidcInteractor extends Mock implements DeleteAuthorityOidcInteractor {}
class _MockGetAuthenticatedAccountInteractor extends Mock implements GetAuthenticatedAccountInteractor {}
class _MockGetOidcUserInfoInteractor extends Mock implements GetOidcUserInfoInteractor {}
class _MockUpdateAccountCacheInteractor extends Mock implements UpdateAccountCacheInteractor {}
class _MockGetSessionInteractor extends Mock implements GetSessionInteractor {}
class _MockAppToast extends Mock implements AppToast {}
class _MockResponsiveUtils extends Mock implements ResponsiveUtils {}
class _MockUuid extends Mock implements Uuid {}
class _MockDeviceManager extends Mock implements DeviceManager {}
class _AuthTestController extends BaseController {}

/// Working fakes for the local-cleanup path: plain mocks return null for
/// non-nullable members, which aborts `clearLocalSessionData` before the
/// credential delete ever runs — hiding what the cleanup actually clears.
class _FakeCachingManager extends Mock implements CachingManager {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> closeHive({bool isolated = true}) async {}
}

class _FakeLanguageCacheManager extends Mock implements LanguageCacheManager {
  @override
  Future<void> removeLanguage() async {}
}

class _FakeAuthorizationInterceptors extends Mock
    implements AuthorizationInterceptors {
  AuthenticationType authenticationTypeValue = AuthenticationType.basic;

  @override
  AuthenticationType get authenticationType => authenticationTypeValue;

  @override
  void clear() => authenticationTypeValue = AuthenticationType.none;
}

/// Dashboard double for the deletion page. `clearAllData` is controllable via
/// the injected callback (routed through the shared manager so concurrent
/// logouts coalesce), the welcome redirect is the real inherited
/// implementation, and every other interface member falls through.
class _FakeDashboardController extends BaseController
    implements ManageAccountDashBoardController {
  _FakeDashboardController(this._onClearData);

  final Future<void> Function() _onClearData;

  @override
  Future<void> clearAllData() => _onClearData();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} was not stubbed');
}

class _CountingTwakeAppManager extends TwakeAppManager {
  int cleanupExecutions = 0;

  @override
  Future<void> runClearDataOnce(Future<void> Function() clearData) {
    return super.runClearDataOnce(() {
      cleanupExecutions++;
      return clearData();
    });
  }
}

int welcomeControllerCreations = 0;
int welcomeControllerClosures = 0;

class _InstrumentedTwakeWelcomeController extends TwakeWelcomeController {
  _InstrumentedTwakeWelcomeController({required super.authClient});

  @override
  void onClose() {
    welcomeControllerClosures++;
    super.onClose();
  }
}

class _InstrumentedWelcomeBindings extends TwakeWelcomeBindings {
  _InstrumentedWelcomeBindings(this._dio);

  final Dio _dio;

  @override
  void dependencies() {
    Get.lazyPut<NumberInboxAuthClient>(() => NumberInboxAuthClient(_dio));
    Get.lazyPut<TwakeWelcomeController>(() {
      welcomeControllerCreations++;
      return _InstrumentedTwakeWelcomeController(
        authClient: Get.find<NumberInboxAuthClient>(),
      );
    });
  }
}

/// Stateful credential storage, seeded like a signed-in session. The page
/// reads it and the real [DeleteCredentialInteractor] writes to it, so tests
/// can assert that cleanup actually removed the stored credentials.
class _Credentials implements CredentialRepository {
  _Credentials({AuthenticationInfoCache? stored}) : _stored = stored;

  AuthenticationInfoCache? _stored;
  int removeAuthenticationInfoCalls = 0;

  AuthenticationInfoCache? get stored => _stored;

  @override
  Future<AuthenticationInfoCache> getAuthenticationInfoStored() async =>
      _stored ??
      AuthenticationInfoCache('+66812345678@numberinbox.test', 'secret');

  @override
  Future<Uri> getBaseUrl() async => Uri.parse('https://jmap.numberinbox.test');
  @override
  Future removeBaseUrl() async {}
  @override
  Future<void> removeAuthenticationInfo() async {
    removeAuthenticationInfoCalls++;
    _stored = null;
  }
  @override
  Future saveBaseUrl(Uri baseUrl) async {}
  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async {
    _stored = info;
  }
}

class _ControllableDeletionClient extends AccountDeletionClient {
  _ControllableDeletionClient() : super(Dio());

  final statusCompleter = Completer<String>();
  int statusCalls = 0;

  @override
  Future<AccountDeletionRequest> request({
    required String confirmE164,
    required String username,
    required String password,
    required String idempotencyKey,
  }) async =>
      const AccountDeletionRequest('request-id', 'status-token');

  @override
  Future<String> status(String requestId, String statusToken) {
    statusCalls++;
    return statusCompleter.future;
  }
}

const _accountScope = '+66812345678@numberinbox.test';
const _requestIdKey = 'numberinbox.accountDeletion.$_accountScope.requestId';
const _statusTokenKey = 'numberinbox.accountDeletion.$_accountScope.statusToken';
const _idempotencyKey = 'numberinbox.accountDeletion.$_accountScope.idempotencyKey';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late _CountingTwakeAppManager appManager;
  late _FakeDashboardController dashboardController;
  late _AuthTestController authController;
  late Completer<void> dashboardCleanup;
  late _Credentials credentials;
  final testTheme = ThemeUtils.buildAppTheme();

  void registerStubs() {
    Get.put<CachingManager>(_FakeCachingManager());
    Get.put<LanguageCacheManager>(_FakeLanguageCacheManager());
    Get.put<AppToast>(_MockAppToast());
    Get.put<ImagePaths>(ImagePaths());
    Get.put<ResponsiveUtils>(_MockResponsiveUtils());
    Get.put<Uuid>(_MockUuid());
    Get.put(ToastManager(_MockAppToast(), ImagePaths()));
    appManager = _CountingTwakeAppManager();
    Get.put<TwakeAppManager>(appManager);
    credentials = _Credentials(
        stored: AuthenticationInfoCache('+66812345678@numberinbox.test', 'secret'));
    Get.put<DeleteCredentialInteractor>(DeleteCredentialInteractor(credentials));
    Get.put<LogoutOidcInteractor>(_MockLogoutOidcInteractor());
    Get.put<DeleteAuthorityOidcInteractor>(_MockDeleteAuthorityOidcInteractor());
    Get.put<GetAuthenticatedAccountInteractor>(_MockGetAuthenticatedAccountInteractor());
    Get.put<GetOidcUserInfoInteractor>(_MockGetOidcUserInfoInteractor());
    Get.put<UpdateAccountCacheInteractor>(_MockUpdateAccountCacheInteractor());
    Get.put<GetSessionInteractor>(_MockGetSessionInteractor());
    Get.put<DynamicUrlInterceptors>(_MockDynamicUrlInterceptors());
    Get.put<AuthorizationInterceptors>(_FakeAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(_FakeAuthorizationInterceptors(),
        tag: BindingTag.isolateTag);
    Get.put<DeviceManager>(_MockDeviceManager());

    authController = _AuthTestController();
    Get.put<BaseController>(authController, tag: 'auth');

    dashboardCleanup = Completer<void>();
    dashboardController = _FakeDashboardController(
        () => appManager.runClearDataOnce(() => dashboardCleanup.future));
    Get.put<ManageAccountDashBoardController>(dashboardController);
  }

  Future<void> pumpApp(WidgetTester tester, {required _ControllableDeletionClient client}) async {
    registerStubs();
    await tester.pumpWidget(GetMaterialApp(
      theme: testTheme,
      initialRoute: AppRoutes.dashboard,
      getPages: [
        GetPage(
          name: AppRoutes.dashboard,
          page: () => const Scaffold(body: Center(child: Text('DASHBOARD'))),
        ),
        GetPage(
          name: AppRoutes.twakeWelcome,
          page: () => const TwakeWelcomeView(),
          binding: _InstrumentedWelcomeBindings(dio),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    // Production opens the deletion page with an unnamed MaterialPageRoute
    // (settings_first_level_view), not a named GetPage route.
    Navigator.of(tester.element(find.text('DASHBOARD'))).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDeletionPage(
          client: client,
          credentialRepository: credentials,
        ),
      ),
    );
    // The deletion page shows an indeterminate spinner while status is
    // pending, so pumpAndSettle would never return — use bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> expectWorkingPhoneLogin(WidgetTester tester) async {
    expect(Get.currentRoute, AppRoutes.twakeWelcome);
    expect(find.byKey(const Key('otp_phone_field')), findsOneWidget);
    expect(Get.key.currentState!.canPop(), isFalse,
        reason: 'authenticated pages must not remain on the back stack');
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.pump();
    expect(Get.find<TwakeWelcomeController>().phoneController.text, '812345678');
  }

  setUp(() {
    welcomeControllerCreations = 0;
    welcomeControllerClosures = 0;
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    FlutterSecureStorage.setMockInitialValues({
      _requestIdKey: 'request-id',
      _statusTokenKey: 'status-token',
      _idempotencyKey: 'idem-key',
    });
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('deletion completion reaches a working phone-login route and clears pending keys',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);
    expect(client.statusCalls, 1);

    client.statusCompleter.complete('completed');
    await tester.pump();
    dashboardCleanup.complete();
    await tester.pumpAndSettle();

    await expectWorkingPhoneLogin(tester);

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: _requestIdKey), isNull);
    expect(await storage.read(key: _statusTokenKey), isNull);
    expect(await storage.read(key: _idempotencyKey), isNull);
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);
  });

  testWidgets(
      'authentication failure redirect first leaves one login route when deletion finishes later',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    // The credential failure wins the race before deletion polls its status.
    final authFuture = authController.clearDataAndGoToLoginPage();
    await tester.pumpAndSettle();
    await authFuture;
    expect(Get.currentRoute, AppRoutes.twakeWelcome);
    final liveController = Get.find<TwakeWelcomeController>();

    // Deletion completes afterwards while its page is already gone.
    client.statusCompleter.complete('completed');
    await tester.pumpAndSettle();

    await expectWorkingPhoneLogin(tester);
    expect(Get.find<TwakeWelcomeController>(), same(liveController));
    expect(welcomeControllerCreations, 1,
        reason: 'the finished deletion must not replace the existing login route');
    expect(welcomeControllerClosures, 0);
  });

  testWidgets('deletion and authentication failure overlap on one cleanup and one redirect',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    client.statusCompleter.complete('completed');
    await tester.pump();
    expect(appManager.cleanupExecutions, 1, reason: 'deletion cleanup started');

    // The concurrent logout joins the already-running cleanup.
    final authFuture = authController.clearDataAndGoToLoginPage();
    await tester.pump();
    expect(appManager.cleanupExecutions, 1, reason: 'the concurrent logout must join it');

    dashboardCleanup.complete();
    await tester.pumpAndSettle();
    await authFuture;

    await expectWorkingPhoneLogin(tester);
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);
  });

  testWidgets('a later authentication failure after login renders preserves the login controller',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    client.statusCompleter.complete('completed');
    await tester.pump();
    dashboardCleanup.complete();
    await tester.pumpAndSettle();
    await expectWorkingPhoneLogin(tester);

    final liveController = Get.find<TwakeWelcomeController>();

    await authController.clearDataAndGoToLoginPage();
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.twakeWelcome);
    expect(Get.find<TwakeWelcomeController>(), same(liveController));
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);
  });

  testWidgets('deletion page closed during pending cleanup does not navigate again',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    client.statusCompleter.complete('completed');
    await tester.pump();
    // Deletion is now awaiting its cleanup; a competing logout removes the page.
    Get.offAllNamed(AppRoutes.dashboard);
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);

    dashboardCleanup.complete();
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget,
        reason: 'a disposed deletion page must not issue a second redirect');
    expect(Get.currentRoute, AppRoutes.dashboard);
    expect(welcomeControllerCreations, 0);
  });

  testWidgets(
      'completed deletion still clears local data and reaches login when the dashboard controller is gone',
      (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    // The dashboard/settings controller can be torn down while deletion is
    // still polling; a completed deletion must not silently stop there.
    Get.delete<ManageAccountDashBoardController>();

    client.statusCompleter.complete('completed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Fail fast with bounded pumps: while the deletion page is still shown
    // its indeterminate spinner would keep pumpAndSettle from ever settling.
    expect(find.byType(AccountDeletionPage), findsNothing,
        reason: 'completed deletion must not stop silently on the deletion page');
    await tester.pumpAndSettle();

    await expectWorkingPhoneLogin(tester);
    expect(credentials.removeAuthenticationInfoCalls, 1,
        reason: 'the real delete-credential interactor must run');
    expect(credentials.stored, isNull,
        reason: 'fallback cleanup must delete the stored credentials');
    expect(Get.find<AuthorizationInterceptors>().authenticationType,
        AuthenticationType.none,
        reason: 'fallback cleanup must clear the authentication state');
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);
  });

  testWidgets('a failed deletion status does not report completion', (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    client.statusCompleter.complete('failed');
    // The page keeps polling, so bounded pumps instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('could not finish'), findsOneWidget);
    expect(find.byType(AccountDeletionPage), findsOneWidget);
    expect(find.byKey(const Key('otp_phone_field')), findsNothing);
    expect(await const FlutterSecureStorage().read(key: _requestIdKey), isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a pending deletion status keeps waiting without completing', (tester) async {
    final client = _ControllableDeletionClient();
    await pumpApp(tester, client: client);

    client.statusCompleter.complete('pending');
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(AccountDeletionPage), findsOneWidget);
    expect(client.statusCalls, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('otp_phone_field')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
