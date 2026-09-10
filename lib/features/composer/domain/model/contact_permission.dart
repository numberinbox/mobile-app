
import 'package:permission_handler/permission_handler.dart';

/// Whether a contacts [PermissionStatus] grants enough access to read
/// device contacts.
///
/// iOS 18+ offers "Allow Limited Access", which maps to
/// [PermissionStatus.limited]. Treating only [PermissionStatus.granted]
/// as success silently drops contacts on those devices.
extension ContactPermissionStatusX on PermissionStatus {
  bool get allowsDeviceContacts => isGranted || isLimited;
}
