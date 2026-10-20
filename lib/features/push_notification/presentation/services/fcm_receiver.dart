import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/numberinbox_push_message.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/fcm_message_controller.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/services/fcm_service.dart';

Future<void>? _backgroundInitFuture;

Future<void> _ensureBackgroundInitialized() {
  return _backgroundInitFuture ??= (() async {
    FcmService.instance.initialStreamController();
    FcmMessageController.instance.initialize();
    await FcmMessageController.instance
        .initialAppConfig()
        .timeout(const Duration(seconds: 10));
  }()).catchError((Object error, StackTrace stackTrace) {
    _backgroundInitFuture = null;
    throw error;
  });
}

@pragma('vm:entry-point')
Future<void> handleFirebaseBackgroundMessage(
  RemoteMessage message, {
  Future<void> Function()? ensureBackgroundInitialized,
  Future<void> Function(FcmSentrySetupCancellation cancellation)? refreshSentryConfiguration,
  Future<void> Function(FcmSentrySetupCancellation cancellation)? invalidateSentryConfiguration,
  void Function(RemoteMessage)? handleMessage,
  Duration sentryRefreshTimeout = const Duration(seconds: 10),
}) async {
  try {
    await (ensureBackgroundInitialized ?? _ensureBackgroundInitialized)();
    await _refreshSentryForBackgroundMessage(
      refreshSentryConfiguration: refreshSentryConfiguration,
      invalidateSentryConfiguration: invalidateSentryConfiguration,
      timeout: sentryRefreshTimeout,
    );
    if (handleMessage != null) {
      handleMessage(message);
      return;
    }
    if (await _handlePlatformPushMessage(message)) return;
    FcmService.instance.handleFirebaseBackgroundMessage(message);
  } catch (e, st) {
    logError(
      'FcmReceiver::handleFirebaseBackgroundMessage: throw exception',
      exception: e,
      stackTrace: st,
    );
  }
}

/// NumberInbox platform pushes are processed inline and awaited: the Android
/// background isolate may be torn down as soon as this callback returns, so a
/// fire-and-forget stream handoff would lose the account lookup and the JMAP
/// work. Returns true when the message was such a push.
Future<bool> _handlePlatformPushMessage(RemoteMessage message) async {
  final data = message.data;
  if (data.isEmpty) return false;
  if (NumberInboxPushMessage.tryParseFromFcmData(data) == null) return false;
  await FcmMessageController.instance.handlePushPayload(data);
  return true;
}

Future<void> _refreshSentryForBackgroundMessage({
  Future<void> Function(FcmSentrySetupCancellation cancellation)? refreshSentryConfiguration,
  Future<void> Function(FcmSentrySetupCancellation cancellation)? invalidateSentryConfiguration,
  required Duration timeout,
}) async {
  final cancellation = FcmSentrySetupCancellation();
  try {
    await (refreshSentryConfiguration ??
        (cancellation) => FcmMessageController.instance
            .setUpSentryConfiguration(cancellation: cancellation))(
      cancellation,
    ).timeout(timeout);
  } catch (e, st) {
    cancellation.cancel();
    _invalidateSentrySetup(cancellation, invalidateSentryConfiguration);
    _logSentryRefreshFailure(e, st);
  }
}

void _invalidateSentrySetup(
  FcmSentrySetupCancellation cancellation,
  Future<void> Function(FcmSentrySetupCancellation cancellation)? invalidateSentryConfiguration,
) {
  try {
    final invalidation = (invalidateSentryConfiguration ??
        FcmMessageController.instance.invalidateSentrySetup)(cancellation);
    unawaited(invalidation.catchError(_logSentryInvalidationFailure));
  } catch (error, stackTrace) {
    _logSentryInvalidationFailure(error, stackTrace);
  }
}

void _logSentryInvalidationFailure(Object error, StackTrace stackTrace) {
  logError(
    'FcmReceiver::handleFirebaseBackgroundMessage: Failed to invalidate Sentry setup',
    exception: error,
    stackTrace: stackTrace,
  );
}

void _logSentryRefreshFailure(Object error, StackTrace stackTrace) {
  if (error is TimeoutException) {
    logWarning(
      'FcmReceiver::handleFirebaseBackgroundMessage: Sentry refresh timed out: $error\n$stackTrace',
    );
  } else {
    logError(
      'FcmReceiver::handleFirebaseBackgroundMessage: Sentry refresh failed',
      exception: error,
      stackTrace: stackTrace,
    );
  }
}

class FcmReceiver {
  FcmReceiver._internal();

  static final FcmReceiver _instance = FcmReceiver._internal();

  static FcmReceiver get instance => _instance;

  static const int MAX_COUNT_RETRY_TO_GET_FCM_TOKEN = 3;

  /// Acquires the FCM token with bounded retries.
  ///
  /// The token is a credential: only its presence is ever logged, never its
  /// value or the raw payload of acquisition failures. [fetchToken] and
  /// [delayBetweenAttempts] are injectable so tests can pin the logging
  /// contract without touching Firebase.
  static Future<String?> acquireFcmToken(
    Future<String?> Function() fetchToken, {
    Duration Function(int attempt)? delayBetweenAttempts,
  }) async {
    final delay = delayBetweenAttempts ?? (attempt) => Duration(seconds: 1 << (attempt - 1));
    for (var attempt = 1; attempt <= MAX_COUNT_RETRY_TO_GET_FCM_TOKEN; attempt++) {
      try {
        final token = await fetchToken();
        log('FcmReceiver::acquireFcmToken:token: ${token != null ? '<fresh-token>' : null}');
        return token;
      } catch (e) {
        if (attempt < MAX_COUNT_RETRY_TO_GET_FCM_TOKEN) {
          logWarning('FcmReceiver::acquireFcmToken: attempt $attempt failed');
          await Future.delayed(delay(attempt));
        } else {
          logError(
            'FcmReceiver::acquireFcmToken: all $MAX_COUNT_RETRY_TO_GET_FCM_TOKEN attempts failed',
          );
        }
      }
    }
    return null;
  }

  Future onInitialFcmListener() async {
    _onBackgroundMessage();
    _onForegroundMessage();

    await _onHandleFcmToken();
  }

  void _onBackgroundMessage() {
    FirebaseMessaging.onBackgroundMessage(handleFirebaseBackgroundMessage);
  }

  void _onForegroundMessage() {
    FirebaseMessaging.onMessage.listen(
      FcmService.instance.handleFirebaseForegroundMessage,
      onError: (e, st) {
        logError(
          'FcmReceiver::_onForegroundMessage:onMessage:',
          exception: e,
          stackTrace: st,
        );
      },
    );
  }

  Future<String?> _getInitialToken() =>
      acquireFcmToken(FirebaseMessaging.instance.getToken);

  Future _onHandleFcmToken() async {
    var currentToken = await _getInitialToken();
    FcmService.instance.handleToken(currentToken);

    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) {
        if (newToken != currentToken) {
          currentToken = newToken;
          FcmService.instance.handleToken(newToken);
        }
      },
      onError: (e, st) {
        logError(
          'FcmReceiver::_onHandleFcmToken:onTokenRefresh:',
          exception: e,
          stackTrace: st,
        );
      },
    );
  }
}
