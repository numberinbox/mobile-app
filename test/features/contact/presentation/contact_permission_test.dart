import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tmail_ui_user/features/composer/domain/model/contact_permission.dart';

void main() {
  group('ContactPermissionStatusX.allowsDeviceContacts', () {
    test('returns true for granted', () {
      expect(PermissionStatus.granted.allowsDeviceContacts, isTrue);
    });

    test('returns true for limited (iOS 18+)', () {
      expect(PermissionStatus.limited.allowsDeviceContacts, isTrue);
    });

    test('returns false for denied', () {
      expect(PermissionStatus.denied.allowsDeviceContacts, isFalse);
    });

    test('returns false for permanentlyDenied', () {
      expect(
        PermissionStatus.permanentlyDenied.allowsDeviceContacts,
        isFalse,
      );
    });

    test('returns false for restricted', () {
      expect(PermissionStatus.restricted.allowsDeviceContacts, isFalse);
    });
  });
}
