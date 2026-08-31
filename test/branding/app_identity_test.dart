import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/16-branding.md — identifiers and app name for NumberInbox.
void main() {
  group('app identity', () {
    test('android applicationId is com.numberinbox.app', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle.contains('applicationId "com.numberinbox.app"'), isTrue,
          reason: 'android applicationId must be com.numberinbox.app');
    });

    test('android namespace is com.numberinbox.app', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle.contains('namespace "com.numberinbox.app"'), isTrue);
    });

    test('iOS bundle id is com.numberinbox.app', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = com.numberinbox.app;'), isTrue,
          reason: 'iOS PRODUCT_BUNDLE_IDENTIFIER must use com.numberinbox.app');
      expect(pbx.contains('com.linagora'), isFalse,
          reason: 'no upstream bundle ids may remain');
    });

    test('android url scheme is numberinbox://', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest.contains('android:scheme="numberinbox"'), isTrue,
          reason: 'deep link scheme numberinbox:// must be registered');
    });
  });
}
