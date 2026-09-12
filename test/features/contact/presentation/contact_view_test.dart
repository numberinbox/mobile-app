import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/contact/presentation/contact_controller.dart';
import 'package:tmail_ui_user/features/contact/presentation/contact_view.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';
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
class _MockAppToast extends Mock implements AppToast {}
class _MockUuid extends Mock implements Uuid {}
class _MockToastManager extends Mock implements ToastManager {}
class _MockTwakeAppManager extends Mock implements TwakeAppManager {}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<CachingManager>(_MockCachingManager());
    Get.put<LanguageCacheManager>(_MockLanguageCacheManager());
    Get.put<AuthorizationInterceptors>(_MockAuthorizationInterceptors());
    Get.put<AuthorizationInterceptors>(
      _MockAuthorizationInterceptors(),
      tag: BindingTag.isolateTag,
    );
    Get.put<DynamicUrlInterceptors>(_MockDynamicUrlInterceptors());
    Get.put<DeleteCredentialInteractor>(_MockDeleteCredentialInteractor());
    Get.put<LogoutOidcInteractor>(_MockLogoutOidcInteractor());
    Get.put<DeleteAuthorityOidcInteractor>(_MockDeleteAuthorityOidcInteractor());
    Get.put<AppToast>(_MockAppToast());
    Get.put<ImagePaths>(ImagePaths());
    Get.put<ResponsiveUtils>(ResponsiveUtils());
    Get.put<Uuid>(_MockUuid());
    Get.put<ToastManager>(_MockToastManager());
    Get.put<TwakeAppManager>(_MockTwakeAppManager());
    Get.put<ContactController>(ContactController());
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        if (call.method == 'checkPermissionStatus') return 1; // granted
        return 0;
      },
    );
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: ContactView(),
    ));
    await tester.pumpAndSettle();
    // Flush the 500ms delayed permission check in ContactController.onReady.
    // pumpAndSettle alone does not advance lone timers.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  group('ContactView all-device-contacts list', () {
    testWidgets('shows loaded device contacts without typing', (tester) async {
      Get.find<ContactController>().setAllDeviceContacts([
        EmailAddress('Manish Thakur', '+918860997941@numberinbox.com'),
        EmailAddress('John Doe', 'john@example.com'),
      ]);

      await pumpView(tester);

      expect(find.text('Manish Thakur'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows phone number (not mapped email) for phone contacts', (tester) async {
      Get.find<ContactController>().setAllDeviceContacts([
        EmailAddress('Bob', '+66812345678@numberinbox.com'),
      ]);

      await pumpView(tester);

      expect(find.text('+66812345678'), findsOneWidget);
      expect(find.text('+66812345678@numberinbox.com'), findsNothing);
    });

    testWidgets('shows nothing when no contacts loaded and none selected', (tester) async {
      await pumpView(tester);

      expect(find.text('Manish Thakur'), findsNothing);
    });
  });
}
