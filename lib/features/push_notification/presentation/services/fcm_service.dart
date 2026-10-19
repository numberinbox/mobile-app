
import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {

  StreamController<Map<String, dynamic>>?  backgroundMessageStreamController;
  StreamController<Map<String, dynamic>>? foregroundMessageStreamController;
  StreamController<String?>? fcmTokenStreamController;

  FcmService._internal();

  static final FcmService _instance = FcmService._internal();

  static FcmService get instance => _instance;

  void handleFirebaseBackgroundMessage(RemoteMessage newRemoteMessage) {
    log('FcmService::handleFirebaseBackgroundMessage():data: ${newRemoteMessage.data}');
    if (newRemoteMessage.data.isNotEmpty) {
      backgroundMessageStreamController?.add(newRemoteMessage.data);
    }
  }

  void handleFirebaseForegroundMessage(RemoteMessage newRemoteMessage) {
    log('FcmService::handleFirebaseForegroundMessage():data: ${newRemoteMessage.data}');
    if (newRemoteMessage.data.isNotEmpty) {
      foregroundMessageStreamController?.add(newRemoteMessage.data);
    }
  }

  void handleToken(String? token) {
    log('FcmService::handleToken():token: $token');
    fcmTokenStreamController?.add(token);
  }

  void initialStreamController() {
    log('FcmService::initialStreamController:');
    backgroundMessageStreamController = StreamController<Map<String, dynamic>>.broadcast();
    foregroundMessageStreamController = StreamController<Map<String, dynamic>>.broadcast();
    fcmTokenStreamController = StreamController<String?>.broadcast();
  }

  Future<void> closeStream() async {
    try {
      await backgroundMessageStreamController?.close();
    } catch (e) {
      logWarning(
        'FcmService::closeStream: backgroundMessageStreamController throw exception: $e',
      );
    } finally {
      backgroundMessageStreamController = null;
    }
    try {
      await foregroundMessageStreamController?.close();
    } catch (e) {
      logWarning(
        'FcmService::closeStream: foregroundMessageStreamController throw exception: $e',
      );
    } finally {
      foregroundMessageStreamController = null;
    }
    try {
      await fcmTokenStreamController?.close();
    } catch (e) {
      logWarning(
        'FcmService::closeStream: fcmTokenStreamController throw exception: $e',
      );
    } finally {
      fcmTokenStreamController = null;
    }
  }
}