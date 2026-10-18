import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Produces and persists a stable installation identifier used as the
/// `deviceClientId` when registering the FCM token with the NumberInbox API.
///
/// Unlike a token-derived hash, this id does not change when Firebase rotates
/// the token, so the backend keeps treating the installation (and its
/// in-flight work) as the same device. The value is a UUID v4, as required by
/// the `POST /v1/fcm-registrations` contract.
class FcmInstallIdProvider {
  FcmInstallIdProvider(this._sharedPreferences);

  static const String installIdKey = 'FCM_INSTALL_ID';

  final SharedPreferences _sharedPreferences;

  Future<String?> getInstallId() async {
    final stored = _sharedPreferences.getString(installIdKey);
    if (stored != null) {
      return stored;
    }
    final installId = const Uuid().v4();
    try {
      await _sharedPreferences.setString(installIdKey, installId);
    } catch (e) {
      return null;
    }
    return installId;
  }
}
