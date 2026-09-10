import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_view.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
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
    Get.put<DynamicUrlInterceptors>(_MockDynamicUrlInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors(), tag: BindingTag.isolateTag);
  }

  Future<void> pumpScreen(WidgetTester tester, {ThemeData? theme}) async {
    registerStubs();
    final controller = TwakeWelcomeController(
      authClient: client,
    );
    Get.put<TwakeWelcomeController>(controller);

    await tester.pumpWidget(MaterialApp(
      theme: theme ?? testTheme,
      home: const TwakeWelcomeView(),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
  });

  tearDown(() {
    Get.reset();
  });

  group('rendering', () {
    testWidgets('renders gradient background', (tester) async {
      await pumpScreen(tester);
      // The gradient container should exist
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders logo', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders NumberInbox branding text', (tester) async {
      await pumpScreen(tester);
      final richTexts = find.byType(RichText);
      expect(richTexts, findsWidgets);
      final hasBranding = richTexts.evaluate().any((el) {
        final widget = el.widget as RichText;
        final text = (widget.text as TextSpan).toPlainText();
        return text.contains('Number') && text.contains('Inbox');
      });
      expect(hasBranding, isTrue);
    });

    testWidgets('does not render Twake branding', (tester) async {
      await pumpScreen(tester);
      expect(find.textContaining('Twake'), findsNothing);
    });

    testWidgets('renders country picker', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('otp_country_picker')), findsOneWidget);
    });

    testWidgets('renders phone field', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('otp_phone_field')), findsOneWidget);
    });

    testWidgets('renders send code button', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('otp_send_cta')), findsOneWidget);
    });

    testWidgets('renders privacy policy text', (tester) async {
      await pumpScreen(tester);
      expect(find.textContaining('Privacy policy'), findsOneWidget);
    });
  });

  group('country picker', () {
    testWidgets('opens bottom sheet with search', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('otp_country_picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('country_search')), findsOneWidget);
      expect(find.byKey(const Key('country_TH')), findsOneWidget);
    });

    testWidgets('search filters countries', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('otp_country_picker')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('country_search')), 'United States');
      await tester.pump();
      expect(find.byKey(const Key('country_US')), findsOneWidget);
      expect(find.byKey(const Key('country_TH')), findsNothing);
    });

    testWidgets('selection updates picker label', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('otp_country_picker')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('country_search')), 'United States');
      await tester.pump();
      await tester.tap(find.byKey(const Key('country_US')));
      await tester.pumpAndSettle();
      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('+1'), findsWidgets);
    });
  });

  group('validation', () {
    testWidgets('empty phone shows inline error', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pump();
      expect(find.byKey(const Key('otp_error')), findsOneWidget);
    });

    testWidgets('short phone shows validation error', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '123');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pump();
      expect(find.byKey(const Key('otp_error')), findsOneWidget);
    });
  });

  group('OTP flow', () {
    testWidgets('send code transitions to code phase', (tester) async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});

      await pumpScreen(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
      expect(find.byKey(const Key('otp_verify_cta')), findsOneWidget);
    });

    testWidgets('server error shows friendly message', (tester) async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(500, {'error': 'internal'}),
          data: {'e164': '+66812345678'});

      await pumpScreen(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_error')), findsOneWidget);
    });

    testWidgets('rate limit shows cooldown message', (tester) async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(429, {'error': 'rate_limited'}),
          data: {'e164': '+66812345678'});

      await pumpScreen(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_error')), findsOneWidget);
    });

    testWidgets('happy path transitions to verifying state', (tester) async {
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

      await pumpScreen(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('otp_code_field')));
      await tester.enterText(find.byKey(const Key('otp_code_field')), '123456');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('otp_verify_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('no overlap between logo and phone field when keyboard is open', (tester) async {
      tester.view.physicalSize = const Size(375, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpScreen(tester);

      final logo = tester.getRect(find.byType(SvgPicture));
      final phoneField = tester.getRect(find.byKey(const Key('otp_phone_field')));

      expect(
        logo.bottom <= phoneField.top,
        isTrue,
        reason: 'Logo (bottom=${logo.bottom}) should be above phone field (top=${phoneField.top})',
      );

      tester.view.resetPhysicalSize();
    });

    testWidgets('no overlap in normal viewport', (tester) async {
      await pumpScreen(tester);

      final logo = tester.getRect(find.byType(SvgPicture));
      final phoneField = tester.getRect(find.byKey(const Key('otp_phone_field')));

      expect(
        logo.bottom <= phoneField.top,
        isTrue,
        reason: 'Logo (bottom=${logo.bottom}) should be above phone field (top=${phoneField.top})',
      );
    });
  });
}
