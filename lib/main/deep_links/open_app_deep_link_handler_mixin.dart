import 'package:core/presentation/extensions/either_view_state_extension.dart';
import 'package:core/presentation/utils/app_toast.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/string_convert.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:tmail_ui_user/features/base/mixin/message_dialog_action_manager.dart';
import 'package:tmail_ui_user/features/home/domain/state/auto_sign_in_via_deep_link_state.dart';
import 'package:tmail_ui_user/features/home/domain/usecases/auto_sign_in_via_deep_link_interactor.dart';
import 'package:tmail_ui_user/main/deep_links/deep_link_callback_action_define.dart';
import 'package:tmail_ui_user/main/deep_links/open_app_deep_link_data.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

mixin OpenAppDeepLinkHandlerMixin {
  /// Parses a `numberinbox.mobile://openApp` link.
  ///
  /// Authentication parameters are never read. Phone OTP is the only public
  /// sign-in method, so a link carrying them is refused here — at the parsing
  /// boundary, before the values exist as data — and returned as an empty
  /// record marked [OpenAppDeepLinkData.credentialParametersRejected]. The bare
  /// banner link still parses, and still just opens the app.
  OpenAppDeepLinkData? parseOpenAppDeepLink(Uri uri) {
    try {
      // Names are read off the raw query first: decoding a hostile value can
      // throw, and a link that fails to decode must still be recognised as a
      // credential attempt rather than dropped as unparsable.
      final names = OpenAppDeepLinkData.rawQueryParameterNames(uri.query);

      if (OpenAppDeepLinkData.containsCredentialParameterName(names)) {
        // Names only: a rejected link still names its parameters in the log,
        // never their values.
        final refusedNames = names
            .where((name) => OpenAppDeepLinkData.credentialParameterNames
                .contains(name.toLowerCase()))
            .toList()
          ..sort();
        logWarning(
          'DeepLinksManager::parseOpenAppDeepLink: refusing credentialed deep '
          'link (parameters: $refusedNames)',
        );
        return OpenAppDeepLinkData(
          registrationUrl: '',
          jmapUrl: '',
          accessToken: '',
          username: '',
          credentialParametersRejected: true,
        );
      }

      final queryParameters = uri.queryParameters;
      final accessToken = queryParameters['access_token'] ?? '';
      final refreshToken = queryParameters['refresh_token'];
      final idToken = queryParameters['id_token'];
      final expiresInStr = queryParameters['expires_in'];
      final username = queryParameters['username'];
      final registrationUrl = queryParameters['registrationUrl'] ?? '';
      final jmapUrl = queryParameters['jmapUrl'] ?? '';

      final expiresIn = expiresInStr != null
          ? int.tryParse(expiresInStr)
          : null;

      final usernameDecoded = username?.isNotEmpty == true
          ? StringConvert.decodeBase64ToString(username!)
          : username ?? '';

      return OpenAppDeepLinkData(
        registrationUrl: registrationUrl,
        jmapUrl: jmapUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
        idToken: idToken,
        expiresIn: expiresIn,
        username: usernameDecoded,
      );
    } catch (e) {
      logWarning('DeepLinksManager::parseOpenAppDeepLink:Exception = $e');
      return null;
    }
  }

  void handleOpenAppDeepLinks({
    required OpenAppDeepLinkData openAppDeepLinkData,
    OnDeepLinkFailureCallback? onFailureCallback,
    OnAutoSignInViaDeepLinkSuccessCallback? onAutoSignInSuccessCallback,
    OnDeepLinkConfirmLogoutCallback<OpenAppDeepLinkData>? onConfirmLogoutCallback,
    UserName? username,
    bool isSignedIn = true,
  }) {
    // Second guard, independent of how the data was built: a link carrying
    // credentials never switches accounts and never signs in.
    if (openAppDeepLinkData.credentialParametersRejected) {
      logWarning(
        'DeepLinksManager::handleOpenAppDeepLinks: refusing credentialed deep link',
      );
      _notifyLinkRefused(openAppDeepLinkData);
      onFailureCallback?.call();
      return;
    }

    if (!openAppDeepLinkData.isValidAuthentication()) {
      _notifyLinkRefused(openAppDeepLinkData);
      onFailureCallback?.call();
      return;
    }

    if (isSignedIn) {
      if (currentContext == null || username == null) {
        onFailureCallback?.call();
        return;
      }

      if (openAppDeepLinkData.isLoggedInWith(username.value)) {
        onFailureCallback?.call();
        return;
      }

      _showConfirmDialogSwitchAccount(
        context: currentContext!,
        currentUsername: username.value,
        newUsername: '${openAppDeepLinkData.username.replaceAll(RegExp(r'[\s\u0000-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]+'), ' ').trim()} (${openAppDeepLinkData.jmapHost})',
        onConfirmAction: () => onConfirmLogoutCallback?.call(openAppDeepLinkData),
        onCancelAction: () => onFailureCallback?.call()
      );
    } else {
      autoSignInViaDeepLink(
        openAppDeepLinkData: openAppDeepLinkData,
        onAutoSignInSuccessCallback: (viewState) => onAutoSignInSuccessCallback?.call(viewState),
        onFailureCallback: () => onFailureCallback?.call(),
      );
    }
  }

  Future<void> autoSignInViaDeepLink({
    required OpenAppDeepLinkData openAppDeepLinkData,
    required OnAutoSignInViaDeepLinkSuccessCallback onAutoSignInSuccessCallback,
    required OnDeepLinkFailureCallback onFailureCallback,
  }) async {
    if (openAppDeepLinkData.credentialParametersRejected) {
      logWarning(
        'DeepLinksManager::autoSignInViaDeepLink: refusing credentialed deep link',
      );
      _notifyLinkRefused(openAppDeepLinkData);
      onFailureCallback.call();
      return;
    }

    if (!openAppDeepLinkData.isValidAuthentication()) {
      logWarning('DeepLinksManager::autoSignInViaDeepLink: invalid or insecure deep link data');
      _notifyLinkRefused(openAppDeepLinkData);
      onFailureCallback.call();
      return;
    }

    try {
      final autoSignInViaDeepLinkInteractor = Get.find<AutoSignInViaDeepLinkInteractor>();

      final autoSignInViewState = await autoSignInViaDeepLinkInteractor.execute(
        baseUri: openAppDeepLinkData.baseUri,
        tokenOIDC: openAppDeepLinkData.tokenOIDC,
        oidcConfiguration: openAppDeepLinkData.oidcConfiguration,
      ).last;

      autoSignInViewState.foldSuccess<AutoSignInViaDeepLinkSuccess>(
        onSuccess: onAutoSignInSuccessCallback,
        onFailure: (failure) => onFailureCallback.call(),
      );
    } catch (e) {
      logWarning('DeepLinksManager::_autoSignInViaDeepLink:Exception = $e');
      onFailureCallback.call();
    }
  }

  void _notifyLinkRefused(OpenAppDeepLinkData openAppDeepLinkData) {
    // A bare openapp link (web "Open in app" banner) only brings the app up,
    // so it stays silent. A refused credentialed link does not: the user
    // asked a link to sign them in, and nothing happened.
    if (openAppDeepLinkData.accessToken.isEmpty &&
        !openAppDeepLinkData.credentialParametersRejected) {
      return;
    }

    final context = currentContext;
    final overlayContext = currentOverlayContext;
    if (context == null || overlayContext == null || !Get.isRegistered<AppToast>()) return;

    Get.find<AppToast>().showToastErrorMessage(
      overlayContext,
      AppLocalizations.of(context).deepLinkCannotBeOpened,
    );
  }

  void _showConfirmDialogSwitchAccount({
    required BuildContext context,
    required String currentUsername,
    required String newUsername,
    required Function onConfirmAction,
    required Function onCancelAction,
  }) {
    final appLocalizations = AppLocalizations.of(context);

    MessageDialogActionManager().showConfirmDialogAction(
      context,
      '',
      appLocalizations.yes,
      title: appLocalizations.switchAccountConfirmation,
      alignCenter: true,
      outsideDismissible: false,
      listTextSpan: [
        TextSpan(text: appLocalizations.youAreCurrentlyLoggedInWith),
        TextSpan(
          text: ' $currentUsername',
          style: ThemeUtils.textStyleM3BodyMedium1.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const TextSpan(text: '. '),
        TextSpan(text: appLocalizations.doYouWantToLogOutAndSwitchTo),
        TextSpan(
          text: ' $newUsername',
          style: ThemeUtils.textStyleM3BodyMedium1.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const TextSpan(text: '?'),
      ],
      onConfirmAction: onConfirmAction,
      onCancelAction: onCancelAction,
    );
  }
}
