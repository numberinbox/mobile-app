import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
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
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

class _MockCachingManager extends Mock implements CachingManager {}
class _MockLanguageCacheManager extends Mock implements LanguageCacheManager {}
class _MockAuthorizationInterceptors extends Mock implements AuthorizationInterceptors {}
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

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late NumberInboxAuthClient client;

  final testTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B3D2E),
      primary: const Color(0xFF0B3D2E),
      surface: const Color(0xFF111111),
      error: const Color(0xFFFF0000),
      outline: const Color(0xFF888888),
      onSurface: const Color(0xFFCCCCCC),
    ),
  );

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
    Get.put<DynamicUrlInterceptors>(DynamicUrlInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors(), tag: BindingTag.isolateTag);
  }

  Future<void> pumpPhase(
    WidgetTester tester, {
    required void Function(TwakeWelcomeController) configure,
  }) async {
    registerStubs();
    final controller = TwakeWelcomeController(authClient: client);
    configure(controller);
    Get.put<TwakeWelcomeController>(controller);

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const TwakeWelcomeView(),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
  });

  tearDown(() => Get.reset());

  testWidgets('golden: phone phase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(tester, configure: (_) {});
    await expectLater(
      find.byType(TwakeWelcomeView),
      matchesGoldenFile('goldens/twake_welcome_phone_phase.png'),
    );
  });

  testWidgets('golden: code phase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(tester, configure: (c) {
      c.phase = OtpPhase.code;
      c.phoneController.text = '812345678';
      c.update();
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TwakeWelcomeView),
      matchesGoldenFile('goldens/twake_welcome_code_phase.png'),
    );
  });

  testWidgets('golden: error state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(tester, configure: (c) {
      c.phase = OtpPhase.phone;
      c.phoneController.text = '812345678';
      c.error = 'Network error';
      c.update();
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(TwakeWelcomeView),
      matchesGoldenFile('goldens/twake_welcome_error_state.png'),
    );
  });
}
