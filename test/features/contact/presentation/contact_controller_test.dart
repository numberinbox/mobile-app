import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/data/network/config/dynamic_url_interceptors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/contact/presentation/contact_controller.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_authority_oidc_interactor.dart';
import 'package:tmail_ui_user/features/login/domain/usecases/delete_credential_interactor.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/language_cache_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/usecases/log_out_oidc_interactor.dart';
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
class _MockAppToast extends Mock implements AppToast {}
class _MockResponsiveUtils extends Mock implements ResponsiveUtils {}
class _MockUuid extends Mock implements Uuid {}
class _MockToastManager extends Mock implements ToastManager {}
class _MockTwakeAppManager extends Mock implements TwakeAppManager {}

void main() {
  group('ContactController (real controller)', () {
    late ContactController controller;

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
      Get.put<ResponsiveUtils>(_MockResponsiveUtils());
      Get.put<Uuid>(_MockUuid());
      Get.put<ToastManager>(_MockToastManager());
      Get.put<TwakeAppManager>(_MockTwakeAppManager());
      controller = ContactController();
    });

    tearDown(() {
      Get.reset();
    });

    test('allDeviceContacts starts empty', () {
      expect(controller.allDeviceContacts, isEmpty);
    });

    test('setAllDeviceContacts populates the list the view reads', () {
      final contacts = [
        EmailAddress('Alice', 'alice@example.com'),
        EmailAddress('Bob', '+66812345678@numberinbox.com'),
      ];

      controller.setAllDeviceContacts(contacts);

      expect(controller.allDeviceContacts, hasLength(2));
      expect(controller.allDeviceContacts[0].email, 'alice@example.com');
      expect(controller.allDeviceContacts[1].email, '+66812345678@numberinbox.com');
    });

    test('setAllDeviceContacts replaces previous list', () {
      controller.setAllDeviceContacts([
        EmailAddress('Alice', 'alice@example.com'),
      ]);
      controller.setAllDeviceContacts([
        EmailAddress('Bob', 'bob@example.com'),
        EmailAddress('Carol', 'carol@example.com'),
      ]);

      expect(controller.allDeviceContacts, hasLength(2));
      expect(controller.allDeviceContacts[0].email, 'bob@example.com');
    });
  });
}
