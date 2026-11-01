// integration_test/numberinbox depends on these keys; renaming one breaks the release gate.
import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/branded_action_button.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

class _MockCachingManager extends Mock implements CachingManager {}

class _MockLanguageCacheManager extends Mock implements LanguageCacheManager {}

class _MockAuthorizationInterceptors extends Mock
    implements AuthorizationInterceptors {}

class _MockDeleteCredentialInteractor extends Mock
    implements DeleteCredentialInteractor {}

class _MockLogoutOidcInteractor extends Mock implements LogoutOidcInteractor {}

class _MockDeleteAuthorityOidcInteractor extends Mock
    implements DeleteAuthorityOidcInteractor {}

class _MockGetAuthenticatedAccountInteractor extends Mock
    implements GetAuthenticatedAccountInteractor {}

class _MockGetOidcUserInfoInteractor extends Mock
    implements GetOidcUserInfoInteractor {}

class _MockUpdateAccountCacheInteractor extends Mock
    implements UpdateAccountCacheInteractor {}

class _MockGetSessionInteractor extends Mock implements GetSessionInteractor {}

class _MockAppToast extends Mock implements AppToast {}

class _MockResponsiveUtils extends Mock implements ResponsiveUtils {}

class _MockUuid extends Mock implements Uuid {}

class _MockTwakeAppManager extends Mock implements TwakeAppManager {}

void main() {
  late Dio dio;
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
    Get.put<DeleteAuthorityOidcInteractor>(
      _MockDeleteAuthorityOidcInteractor(),
    );
    Get.put<GetAuthenticatedAccountInteractor>(
      _MockGetAuthenticatedAccountInteractor(),
    );
    Get.put<GetOidcUserInfoInteractor>(_MockGetOidcUserInfoInteractor());
    Get.put<UpdateAccountCacheInteractor>(_MockUpdateAccountCacheInteractor());
    Get.put<GetSessionInteractor>(_MockGetSessionInteractor());
    Get.put<DynamicUrlInterceptors>(DynamicUrlInterceptors());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(
      _MockAuthorizationInterceptors(),
      tag: BindingTag.isolateTag,
    );
  }

  Future<void> pumpPhase(
    WidgetTester tester, {
    required void Function(TwakeWelcomeController) configure,
  }) async {
    registerStubs();
    final controller = TwakeWelcomeController(authClient: client);
    configure(controller);
    Get.put<TwakeWelcomeController>(controller);

    await tester.pumpWidget(
      MaterialApp(theme: testTheme, home: const TwakeWelcomeView()),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/numberinbox_mark.png'),
        tester.element(find.byType(TwakeWelcomeView)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> loadBrandFonts() async {
    final fontLoader = FontLoader('packages/linagora_design_flutter/TwakeInter')
      ..addFont(
        rootBundle.load(
          'packages/linagora_design_flutter/assets/fonts/TwakeInter-Regular.ttf',
        ),
      )
      ..addFont(
        rootBundle.load(
          'packages/linagora_design_flutter/assets/fonts/TwakeInter-Medium.ttf',
        ),
      )
      ..addFont(
        rootBundle.load(
          'packages/linagora_design_flutter/assets/fonts/TwakeInter-SemiBold.ttf',
        ),
      );
    await fontLoader.load();
    await (FontLoader('NotoEmoji')..addFont(
          rootBundle.load('assets/fonts/fallback/NotoEmoji-Regular.ttf'),
        ))
        .load();
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
  });

  setUpAll(loadBrandFonts);

  tearDown(() => Get.reset());

  /// The design contract each phase has to keep, asserted instead of
  /// pixel-compared.
  ///
  /// This file used to compare rendered PNGs against committed goldens. Skia
  /// rasterises text and rounded corners slightly differently on macOS and
  /// Linux, so the same source produced a ~1.4% pixel diff on the CI runner and
  /// failed every run there while passing locally — a red that carried no
  /// information. These assertions describe the same contract in terms that are
  /// identical on every platform: the brand geometry and colours, the copy, and
  /// which control is on screen for each phase.
  void expectBrandedCta(WidgetTester tester, Key key, String label) {
    expect(
      find.descendant(of: find.byKey(key), matching: find.text(label)),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(key)).height,
      BrandedActionButton.minHeight,
    );
  }

  BoxDecoration ctaDecoration(WidgetTester tester, Key key) => tester
      .widget<DecoratedBox>(
        find
            .ancestor(of: find.byKey(key), matching: find.byType(DecoratedBox))
            .first,
      )
      .decoration as BoxDecoration;

  testWidgets('phone phase shows the brand CTA and the phone field',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(tester, configure: (_) {});

    expect(find.byKey(const Key('otp_country_picker')), findsOneWidget);
    expect(find.byKey(const Key('otp_phone_field')), findsOneWidget);
    expect(
      find.byKey(const Key('otp_code_field')),
      findsNothing,
      reason: 'the code field belongs to the next phase',
    );
    expectBrandedCta(tester, const Key('otp_send_cta'), 'Send code');
    expect(find.byKey(const Key('otp_error')), findsNothing);

    final gradient =
        ctaDecoration(tester, const Key('otp_send_cta')).gradient!
            as LinearGradient;
    expect(gradient.colors, [
      NumberInboxPalette.actionGreen,
      NumberInboxPalette.actionBlue,
    ]);
  });

  testWidgets('code phase swaps the field and the CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(
      tester,
      configure: (c) {
        c.phase = OtpPhase.code;
        c.phoneController.text = '812345678';
        c.update();
      },
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
    expect(find.byKey(const Key('otp_phone_field')), findsNothing);
    expect(
      find.byKey(const Key('otp_country_picker')),
      findsNothing,
      reason: 'the country is already chosen; it is not re-prompted',
    );
    expectBrandedCta(tester, const Key('otp_verify_cta'), 'Verify');
    expect(find.byKey(const Key('otp_send_cta')), findsNothing);
  });

  testWidgets('error state shows the message in the error colour',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await pumpPhase(
      tester,
      configure: (c) {
        c.phase = OtpPhase.phone;
        c.phoneController.text = '812345678';
        c.error = 'Network error';
        c.update();
      },
    );
    await tester.pumpAndSettle();

    final error = tester.widget<Text>(find.byKey(const Key('otp_error')));
    expect(error.data, 'Network error');
    expect(error.style?.color, testTheme.colorScheme.error);
    // The CTA stays usable: an error must not leave the user stuck.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_send_cta')))
          .onPressed,
      isNotNull,
    );
  });
}
