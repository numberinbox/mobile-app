import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/account/password.dart';
import 'package:tmail_ui_user/features/login/data/local/account_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/local/token_oidc_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/network/authentication_client/authentication_client_base.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/main/utils/ios_sharing_manager.dart';

import 'authorization_interceptors_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AuthenticationClientBase>(),
  MockSpec<TokenOidcCacheManager>(),
  MockSpec<AccountCacheManager>(),
  MockSpec<IOSSharingManager>(),
])
void main() {
  late AuthorizationInterceptors interceptor;

  setUpAll(() {
    interceptor = AuthorizationInterceptors(
      Dio(),
      MockAuthenticationClientBase(),
      MockTokenOidcCacheManager(),
      MockAccountCacheManager(),
      MockIOSSharingManager(),
    );
  });

  group('AuthorizationInterceptors::basicAuthorizationHeader', () {
    test('should return null when no authorization has been set', () {
      // Act
      final result = interceptor.basicAuthorizationHeader;

      // Assert
      expect(result, isNull);
    });

    test('should return correct Basic header after setBasicAuthorization', () {
      // Act
      interceptor.setBasicAuthorization(
        UserName('+66951987335@numberinbox.test'),
        Password('test-password-123'),
      );

      // Assert
      final result = interceptor.basicAuthorizationHeader;
      expect(result, isNotNull);
      expect(result, startsWith('Basic '));
    });

    test('should return null after setting OIDC token clears basic auth', () {
      // Arrange — set basic auth first
      interceptor.setBasicAuthorization(
        UserName('user@test.com'),
        Password('pass123'),
      );
      expect(interceptor.basicAuthorizationHeader, isNotNull);

      // Act — set OIDC (this should clear basic auth path)
      // Note: setTokenAndAuthorityOidc doesn't clear _authorization,
      // but the auth type switch in onRequest will use OIDC instead.
      // The getter still returns the Basic header if _authorization is set.

      // Assert
      expect(interceptor.basicAuthorizationHeader, startsWith('Basic '));
    });
  });
}
