import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/main/deep_links/open_app_deep_link_data.dart';
import 'package:tmail_ui_user/main/deep_links/open_app_deep_link_handler_mixin.dart';

class _TestDeepLinkHandler with OpenAppDeepLinkHandlerMixin {}

/// The mobile-web smart banner opens the app with a bare
/// `numberinbox.mobile://openApp` URL. That must never be treated as a
/// credentialed sign-in: it carries no tokens, so the login screen must not
/// show a loading dialog or attempt an auto sign-in with empty fields.
void main() {
  group('banner app-open deep link', () {
    late _TestDeepLinkHandler handler;

    setUp(() {
      handler = _TestDeepLinkHandler();
    });

    test('a bare openApp URL carries no credentials and must not sign in', () {
      final data = handler.parseOpenAppDeepLink(
        Uri.parse('numberinbox.mobile://openApp'),
      );

      expect(data, isNotNull);
      expect(data!.accessToken, isEmpty);
      expect(data.username, isEmpty);
      expect(data.registrationUrl, isEmpty);
      expect(data.jmapUrl, isEmpty);
      expect(data.isValidAuthentication(), isFalse);
      expect(
        OpenAppDeepLinkData.canAttemptAutoSignIn(data),
        isFalse,
        reason: 'the banner link must land in the normal signed-in/sign-in '
            'state instead of starting a sign-in with empty credentials',
      );
    });

    test('a credentialed openApp URL is refused outright', () {
      // Phone OTP is the only public sign-in method. A link that carries
      // credentials is either an attack or a leftover from the old web
      // sign-in, and either way the tokens must never reach the OIDC
      // interactor or credential storage.
      const token = 'TOKEN-MARKER-abc123';
      final username = Uri.encodeComponent(
        Uri.encodeComponent('tmail-user@example.com'),
      );
      final data = handler.parseOpenAppDeepLink(
        Uri.parse(
          'numberinbox.mobile://openApp'
          '?access_token=$token'
          '&username=$username'
          '&registrationUrl=https://sign-up.numberinbox.com'
          '&jmapUrl=https://jmap.numberinbox.com',
        ),
      );

      expect(data, isNotNull);
      expect(data!.credentialParametersRejected, isTrue);
      expect(
        data.accessToken,
        isEmpty,
        reason: 'the token must be dropped at the parsing boundary, not merely '
            'refused later',
      );
      expect(data.username, isEmpty);
      expect(data.registrationUrl, isEmpty);
      expect(data.jmapUrl, isEmpty);
      expect(data.isValidAuthentication(), isFalse);
      expect(OpenAppDeepLinkData.canAttemptAutoSignIn(data), isFalse);
    });

    test('an empty credential parameter is still a credentialed link', () {
      // `?access_token=` carries no secret, but a link that is trying to pass
      // credentials is refused on the same rule rather than by accident.
      final data = handler.parseOpenAppDeepLink(
        Uri.parse('numberinbox.mobile://openApp?access_token='),
      );

      expect(data, isNotNull);
      expect(data!.credentialParametersRejected, isTrue);
      expect(OpenAppDeepLinkData.canAttemptAutoSignIn(data), isFalse);
    });

    test('a malformed credential parameter is still a credentialed link', () {
      final data = handler.parseOpenAppDeepLink(
        Uri.parse('numberinbox.mobile://openApp?access_token=%E0%A4%A'),
      );

      expect(data, isNotNull);
      expect(data!.credentialParametersRejected, isTrue);
      expect(OpenAppDeepLinkData.canAttemptAutoSignIn(data), isFalse);
    });

    test('a non-credential parameter leaves the link bare', () {
      final data = handler.parseOpenAppDeepLink(
        Uri.parse('numberinbox.mobile://openApp?utm_source=banner'),
      );

      expect(data, isNotNull);
      expect(data!.credentialParametersRejected, isFalse);
    });

    test('the banner link itself is not marked as rejected', () {
      final data = handler.parseOpenAppDeepLink(
        Uri.parse('numberinbox.mobile://openApp'),
      );

      expect(data!.credentialParametersRejected, isFalse);
    });

    test('other deep link data never attempts an auto sign-in', () {
      expect(
        OpenAppDeepLinkData.canAttemptAutoSignIn(
          _OtherDeepLinkData(),
        ),
        isFalse,
      );
    });
  });
}

class _OtherDeepLinkData extends OpenAppDeepLinkData {
  _OtherDeepLinkData()
      : super(
          registrationUrl: '',
          jmapUrl: '',
          username: '',
          accessToken: '',
        );
}
