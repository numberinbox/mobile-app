import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/data/utils/device_manager.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_oidc_user_info_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/update_account_cache_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_bindings.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

class _MockCachingManager extends Mock implements CachingManager {}
class _MockLanguageCacheManager extends Mock implements LanguageCacheManager {}
class _MockAuthorizationInterceptors extends Mock implements AuthorizationInterceptors {}
class _MockDynamicUrlInterceptors extends Mock implements DynamicUrlInterceptors {}
class _MockDeleteCredentialInteractor extends Mock implements DeleteCredentialInteractor {}
class _MockLogoutOidcInteractor extends Mock implements LogoutOidcInteractor {}
class _MockDeleteAuthorityOidcInteractor extends Mock implements DeleteAuthorityOidcInteractor {}
class _MockGetAuthenticatedAccountInteractor extends Mock implements GetAuthenticatedAccountInteractor {}
class _MockGetOidcUserInfoInteractor extends Mock implements GetOidcUserInfoInteractor {}
class _MockUpdateAccountCacheInteractor extends Mock implements UpdateAccountCacheInteractor {}
class _MockGetSessionInteractor extends Mock implements GetSessionInteractor {}
class _MockAppToast extends Mock implements AppToast {}
class _MockResponsiveUtils extends Mock implements ResponsiveUtils {}
class _MockUuid extends Mock implements Uuid {}
class _MockTwakeAppManager extends Mock implements TwakeAppManager {}
class _MockDeviceManager extends Mock implements DeviceManager {}

class _TestDashboardController extends BaseController {}

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

void main() {
  late Dio dio;
  late DioAdapter adapter;
  final testTheme = ThemeUtils.buildAppTheme();

  void registerStubs() {
    Get.put<CachingManager>(_MockCachingManager());
    Get.put<LanguageCacheManager>(_MockLanguageCacheManager());
    Get.put<AppToast>(_MockAppToast());
    Get.put<ImagePaths>(ImagePaths());
    Get.put<ResponsiveUtils>(_MockResponsiveUtils());
    Get.put<Uuid>(_MockUuid());
    Get.put(ToastManager(_MockAppToast(), ImagePaths()));
    Get.put<TwakeAppManager>(_MockTwakeAppManager());
    Get.put<DeleteCredentialInteractor>(_MockDeleteCredentialInteractor());
    Get.put<LogoutOidcInteractor>(_MockLogoutOidcInteractor());
    Get.put<DeleteAuthorityOidcInteractor>(_MockDeleteAuthorityOidcInteractor());
    Get.put<GetAuthenticatedAccountInteractor>(_MockGetAuthenticatedAccountInteractor());
    Get.put<GetOidcUserInfoInteractor>(_MockGetOidcUserInfoInteractor());
    Get.put<UpdateAccountCacheInteractor>(_MockUpdateAccountCacheInteractor());
    Get.put<GetSessionInteractor>(_MockGetSessionInteractor());
    Get.put<DynamicUrlInterceptors>(_MockDynamicUrlInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors(), tag: BindingTag.isolateTag);
    Get.put<DeviceManager>(_MockDeviceManager());
    Get.put(_TestDashboardController());
  }

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  /// Dispatches the redirect through the production entry point, exactly as
  /// an authentication-failure or deletion completion would.
  Future<void> redirectToWelcome({bool popAllRoute = true}) async {
    final controller = Get.isRegistered<TwakeWelcomeController>()
        ? Get.find<TwakeWelcomeController>()
        : Get.find<_TestDashboardController>();
    controller.navigateToTwakeWelcomePage(popAllRoute: popAllRoute);
  }

  setUp(() {
    welcomeControllerCreations = 0;
    welcomeControllerClosures = 0;
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
      'duplicate welcome redirect issued before the next frame keeps the phone field editable',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('DASHBOARD'), findsOneWidget);

    await redirectToWelcome();
    await redirectToWelcome();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_phone_field')), findsOneWidget);
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);
    expect(Get.key.currentState!.canPop(), isFalse,
        reason: 'dashboard must not remain on the back stack');

    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.pump();
    expect(find.text('812345678'), findsOneWidget);
  });

  testWidgets(
      'duplicate welcome redirect after the page rendered preserves the live controller',
      (tester) async {
    await pumpApp(tester);

    await redirectToWelcome();
    await tester.pumpAndSettle();

    final liveController = Get.find<TwakeWelcomeController>();
    expect(welcomeControllerCreations, 1);

    await redirectToWelcome();
    await tester.pumpAndSettle();

    expect(Get.find<TwakeWelcomeController>(), same(liveController));
    expect(welcomeControllerCreations, 1);
    expect(welcomeControllerClosures, 0);

    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.pump();
    expect(liveController.phoneController.text, '812345678');
  });

  testWidgets(
      'duplicate welcome redirect after advancing to OTP keeps the code field editable',
      (tester) async {
    adapter.onPost('/v1/otp/start',
        (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'});

    await pumpApp(tester);

    await redirectToWelcome();
    await tester.pumpAndSettle();

    Get.find<TwakeWelcomeController>().onCountrySelected(
      countries.firstWhere((c) => c.code == 'TH'),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);

    final liveController = Get.find<TwakeWelcomeController>();

    await redirectToWelcome();
    await tester.pumpAndSettle();

    expect(Get.find<TwakeWelcomeController>(), same(liveController));
    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otp_code_field')), '123456');
    await tester.pump();
    expect(liveController.codeController.text, '123456');
  });

  testWidgets(
      'a genuine later dashboard to welcome cycle creates a fresh controller',
      (tester) async {
    await pumpApp(tester);

    await redirectToWelcome();
    await tester.pumpAndSettle();
    final firstController = Get.find<TwakeWelcomeController>();

    Get.offAllNamed(AppRoutes.dashboard);
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(welcomeControllerClosures, 1);

    await redirectToWelcome();
    await tester.pumpAndSettle();

    final secondController = Get.find<TwakeWelcomeController>();
    expect(identical(firstController, secondController), isFalse);
    expect(welcomeControllerCreations, 2);

    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.pump();
    expect(secondController.phoneController.text, '812345678');
  });
}
