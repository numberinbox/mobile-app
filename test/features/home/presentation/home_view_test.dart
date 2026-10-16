import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/cleanup/domain/usecases/cleanup_email_cache_interactor.dart';
import 'package:tmail_ui_user/features/cleanup/domain/usecases/cleanup_recent_login_url_cache_interactor.dart';
import 'package:tmail_ui_user/features/cleanup/domain/usecases/cleanup_recent_login_username_interactor.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/get_session_interactor.dart';
import 'package:tmail_ui_user/features/home/presentation/home_controller.dart';
import 'package:tmail_ui_user/features/home/presentation/home_view.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/authenticate_oidc_on_browser_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/check_oidc_is_available_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_authenticated_account_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_oidc_configuration_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/get_oidc_user_info_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/remove_auth_destination_url_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/update_account_cache_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/utils/email_receive_manager.dart';
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

import 'home_controller_test.mocks.dart';

/// Layout-only driver: skips startup navigation side effects so the geometry
/// assertions are not coupled to controller timing (covered separately).
class _LayoutTestHomeController extends HomeController {
  _LayoutTestHomeController(
    CleanupEmailCacheInteractor cleanupEmailCacheInteractor,
    EmailReceiveManager emailReceiveManager,
    CleanupRecentLoginUrlCacheInteractor cleanupRecentLoginUrlCacheInteractor,
    CleanupRecentLoginUsernameCacheInteractor
        cleanupRecentLoginUsernameCacheInteractor,
    CheckOIDCIsAvailableInteractor checkOIDCIsAvailableInteractor,
    GetOIDCConfigurationInteractor getOIDCConfigurationInteractor,
    AuthenticateOidcOnBrowserInteractor authenticateOidcOnBrowserInteractor,
    RemoveAuthDestinationUrlInteractor removeAuthDestinationUrlInteractor,
  ) : super(
          cleanupEmailCacheInteractor,
          emailReceiveManager,
          cleanupRecentLoginUrlCacheInteractor,
          cleanupRecentLoginUsernameCacheInteractor,
          checkOIDCIsAvailableInteractor,
          getOIDCConfigurationInteractor,
          authenticateOidcOnBrowserInteractor,
          removeAuthDestinationUrlInteractor,
        );

  @override
  void onReady() {}
}

