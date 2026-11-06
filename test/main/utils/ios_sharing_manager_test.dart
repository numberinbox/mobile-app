import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/account/authentication_type.dart';
import 'package:tmail_ui_user/features/push_notification/data/keychain/keychain_sharing_session.dart';
import 'package:core/utils/sentry/sentry_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/login/data/local/authentication_info_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/local/oidc_configuration_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/local/token_oidc_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/network/oidc_http_client.dart';
import 'package:tmail_ui_user/features/mailbox/data/local/mailbox_cache_manager.dart';
import 'package:tmail_ui_user/features/mailbox/data/local/state_cache_manager.dart';
import 'package:tmail_ui_user/features/push_notification/data/keychain/keychain_sharing_manager.dart';
import 'package:tmail_ui_user/main/utils/ios_sharing_manager.dart';

class _FailingKeychainSharingManager extends KeychainSharingManager {
  _FailingKeychainSharingManager() : super(const FlutterSecureStorage());

  bool deleteSentryConfigCalled = false;

  @override
  Future<void> saveSentryConfig(SentryConfig sentryConfig) async {
    throw StateError('keychain write failed');
  }

  @override
  Future<void> deleteSentryConfig() async {
    deleteSentryConfigCalled = true;
  }
}

class _MemoryKeychain extends KeychainSharingManager {
  _MemoryKeychain(this.session) : super(const FlutterSecureStorage());
  KeychainSharingSession? session;
  final writes = <KeychainSharingSession>[];
  @override
  Future<bool> isSessionExist(AccountId accountId) async => session?.accountId == accountId;
  @override
  Future<KeychainSharingSession> getSharingSession(AccountId accountId) async => session!;
  @override
  Future<void> saveSharingSession(KeychainSharingSession value) async {
    writes.add(value);
    session = value;
  }
}

class _MockStateCacheManager extends Mock implements StateCacheManager {}

class _MockTokenOidcCacheManager extends Mock implements TokenOidcCacheManager {}

class _MockAuthenticationInfoCacheManager extends Mock
    implements AuthenticationInfoCacheManager {}

class _MockOidcConfigurationCacheManager extends Mock
    implements OidcConfigurationCacheManager {}

class _MockOIDCHttpClient extends Mock implements OIDCHttpClient {}

class _MockMailboxCacheManager extends Mock implements MailboxCacheManager {}

void main() {
  for (final hasSession in [true, false]) {
    test('delivery cursor update preserves every other field (session=$hasSession)', () async {
      final account = AccountId(Id('synthetic-account'));
      final original = KeychainSharingSession(accountId: account, userName: UserName('synthetic@example.com'),
        authenticationType: AuthenticationType.basic, apiUrl: 'https://example.com/jmap',
        basicAuth: 'synthetic-credential', emailState: 'email-state', emailDeliveryState: 'old-delivery');
      final keychain = _MemoryKeychain(hasSession ? original : null);
      final manager = IOSSharingManager(keychain, _MockStateCacheManager(), _MockTokenOidcCacheManager(),
        _MockAuthenticationInfoCacheManager(), _MockOidcConfigurationCacheManager(),
        _MockOIDCHttpClient(), _MockMailboxCacheManager());
      await manager.updateEmailDeliveryStateInKeyChain(account, 'new-delivery');
      if (hasSession) {
        final updated = keychain.writes.single.toJson();
        expect(updated, {...original.toJson(), 'emailDeliveryState': 'new-delivery'});
      } else {
        expect(keychain.writes, isEmpty);
      }
    });
  }

  test('saveSentryConfigToKeychain propagates write failures', () async {
    final keychainSharingManager = _FailingKeychainSharingManager();
    final iosSharingManager = IOSSharingManager(
      keychainSharingManager,
      _MockStateCacheManager(),
      _MockTokenOidcCacheManager(),
      _MockAuthenticationInfoCacheManager(),
      _MockOidcConfigurationCacheManager(),
      _MockOIDCHttpClient(),
      _MockMailboxCacheManager(),
    );
    final sentryConfig = SentryConfig(
      dsn: 'https://test@sentry.io/123',
      environment: 'test',
      release: '1.0.0',
      isReportingAllowed: false,
    );

    await expectLater(
      iosSharingManager.saveSentryConfigToKeychain(sentryConfig),
      throwsStateError,
    );
    expect(keychainSharingManager.deleteSentryConfigCalled, isTrue);
  });
}
