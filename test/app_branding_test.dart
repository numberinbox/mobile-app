import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App name branding', () {
    test('iOS Info.plist CFBundleDisplayName matches the wordmark', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleDisplayName</key>\n\t\t<string>NumberInbox</string>'));
    });

    test('iOS Info.plist CFBundleName matches the wordmark', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleName</key>\n\t\t<string>NumberInbox</string>'));
    });

    test('iOS contacts usage description does not say Team-Mail', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('Team-Mail')));
    });

    test('iOS contacts usage description mentions NumberInbox', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NumberInbox'));
    });

    test('Android app_name matches the wordmark', () {
      final strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
      expect(strings, contains('<string name="app_name">NumberInbox</string>'));
    });

    test('English locale app_name matches the wordmark', () {
      final arb = File('lib/l10n/intl_en.arb').readAsStringSync();
      expect(arb, contains('"app_name": "NumberInbox"'));
    });
  });
}
