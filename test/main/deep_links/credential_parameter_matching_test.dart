import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/logging/app_logger_registry.dart';
import 'package:core/utils/logging/log_handler.dart';
import 'package:core/utils/logging/log_record.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/oidc/oidc_configuration.dart';
import 'package:model/oidc/token_oidc.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/auto_sign_in_via_deep_link_interactor.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/main/deep_links/deep_links_manager.dart';
import 'package:tmail_ui_user/main/deep_links/open_app_deep_link_data.dart';

class _Logs extends LogHandler {
  final messages = <String>[];
  @override
  void handle(LogRecord record) => messages.add(record.rawMessage);
}

class _SignIn extends Fake implements AutoSignInViaDeepLinkInteractor {
  int calls = 0;
  @override
  Stream<Either<Failure, Success>> execute({
    required Uri baseUri,
    required TokenOIDC tokenOIDC,
    required OIDCConfiguration oidcConfiguration,
  }) {
    calls++;
    return const Stream.empty();
  }
}

class _Credentials extends Fake implements CredentialRepository {
  int mutations = 0;
  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async {
    mutations++;
  }

  @override
  Future<void> removeAuthenticationInfo() async {
    mutations++;
  }

  @override
  Future<void> saveBaseUrl(Uri uri) async {
    mutations++;
  }

  @override
  Future<void> removeBaseUrl() async {
    mutations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const parameters = [
    'access_token',
    'refresh_token',
    'id_token',
    'expires_in',
    'username',
    'registrationUrl',
    'jmapUrl',
  ];
  late _Logs logs;
  late _SignIn signIn;
  late _Credentials credentials;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    logs = _Logs();
    AppLoggerRegistry.instance.registerHandler(logs);
    signIn = _SignIn();
    credentials = _Credentials();
    Get.put<AutoSignInViaDeepLinkInteractor>(signIn);
    Get.put<CredentialRepository>(credentials);
  });
  tearDown(() {
    AppLoggerRegistry.instance.resetForTesting();
    Get.reset();
  });

  for (final parameter in parameters) {
    final mixedCase = String.fromCharCodes(
      List.generate(
        parameter.length,
        (i) =>
            (i.isEven ? parameter[i].toUpperCase() : parameter[i].toLowerCase())
                .codeUnitAt(0),
      ),
    );
    for (final spelling in {parameter, parameter.toLowerCase(), mixedCase}) {
      for (final nonempty in [false, true]) {
        for (final signedIn in [false, true]) {
          test(
            '$spelling ${nonempty ? 'sentinel' : 'empty'} signedIn=$signedIn is refused without side effects',
            () async {
              const sentinel = 'SECRET-SENTINEL-credential-value';
              final manager = DeepLinksManager();
              final data =
                  manager.parseDeepLink(
                        'numberinbox.mobile://openApp?'
                        '$spelling=${nonempty ? Uri.encodeComponent(sentinel) : ''}',
                      )
                      as OpenAppDeepLinkData;
              expect(data.credentialParametersRejected, isTrue);
              expect(data.accessToken, isEmpty);
              expect(data.refreshToken, anyOf(isNull, isEmpty));
              expect(data.idToken, anyOf(isNull, isEmpty));
              expect(data.expiresIn, isNull);
              expect(data.username, isEmpty);
              expect(data.registrationUrl, isEmpty);
              expect(data.jmapUrl, isEmpty);
              expect(OpenAppDeepLinkData.canAttemptAutoSignIn(data), isFalse);
              var switched = false;
              var signedInViaLink = false;
              var failures = 0;
              manager.handleOpenAppDeepLinks(
                openAppDeepLinkData: data,
                isSignedIn: signedIn,
                username: signedIn ? UserName('current@example.test') : null,
                onConfirmLogoutCallback: (_) => switched = true,
                onAutoSignInSuccessCallback: (_) => signedInViaLink = true,
                onFailureCallback: () => failures++,
              );
              await manager.autoSignInViaDeepLink(
                openAppDeepLinkData: data,
                onAutoSignInSuccessCallback: (_) => signedInViaLink = true,
                onFailureCallback: () => failures++,
              );
              expect(failures, 2);
              expect(switched, isFalse);
              expect(signedInViaLink, isFalse);
              expect(signIn.calls, 0);
              expect(credentials.mutations, 0);
              expect(logs.messages.join('\n'), isNot(contains(sentinel)));
            },
          );
        }
      }
    }
  }
}
