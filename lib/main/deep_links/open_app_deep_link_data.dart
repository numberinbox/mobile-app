import 'package:model/oidc/oidc_configuration.dart';
import 'package:model/oidc/token_id.dart';
import 'package:model/oidc/token_oidc.dart';
import 'package:tmail_ui_user/features/login/data/network/config/oidc_constant.dart';
import 'package:tmail_ui_user/main/deep_links/deep_link_action_type.dart';
import 'package:tmail_ui_user/main/deep_links/deep_link_data.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

class OpenAppDeepLinkData extends DeepLinkData {
  final String registrationUrl;
  final String jmapUrl;
  final String username;
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final int? expiresIn;

  /// Whether the link arrived carrying authentication parameters.
  ///
  /// Phone OTP is the only public sign-in method, so such a link is refused.
  /// The parser empties the credential fields when it sets this, so no later
  /// caller can sign in with them even if a guard is dropped; the flag keeps
  /// the refusal visible for logging and for the refused-link toast.
  final bool credentialParametersRejected;

  OpenAppDeepLinkData({
    super.actionType = DeepLinkActionType.openApp,
    required this.registrationUrl,
    required this.jmapUrl,
    required this.username,
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresIn,
    this.credentialParametersRejected = false,
  });

  /// Query parameters that would let a link sign the user in.
  ///
  /// Matched case-insensitively: the app does not read `Access_Token`, but a
  /// link that is *trying* to pass credentials is refused on the same rule
  /// rather than slipping through on a spelling difference.
  static const credentialParameterNames = <String>{
    'access_token',
    'refresh_token',
    'id_token',
    'expires_in',
    'username',
    'registrationUrl',
    'jmapUrl',
  };

  /// Whether any of [names] is a credential parameter name.
  ///
  /// Takes raw names rather than decoded query parameters on purpose: a value
  /// that fails to decode must still be recognised as a credential attempt
  /// rather than thrown out as an unparsable link.
  static bool containsCredentialParameterName(Iterable<String> names) =>
      names.any((name) => credentialParameterNames.contains(name.toLowerCase()));

  /// The names in a raw query string, before any percent-decoding.
  ///
  /// `+` is a space in `application/x-www-form-urlencoded`, so it is restored
  /// here; the comparison is case-insensitive and unaffected either way.
  static List<String> rawQueryParameterNames(String query) => query
      .split('&')
      .where((pair) => pair.isNotEmpty)
      .map((pair) => pair.split('=').first.replaceAll('+', ' '))
      .toList();

  /// Whether the record holds authentication material.
  ///
  /// Phone OTP is the only public sign-in method, so any record carrying
  /// credentials is refused by the handlers — including one built in code
  /// rather than parsed from a link, which is why this is checked on the record
  /// itself and not only on the parse path.
  bool get carriesCredentials =>
      credentialParametersRejected ||
      accessToken.isNotEmpty ||
      (refreshToken?.isNotEmpty ?? false) ||
      (idToken?.isNotEmpty ?? false) ||
      username.isNotEmpty;

  /// Whether an incoming deep link may start the auto sign-in flow.
  ///
  /// Always false. Credential-based deep-link sign-in is unsupported, so this
  /// is kept as the single question callers ask: the mobile-web banner opens
  /// the app with a bare `openApp` URL that carries no credentials, and such a
  /// link must land in the normal signed-in/sign-in state instead of showing a
  /// loading dialog and signing in with empty fields.
  static bool canAttemptAutoSignIn(DeepLinkData deepLinkData) => false;

  /// The deep link is reachable from any web page or email link: the servers
  /// it points the app to must be https URLs on an allow-listed host.
  ///
  /// A link that carried credentials is never valid, whatever it contains now.
  bool isValidAuthentication() =>
      !credentialParametersRejected &&
      accessToken.isNotEmpty &&
      username.isNotEmpty &&
      _isSecureAbsoluteUrl(registrationUrl) &&
      _isSecureAbsoluteUrl(jmapUrl);

  static bool _isSecureAbsoluteUrl(String url) {
    // Dart reads `\` as `/`, Android's java.net.URL as part of the user
    // info: `https://sign-up.twake.app\@evil.com` passes the host check here
    // but AppAuth fetches the OIDC discovery from evil.com.
    if (url.contains(r'\')) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        AppConfig.deepLinkAllowedHosts.contains(uri.host);
  }

  String get jmapHost => Uri.tryParse(jmapUrl)?.host ?? jmapUrl;

  DateTime? _getExpiredTime() {
    return expiresIn != null
        ? DateTime.now().add(Duration(seconds: expiresIn!))
        : null;
  }

  bool isLoggedInWith(String currentUsername) => username == currentUsername;

  TokenOIDC get tokenOIDC {
    return TokenOIDC(
      accessToken,
      TokenId(idToken ?? ''),
      refreshToken ?? '',
      expiredTime: _getExpiredTime(),
    );
  }

  Uri get baseUri => Uri.parse(jmapUrl);

  OIDCConfiguration get oidcConfiguration => OIDCConfiguration(
    authority: registrationUrl,
    clientId: OIDCConstant.clientId,
    scopes: AppConfig.oidcScopes,
    isTWP: true,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    registrationUrl,
    jmapUrl,
    username,
    accessToken,
    refreshToken,
    idToken,
    expiresIn,
    credentialParametersRejected,
  ];
}
