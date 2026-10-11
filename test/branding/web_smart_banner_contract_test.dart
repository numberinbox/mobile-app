import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the mobile-web smart banner.
///
/// The banner is the first NumberInbox surface an existing Twake/Tmail web user
/// can reach, so its launch scheme and store fallbacks have to match the app we
/// actually ship.
void main() {
  group('web smart banner launch targets', () {
    late String workerService;

    setUp(() {
      workerService = File('web/worker_service/worker_service.js').readAsStringSync();
    });

    test('opens the app with the scheme and host the apps register', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      // Android declares scheme + host; iOS only registers the scheme.
      expect(
        manifest,
        contains('android:scheme="numberinbox.mobile"'),
        reason: 'the Android app must register the NumberInbox scheme',
      );
      expect(
        manifest,
        contains('android:host="openApp"'),
        reason: 'the host casing is part of the launch contract',
      );
      expect(plist, contains('<string>numberinbox.mobile</string>'));

      expect(
        workerService,
        contains("numberinbox.mobile://openApp"),
        reason: 'the banner must deep link with the registered scheme and host',
      );
    });

    test('never sends users to an upstream Twake Mail listing', () {
      expect(
        workerService.toLowerCase().contains('twake'),
        isFalse,
        reason: 'the banner must not reference Twake Mail assets or listings',
      );
      expect(workerService, isNot(contains('1587086189')));
    });

    test('only falls back to verified, owned store listings', () {
      final androidStoreMatch = RegExp(
        r"const androidStore = '([^']*)'",
      ).firstMatch(workerService);
      final iosStoreMatch = RegExp(r"const iosStore = '([^']*)'").firstMatch(workerService);

      // A store fallback is only allowed when it points at a listing we own.
      if (androidStoreMatch != null) {
        expect(
          androidStoreMatch.group(1),
          anyOf(contains('com.numberinbox.app'), isNull),
          reason: 'the Android listing must use the shipped applicationId',
        );
      }
      if (iosStoreMatch != null) {
        expect(
          iosStoreMatch.group(1),
          isNot(contains('twake')),
          reason: 'the iOS fallback must never point at Twake Mail',
        );
        expect(
          iosStoreMatch.group(1),
          anyOf(isEmpty, contains('/app/id')),
          reason: 'an iOS fallback must be an App Store listing URL',
        );
      }
    });
  });

  group('web smart banner branding', () {
    test('uses the light brand palette instead of the pink tinted surface', () {
      final css = File('web/worker_service/style.css').readAsStringSync();

      expect(
        css.toUpperCase(),
        isNot(contains('#FFFBFE')),
        reason: 'the pink/blue tinted banner background is not the NumberInbox brand',
      );
      expect(
        css.toUpperCase(),
        anyOf(contains('#F5F7EB'), contains('#FFFFFF')),
        reason: 'the banner surface must use the light brand palette',
      );
      expect(css, contains('#0F172A'), reason: 'banner text uses the brand navy');
      expect(css.toUpperCase(), contains('#047857'),
          reason: 'the Open action uses the contrast-safe brand green');
    });

    test('shows the branded English tagline', () {
      final en = jsonDecode(File('web/i18n/en.json').readAsStringSync())
          as Map<String, dynamic>;

      expect(
        en['description'],
        'Email, reimagined with your number.',
        reason: 'the banner copy must be the NumberInbox tagline',
      );
    });

    test('translates the tagline instead of leaving the English fallback', () {
      const locales = ['fr', 'de', 'vi'];
      final english =
          jsonDecode(File('web/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;

      for (final locale in locales) {
        final value =
            (jsonDecode(File('web/i18n/$locale.json').readAsStringSync())
                    as Map<String, dynamic>)['description'] as String?;
        expect(value, isNotNull, reason: '$locale has no banner description');
        expect(value!.trim(), isNotEmpty);
        expect(
          value,
          isNot(english['description']),
          reason: '$locale must translate the tagline, not repeat the English copy',
        );
      }
    });
  });

  group('web smart banner startup wiring', () {
    test('fetches translations once and applies them before the app starts', () {
      final translater = File('web/i18n/translater.js').readAsStringSync();
      final indexHtml = File('web/index.html').readAsStringSync();

      expect(
        indexHtml,
        contains('initializeLocalizedApp(initialTmailApp)'),
        reason: 'startup must go through the single chained entry point',
      );
      expect(
        indexHtml,
        isNot(contains('loadLanguageResources().finally')),
        reason: 'the inline script must not fetch translations separately',
      );
      expect(
        translater,
        contains('loadLanguageResources()\n    .then(applyLanguageResources)\n    .finally(onReady)'),
        reason: 'one fetch, then text application, then app startup',
      );
      expect(
        translater,
        isNot(contains("addEventListener('DOMContentLoaded'")),
        reason: 'a second DOMContentLoaded load would re-fetch and race startup',
      );
    });

    test('the default English copy is the branded tagline', () {
      final translater = File('web/i18n/translater.js').readAsStringSync();

      expect(translater, contains("Email, reimagined with your number."));
      expect(
        translater,
        isNot(contains('Faster and more convenient')),
        reason: 'the old generic copy must not survive as a fallback',
      );
    });
  });
}
