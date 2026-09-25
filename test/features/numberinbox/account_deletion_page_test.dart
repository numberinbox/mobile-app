import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_page.dart';

class _Credentials implements CredentialRepository {
  @override
  Future<AuthenticationInfoCache> getAuthenticationInfoStored() async =>
      AuthenticationInfoCache('+66812345678@numberinbox.test', 'secret');

  @override
  Future<Uri> getBaseUrl() async => Uri.parse('https://jmap.numberinbox.test');
  @override
  Future removeBaseUrl() async {}
  @override
  Future<void> removeAuthenticationInfo() async {}
  @override
  Future saveBaseUrl(Uri baseUrl) async {}
  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async {}
}

class _DeletionClient extends AccountDeletionClient {
  _DeletionClient() : super(Dio());
  int calls = 0;
  int statusCalls = 0;

  @override
  Future<AccountDeletionRequest> request({
    required String confirmE164,
    required String username,
    required String password,
    required String idempotencyKey,
  }) async {
    calls++;
    return const AccountDeletionRequest('request-id', 'status-token');
  }

  @override
  Future<String> status(String requestId, String statusToken) async {
    statusCalls++;
    return 'completed';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('requires the signed-in number before deletion is offered', (tester) async {
    final client = _DeletionClient();
    await tester.pumpWidget(MaterialApp(
      home: AccountDeletionPage(
        client: client,
        credentialRepository: _Credentials(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsWidgets);
    expect(find.text('Verification code'), findsNothing);
    await tester.enterText(find.byKey(const Key('deletion_phone_field')), '0899999999');
    await tester.tap(find.byKey(const Key('deletion_submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('does not match'), findsOneWidget);
    expect(client.calls, 0);
  });

  testWidgets('confirms the signed-in number and finishes without another OTP', (tester) async {
    final client = _DeletionClient();
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
      home: AccountDeletionPage(
        client: client,
        credentialRepository: _Credentials(),
        onDeleted: () async => signedOut = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('deletion_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Delete permanently'), findsOneWidget);
    expect(client.calls, 0);

    await tester.tap(find.text('Delete permanently'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(client.calls, 1);
    expect(client.statusCalls, 1);
    expect(signedOut, isTrue);
  });
}