/// Startup alignment: the N/@ mark itself sits at viewport center while the
/// wordmark and spinner appear below it (second startup stage).
void main() {
  final testTheme = ThemeUtils.buildAppTheme();

  Finder imageWithAsset(String assetName) => find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == assetName,
      );

  /// The wordmark is an SvgPicture, which [imageWithAsset] cannot match.
  Finder svgAsset(String assetName) => find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName.contains(
                  assetName.split('/').last,
                ),
      );

  Future<void> pumpHome(WidgetTester tester) async {
    Get.testMode = true;
    final appToast = MockAppToast();
    final imagePaths = MockImagePaths();
    Get.put<GetSessionInteractor>(MockGetSessionInteractor());
    Get.put<GetAuthenticatedAccountInteractor>(
        MockGetAuthenticatedAccountInteractor());
    Get.put<UpdateAccountCacheInteractor>(MockUpdateAccountCacheInteractor());
    Get.put<GetOidcUserInfoInteractor>(MockGetOidcUserInfoInteractor());
    Get.put<CachingManager>(MockCachingManager());
    Get.put<LanguageCacheManager>(MockLanguageCacheManager());
    Get.put<AuthorizationInterceptors>(MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(
      MockAuthorizationInterceptors(),
      tag: BindingTag.isolateTag,
    );
    Get.put<DynamicUrlInterceptors>(MockDynamicUrlInterceptors());
    Get.put<DeleteCredentialInteractor>(MockDeleteCredentialInteractor());
    Get.put<LogoutOidcInteractor>(MockLogoutOidcInteractor());
    Get.put<DeleteAuthorityOidcInteractor>(MockDeleteAuthorityOidcInteractor());
    Get.put<AppToast>(appToast);
    Get.put<ImagePaths>(imagePaths);
    Get.put<ResponsiveUtils>(MockResponsiveUtils());
    Get.put<Uuid>(MockUuid());
    Get.put<ToastManager>(ToastManager(appToast, imagePaths));
    Get.put<TwakeAppManager>(MockTwakeAppManager());
    Get.put<HomeController>(_LayoutTestHomeController(
      MockCleanupEmailCacheInteractor(),
      MockEmailReceiveManager(),
      MockCleanupRecentLoginUrlCacheInteractor(),
      MockCleanupRecentLoginUsernameCacheInteractor(),
      MockCheckOIDCIsAvailableInteractor(),
      MockGetOIDCConfigurationInteractor(),
      MockAuthenticateOidcOnBrowserInteractor(),
      MockRemoveAuthDestinationUrlInteractor(),
    ));

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const HomeView(),
    ));
    // No pumpAndSettle: the activity indicator animates forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  tearDown(Get.reset);

  testWidgets('mark stays at viewport center', (tester) async {
    await pumpHome(tester);

    final mark = imageWithAsset('assets/images/numberinbox_mark.png');
    expect(mark, findsOneWidget);
    final markCenter = tester.getCenter(mark);
    final viewCenter = tester.getCenter(find.byType(HomeView));
    expect((markCenter.dx - viewCenter.dx).abs(), lessThanOrEqualTo(2));
    expect((markCenter.dy - viewCenter.dy).abs(), lessThanOrEqualTo(4));
  });

  testWidgets('wordmark and spinner appear below the mark', (tester) async {
    await pumpHome(tester);

    final mark = imageWithAsset('assets/images/numberinbox_mark.png');
    final wordmark = svgAsset('assets/images/numberinbox_wordmark.svg');
    expect(mark, findsOneWidget);
    expect(wordmark, findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    final markBottom = tester.getBottomLeft(mark).dy;
    final wordmarkTop = tester.getTopLeft(wordmark).dy;
    expect(wordmarkTop, greaterThan(markBottom));

    final wordmarkBottom = tester.getBottomLeft(wordmark).dy;
    final spinnerTop =
        tester.getTopLeft(find.byType(CupertinoActivityIndicator)).dy;
    expect(spinnerTop, greaterThan(wordmarkBottom));
  });

  testWidgets('background is white, not the navy brand', (tester) async {
    await pumpHome(tester);

    final boxes = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(HomeView),
            matching: find.byType(ColoredBox),
          ),
        )
        .toList();
    expect(boxes, isNotEmpty);
    expect(
      boxes.map((b) => b.color),
      contains(const Color(0xFFFFFFFF)),
      reason: 'the loading screen is pure white so it matches the native splash',
    );
  });

  testWidgets('spinner is visible against white', (tester) async {
    await pumpHome(tester);

    final spinner = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    final color = spinner.color ?? const Color(0xFF999999);
    final luminance = color.computeLuminance();
    expect(
      luminance,
      lessThan(0.5),
      reason: 'a grey or white spinner would be invisible on a white screen',
    );
  });

  testWidgets('requests dark status-bar icons on the white splash',
      (tester) async {
    await pumpHome(tester);

    // Effective style, not a source string: the innermost region wins.
    final regions = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .toList();
    expect(regions, isNotEmpty,
        reason: 'the splash must publish a region, otherwise the platform '
            'falls back to white icons that vanish on white');
    final effective = regions.last.value;
    expect(effective.statusBarIconBrightness, Brightness.dark,
        reason: 'dark icons are required on a white background');
    expect(effective.statusBarColor, Colors.transparent);
  });

  testWidgets('does not use the white-on-navy wordmark on white',
      (tester) async {
    await pumpHome(tester);

    expect(
      imageWithAsset('assets/images/numberinbox_wordmark_dark.png'),
      findsNothing,
      reason: 'the light wordmark is required now that the background is white',
    );
  });
}
