import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
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
    testWidgets('renders light brand background', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders logo', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders NumberInbox branding text', (tester) async {
      await pumpScreen(tester);
      expect(find.byWidgetPredicate((widget) =>
        widget is SvgPicture && widget.semanticsLabel == 'NumberInbox'),
        findsOneWidget);
      expect(find.text('Email, reimagined with your number.'), findsOneWidget);
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
    Future<void> pumpScreenAsThailand(WidgetTester tester) async {
      await pumpScreen(tester);
      Get.find<TwakeWelcomeController>().onCountrySelected(
        countries.firstWhere((c) => c.code == 'TH'),
      );
      await tester.pump();
    }

    testWidgets('send code transitions to code phase', (tester) async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(200, {'ok': true}),
          data: {'e164': '+66812345678'});

      await pumpScreenAsThailand(tester);
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

      await pumpScreenAsThailand(tester);
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('otp_error')), findsOneWidget);
    });

    testWidgets('rate limit shows cooldown message', (tester) async {
      adapter.onPost('/v1/otp/start',
          (server) => server.reply(429, {'error': 'rate_limited'}),
          data: {'e164': '+66812345678'});

      await pumpScreenAsThailand(tester);
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

      await pumpScreenAsThailand(tester);
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

  group('welcome flow primary action', () {
    /// The branded decoration painted behind a welcome-flow CTA.
    DecoratedBox brandedDecorationOf(WidgetTester tester, String key) {
      final button = find.byKey(Key(key));
      final decorationFinder = find.ancestor(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) => widget is DecoratedBox && widget.decoration is BoxDecoration,
        ),
      );
      final boxes = tester.widgetList<DecoratedBox>(decorationFinder).toList();
      for (final box in boxes.reversed) {
        final decoration = box.decoration as BoxDecoration;
        if (decoration.gradient != null) return box;
      }
      throw StateError('no gradient DecoratedBox found above $key');
    }

    List<Color> gradientStopsOf(WidgetTester tester, String key) {
      final decoration =
          brandedDecorationOf(tester, key).decoration as BoxDecoration;
      return decoration.gradient!.colors.toList(growable: false);
    }

    double cornerRadiusOf(WidgetTester tester, String key) {
      final decoration =
          brandedDecorationOf(tester, key).decoration as BoxDecoration;
      final radius = (decoration.borderRadius as BorderRadius?) ?? BorderRadius.zero;
      return radius.topLeft.x;
    }

    Color labelColorOf(WidgetTester tester, String key) {
      final button = tester.widget<FilledButton>(find.byKey(Key(key)));
      return button.style!.foregroundColor!.resolve({})!;
    }

    Future<void> pumpCodePhase(WidgetTester tester) async {
      adapter.onPost(
        '/v1/otp/start',
        (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'},
      );
      await pumpScreen(tester);
      Get.find<TwakeWelcomeController>().onCountrySelected(
        countries.firstWhere((c) => c.code == 'TH'),
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('otp_verify_cta')), findsOneWidget);
    }

    testWidgets('send code and verify share the branded gradient', (tester) async {
      await pumpScreen(tester);
      final sendStops = gradientStopsOf(tester, 'otp_send_cta');

      await pumpCodePhase(tester);
      final verifyStops = gradientStopsOf(tester, 'otp_verify_cta');

      expect(
        verifyStops,
        sendStops,
        reason: 'the Verify button must use the same gradient as Send code',
      );
      expect(sendStops, [NumberInboxPalette.actionGreen, NumberInboxPalette.actionBlue]);
    });

    testWidgets('send code and verify share the same geometry', (tester) async {
      await pumpScreen(tester);
      final sendSize = tester.getSize(find.byKey(const Key('otp_send_cta')));
      final sendRadius = cornerRadiusOf(tester, 'otp_send_cta');

      await pumpCodePhase(tester);
      final verifySize = tester.getSize(find.byKey(const Key('otp_verify_cta')));
      final verifyRadius = cornerRadiusOf(tester, 'otp_verify_cta');

      expect(verifySize.height, greaterThanOrEqualTo(54));
      expect(verifySize.height, closeTo(sendSize.height, 0.5));
      expect(verifySize.width, closeTo(sendSize.width, 0.5));
      expect(sendRadius, 14);
      expect(verifyRadius, sendRadius);
    });

    testWidgets('both phases render a white enabled label', (tester) async {
      await pumpScreen(tester);
      expect(labelColorOf(tester, 'otp_send_cta'), Colors.white);

      await pumpCodePhase(tester);
      expect(labelColorOf(tester, 'otp_verify_cta'), Colors.white);
    });

    testWidgets('loading state shows a white spinner and blocks repeat taps',
        (tester) async {
      var startCalls = 0;
      // A long response delay keeps the request in flight, so the CTA stays in
      // its loading state while the assertions run.
      adapter.onPost(
        '/v1/otp/start',
        (server) {
          startCalls++;
          server.reply(
            200,
            {'ok': true},
            delay: const Duration(seconds: 30),
          );
        },
        data: {'e164': '+66812345678'},
      );

      await pumpScreen(tester);
      Get.find<TwakeWelcomeController>().onCountrySelected(
        countries.firstWhere((c) => c.code == 'TH'),
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
      await tester.tap(find.byKey(const Key('otp_send_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(startCalls, 1);

      final progress = find.descendant(
        of: find.byKey(const Key('otp_send_cta')),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(progress, findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(progress);
      expect(
        spinner.valueColor?.value,
        Colors.white,
        reason: 'the spinner must be visibly white on the branded background',
      );
      expect(
        gradientStopsOf(tester, 'otp_send_cta'),
        [NumberInboxPalette.actionGreen, NumberInboxPalette.actionBlue],
        reason: 'loading must keep the branded gradient, not fall back to a '
            'neutral fill that would swallow the white spinner',
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('otp_send_cta'))).onPressed,
        isNull,
        reason: 'a loading CTA must not be interactive',
      );

      await tester.tap(find.byKey(const Key('otp_send_cta')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        startCalls,
        1,
        reason: 'a busy CTA must not send a second OTP request',
      );

      // Let the delayed response land so no request outlives the test.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
    });
  });
}
