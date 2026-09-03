import 'dart:core';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceManager {
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceManager(this._deviceInfoPlugin);

  Future<bool> isNeedRequestStoragePermissionOnAndroid() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    return sdkInt <= 28;
  }

  Future<String> getDeviceId() async {
    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) return vendorId;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        final androidId = androidInfo.id;
        if (androidId.isNotEmpty) return androidId;
      }
    } catch (_) {}
    try {
      final info = await _deviceInfoPlugin.deviceInfo;
      final raw = info.data.toString();
      if (raw.isNotEmpty) return raw.hashCode.toUnsigned(20).toString();
    } catch (_) {}
    return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Map<String, String>> getDeviceInfo() async {
    try {
      final info = await _deviceInfoPlugin.deviceInfo;
      return info.data.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }
}